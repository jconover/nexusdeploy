#!/usr/bin/env python3
"""Deployment Orchestrator.

Orchestrates deployments with support for rolling, canary, and blue-green strategies.
Includes rollback capability.
"""
import argparse
import logging
import shlex
import subprocess
import sys
from dataclasses import dataclass
from enum import Enum

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

VALID_SERVICES = ["api-gateway", "auth-service", "worker-service", "all"]
VALID_ENVIRONMENTS = ["dev", "staging", "prod"]


class Strategy(str, Enum):
    ROLLING = "rolling"
    CANARY = "canary"
    BLUE_GREEN = "blue-green"


@dataclass
class DeployConfig:
    environment: str
    service: str
    strategy: Strategy
    version: str
    dry_run: bool
    project: str = ""
    registry: str = ""
    cluster: str = ""
    zone: str = ""


def run_cmd(cmd: str, dry_run: bool = False, capture: bool = False) -> tuple[int, str]:
    """Run a shell command, returning (returncode, output)."""
    logger.info("$ %s", cmd)
    if dry_run:
        logger.info("[DRY-RUN] Command not executed")
        return 0, ""

    result = subprocess.run(
        shlex.split(cmd),
        capture_output=capture,
        text=True,
    )
    output = (result.stdout or "") + (result.stderr or "")
    if result.returncode != 0:
        logger.error("Command failed (exit %d): %s", result.returncode, output)
    return result.returncode, output


def build_and_push_image(config: DeployConfig, service: str) -> bool:
    """Build Docker image and push to registry."""
    logger.info("Building image for %s:%s", service, config.version)
    image = f"{config.registry}/{service}:{config.version}" if config.registry else f"{service}:{config.version}"

    rc, _ = run_cmd(
        f"docker build -t {image} ./docker/{service}",
        dry_run=config.dry_run,
    )
    if rc != 0:
        return False

    if config.registry:
        rc, _ = run_cmd(f"docker push {image}", dry_run=config.dry_run)
        if rc != 0:
            return False

    logger.info("Image ready: %s", image)
    return True


def configure_kubectl(config: DeployConfig) -> bool:
    """Configure kubectl context for the target cluster."""
    if not config.cluster:
        logger.info("No cluster specified, using current kubectl context")
        return True

    cmd = f"gcloud container clusters get-credentials {config.cluster} --zone {config.zone}"
    if config.project:
        cmd += f" --project {config.project}"

    rc, _ = run_cmd(cmd, dry_run=config.dry_run)
    return rc == 0


def deploy_rolling(config: DeployConfig, service: str) -> bool:
    """Rolling update deployment strategy."""
    logger.info("[ROLLING] Deploying %s to %s", service, config.environment)
    namespace = f"nexusdeploy-{config.environment}" if config.environment != "prod" else "nexusdeploy"
    image = f"{config.registry}/{service}:{config.version}" if config.registry else f"{service}:{config.version}"

    rc, _ = run_cmd(
        f"kubectl set image deployment/{service} {service}={image} -n {namespace}",
        dry_run=config.dry_run,
    )
    if rc != 0:
        return False

    rc, _ = run_cmd(
        f"kubectl rollout status deployment/{service} -n {namespace} --timeout=300s",
        dry_run=config.dry_run,
    )
    return rc == 0


def deploy_canary(config: DeployConfig, service: str) -> bool:
    """Canary deployment strategy — deploy 10% traffic to new version."""
    logger.info("[CANARY] Deploying %s canary to %s", service, config.environment)
    namespace = f"nexusdeploy-{config.environment}" if config.environment != "prod" else "nexusdeploy"

    # Create canary deployment with 1 replica (alongside main deployment)
    canary_name = f"{service}-canary"
    image = f"{config.registry}/{service}:{config.version}" if config.registry else f"{service}:{config.version}"

    # Patch canary deployment image
    rc, _ = run_cmd(
        f"kubectl set image deployment/{canary_name} {service}={image} -n {namespace}",
        dry_run=config.dry_run,
    )
    if rc != 0:
        logger.warning("Canary deployment %s not found, creating via rolling update", canary_name)
        return deploy_rolling(config, service)

    rc, _ = run_cmd(
        f"kubectl rollout status deployment/{canary_name} -n {namespace} --timeout=120s",
        dry_run=config.dry_run,
    )
    if rc == 0:
        logger.info("Canary healthy. Promote with: kubectl set image deployment/%s %s=%s -n %s",
                    service, service, image, namespace)
    return rc == 0


def deploy_blue_green(config: DeployConfig, service: str) -> bool:
    """Blue-green deployment strategy."""
    logger.info("[BLUE-GREEN] Deploying %s blue-green to %s", service, config.environment)
    namespace = f"nexusdeploy-{config.environment}" if config.environment != "prod" else "nexusdeploy"
    image = f"{config.registry}/{service}:{config.version}" if config.registry else f"{service}:{config.version}"

    green_name = f"{service}-green"

    # Deploy green
    rc, _ = run_cmd(
        f"kubectl set image deployment/{green_name} {service}={image} -n {namespace}",
        dry_run=config.dry_run,
    )
    if rc != 0:
        logger.warning("Green deployment not found, falling back to rolling update")
        return deploy_rolling(config, service)

    rc, _ = run_cmd(
        f"kubectl rollout status deployment/{green_name} -n {namespace} --timeout=300s",
        dry_run=config.dry_run,
    )
    if rc != 0:
        logger.error("Green deployment failed, not switching traffic")
        return False

    # Switch service selector to green
    rc, _ = run_cmd(
        f"kubectl patch service {service} -n {namespace} "
        f"-p '{{\"spec\":{{\"selector\":{{\"version\":\"green\"}}}}}}'",
        dry_run=config.dry_run,
    )
    if rc == 0:
        logger.info("Traffic switched to green deployment. Scale down blue when verified.")
    return rc == 0


def rollback_deployment(config: DeployConfig, service: str) -> bool:
    """Rollback deployment to previous revision."""
    logger.info("Rolling back %s in %s", service, config.environment)
    namespace = f"nexusdeploy-{config.environment}" if config.environment != "prod" else "nexusdeploy"

    rc, _ = run_cmd(
        f"kubectl rollout undo deployment/{service} -n {namespace}",
        dry_run=config.dry_run,
    )
    if rc != 0:
        return False

    rc, _ = run_cmd(
        f"kubectl rollout status deployment/{service} -n {namespace} --timeout=300s",
        dry_run=config.dry_run,
    )
    return rc == 0


def deploy_service(config: DeployConfig, service: str) -> bool:
    """Deploy a single service with the configured strategy."""
    logger.info("Deploying service: %s (strategy: %s)", service, config.strategy)

    if not build_and_push_image(config, service):
        logger.error("Image build/push failed for %s", service)
        return False

    strategy_fn = {
        Strategy.ROLLING: deploy_rolling,
        Strategy.CANARY: deploy_canary,
        Strategy.BLUE_GREEN: deploy_blue_green,
    }[config.strategy]

    success = strategy_fn(config, service)
    if success:
        logger.info("Deployment of %s succeeded", service)
    else:
        logger.error("Deployment of %s failed", service)
        if config.strategy == Strategy.ROLLING and not config.dry_run:
            logger.info("Attempting automatic rollback...")
            rollback_deployment(config, service)
    return success


def main() -> int:
    parser = argparse.ArgumentParser(
        description="NexusDeploy Deployment Orchestrator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --environment staging --service api-gateway --version v1.2.3
  %(prog)s --environment prod --service all --strategy canary --version v2.0.0
  %(prog)s --environment dev --service worker-service --dry-run
""",
    )
    parser.add_argument("--environment", "-e", required=True, choices=VALID_ENVIRONMENTS)
    parser.add_argument("--service", "-s", required=True, choices=VALID_SERVICES)
    parser.add_argument("--strategy", choices=[s.value for s in Strategy], default="rolling")
    parser.add_argument("--version", "-V", default="latest", help="Image tag/version to deploy")
    parser.add_argument("--project", help="GCP project ID")
    parser.add_argument("--registry", help="Container registry (e.g. gcr.io/my-project)")
    parser.add_argument("--cluster", help="GKE cluster name")
    parser.add_argument("--zone", default="us-central1", help="GKE cluster zone")
    parser.add_argument("--dry-run", action="store_true", help="Show commands without executing")
    parser.add_argument("--rollback", action="store_true", help="Rollback instead of deploy")
    parser.add_argument("--verbose", "-v", action="store_true")

    args = parser.parse_args()
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    config = DeployConfig(
        environment=args.environment,
        service=args.service,
        strategy=Strategy(args.strategy),
        version=args.version,
        dry_run=args.dry_run,
        project=args.project or "",
        registry=args.registry or "",
        cluster=args.cluster or "",
        zone=args.zone,
    )

    if config.dry_run:
        logger.info("DRY RUN MODE — no changes will be made")

    if not configure_kubectl(config):
        logger.error("Failed to configure kubectl")
        return 1

    services = VALID_SERVICES[:-1] if config.service == "all" else [config.service]

    results = []
    for svc in services:
        if args.rollback:
            ok = rollback_deployment(config, svc)
        else:
            ok = deploy_service(config, svc)
        results.append((svc, ok))

    print("\n== Deployment Summary ==")
    for svc, ok in results:
        print(f"  {'✓' if ok else '✗'} {svc}: {'SUCCESS' if ok else 'FAILED'}")

    return 0 if all(ok for _, ok in results) else 1


if __name__ == "__main__":
    sys.exit(main())
