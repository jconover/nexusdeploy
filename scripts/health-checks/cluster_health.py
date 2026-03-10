#!/usr/bin/env python3
"""GKE Cluster Health Checker.

Checks cluster health including nodes, pods, PVCs, and TLS certificates.
Exit codes: 0=healthy, 1=warning, 2=critical
"""
import argparse
import logging
import sys
from dataclasses import dataclass, field
from enum import IntEnum

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


class Status(IntEnum):
    HEALTHY = 0
    WARNING = 1
    CRITICAL = 2


@dataclass
class CheckResult:
    name: str
    status: Status
    message: str
    details: list[str] = field(default_factory=list)


def check_cluster_status(cluster: str, zone: str, project: str | None = None) -> CheckResult:
    """Check overall GKE cluster status."""
    logger.info("Checking cluster status: %s/%s", zone, cluster)
    try:
        from google.cloud import container_v1

        client = container_v1.ClusterManagerClient()
        name = f"projects/{project}/locations/{zone}/clusters/{cluster}"
        cluster_obj = client.get_cluster(name=name)

        if cluster_obj.status == container_v1.Cluster.Status.RUNNING:
            return CheckResult(
                name="cluster_status",
                status=Status.HEALTHY,
                message=f"Cluster {cluster} is RUNNING (k8s {cluster_obj.current_master_version})",
            )
        else:
            return CheckResult(
                name="cluster_status",
                status=Status.CRITICAL,
                message=f"Cluster {cluster} status: {cluster_obj.status.name}",
            )
    except ImportError:
        logger.warning("google-cloud-container not installed, using kubectl fallback")
        return CheckResult(
            name="cluster_status",
            status=Status.WARNING,
            message=f"Could not connect to cluster {cluster} (SDK not available)",
        )
    except Exception as e:
        return CheckResult(
            name="cluster_status",
            status=Status.CRITICAL,
            message=f"Failed to get cluster status: {e}",
        )


def check_node_health(namespace: str = "default") -> CheckResult:
    """Check node readiness and resource pressure."""
    logger.info("Checking node health")
    try:
        from kubernetes import client as k8s_client, config as k8s_config

        try:
            k8s_config.load_incluster_config()
        except k8s_config.ConfigException:
            k8s_config.load_kube_config()

        v1 = k8s_client.CoreV1Api()
        nodes = v1.list_node()

        not_ready = []
        pressured = []
        for node in nodes.items:
            for condition in node.status.conditions:
                if condition.type == "Ready" and condition.status != "True":
                    not_ready.append(node.metadata.name)
                if condition.type in ("MemoryPressure", "DiskPressure", "PIDPressure"):
                    if condition.status == "True":
                        pressured.append(f"{node.metadata.name}:{condition.type}")

        if not_ready or pressured:
            status = Status.CRITICAL if not_ready else Status.WARNING
            details = [f"NotReady: {', '.join(not_ready)}"] if not_ready else []
            details += [f"Pressure: {p}" for p in pressured]
            return CheckResult(
                name="node_health",
                status=status,
                message=f"{len(nodes.items)} nodes, {len(not_ready)} not ready, {len(pressured)} under pressure",
                details=details,
            )

        return CheckResult(
            name="node_health",
            status=Status.HEALTHY,
            message=f"All {len(nodes.items)} nodes are Ready",
        )
    except ImportError:
        return CheckResult(
            name="node_health",
            status=Status.WARNING,
            message="kubernetes Python client not installed",
        )
    except Exception as e:
        return CheckResult(
            name="node_health",
            status=Status.CRITICAL,
            message=f"Failed to check node health: {e}",
        )


def check_pod_status(namespace: str = "nexusdeploy") -> CheckResult:
    """Check pod health in the given namespace."""
    logger.info("Checking pod status in namespace: %s", namespace)
    try:
        from kubernetes import client as k8s_client, config as k8s_config

        try:
            k8s_config.load_incluster_config()
        except k8s_config.ConfigException:
            k8s_config.load_kube_config()

        v1 = k8s_client.CoreV1Api()
        pods = v1.list_namespaced_pod(namespace)

        failed = []
        pending = []
        crashlooping = []

        for pod in pods.items:
            phase = pod.status.phase
            if phase == "Failed":
                failed.append(pod.metadata.name)
            elif phase == "Pending":
                pending.append(pod.metadata.name)
            elif pod.status.container_statuses:
                for cs in pod.status.container_statuses:
                    if cs.state.waiting and cs.state.waiting.reason == "CrashLoopBackOff":
                        crashlooping.append(f"{pod.metadata.name}/{cs.name}")

        issues = failed + pending + crashlooping
        if crashlooping or failed:
            return CheckResult(
                name="pod_status",
                status=Status.CRITICAL,
                message=f"{len(pods.items)} pods: {len(failed)} failed, {len(crashlooping)} crashlooping",
                details=issues,
            )
        if pending:
            return CheckResult(
                name="pod_status",
                status=Status.WARNING,
                message=f"{len(pods.items)} pods: {len(pending)} pending",
                details=pending,
            )

        running = sum(1 for p in pods.items if p.status.phase == "Running")
        return CheckResult(
            name="pod_status",
            status=Status.HEALTHY,
            message=f"All {running}/{len(pods.items)} pods running in {namespace}",
        )
    except ImportError:
        return CheckResult(
            name="pod_status",
            status=Status.WARNING,
            message="kubernetes Python client not installed",
        )
    except Exception as e:
        return CheckResult(
            name="pod_status",
            status=Status.CRITICAL,
            message=f"Failed to check pod status: {e}",
        )


def check_pvc_status(namespace: str = "nexusdeploy") -> CheckResult:
    """Check PersistentVolumeClaim health."""
    logger.info("Checking PVC status in namespace: %s", namespace)
    try:
        from kubernetes import client as k8s_client, config as k8s_config

        try:
            k8s_config.load_incluster_config()
        except k8s_config.ConfigException:
            k8s_config.load_kube_config()

        v1 = k8s_client.CoreV1Api()
        pvcs = v1.list_namespaced_persistent_volume_claim(namespace)

        unbound = [
            p.metadata.name
            for p in pvcs.items
            if p.status.phase != "Bound"
        ]

        if unbound:
            return CheckResult(
                name="pvc_status",
                status=Status.CRITICAL,
                message=f"{len(unbound)}/{len(pvcs.items)} PVCs not bound",
                details=unbound,
            )

        return CheckResult(
            name="pvc_status",
            status=Status.HEALTHY,
            message=f"All {len(pvcs.items)} PVCs bound",
        )
    except ImportError:
        return CheckResult(
            name="pvc_status",
            status=Status.WARNING,
            message="kubernetes Python client not installed",
        )
    except Exception as e:
        return CheckResult(
            name="pvc_status",
            status=Status.CRITICAL,
            message=f"Failed to check PVC status: {e}",
        )


def check_certificates(namespace: str = "nexusdeploy") -> CheckResult:
    """Check cert-manager Certificate resources."""
    logger.info("Checking TLS certificates in namespace: %s", namespace)
    try:
        from kubernetes import client as k8s_client, config as k8s_config
        from kubernetes.client import CustomObjectsApi

        try:
            k8s_config.load_incluster_config()
        except k8s_config.ConfigException:
            k8s_config.load_kube_config()

        custom = CustomObjectsApi()
        certs = custom.list_namespaced_custom_object(
            group="cert-manager.io",
            version="v1",
            namespace=namespace,
            plural="certificates",
        )

        not_ready = []
        for cert in certs.get("items", []):
            conditions = cert.get("status", {}).get("conditions", [])
            ready = any(c.get("type") == "Ready" and c.get("status") == "True" for c in conditions)
            if not ready:
                not_ready.append(cert["metadata"]["name"])

        if not_ready:
            return CheckResult(
                name="certificates",
                status=Status.CRITICAL,
                message=f"{len(not_ready)} certificates not ready",
                details=not_ready,
            )

        total = len(certs.get("items", []))
        return CheckResult(
            name="certificates",
            status=Status.HEALTHY,
            message=f"All {total} certificates ready",
        )
    except ImportError:
        return CheckResult(
            name="certificates",
            status=Status.WARNING,
            message="kubernetes Python client not installed",
        )
    except Exception as e:
        return CheckResult(
            name="certificates",
            status=Status.WARNING,
            message=f"Could not check certificates (cert-manager may not be installed): {e}",
        )


def print_results(results: list[CheckResult]) -> None:
    """Print check results in a formatted table."""
    status_icon = {Status.HEALTHY: "✓", Status.WARNING: "⚠", Status.CRITICAL: "✗"}
    status_label = {Status.HEALTHY: "HEALTHY ", Status.WARNING: "WARNING ", Status.CRITICAL: "CRITICAL"}

    print(f"\n{'='*70}")
    print(f"  GKE Cluster Health Check - {__import__('datetime').datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}")
    print(f"{'='*70}")

    for r in results:
        icon = status_icon[r.status]
        label = status_label[r.status]
        print(f"  {icon} [{label}] {r.name:<25} {r.message}")
        for detail in r.details:
            print(f"           {'':25}   → {detail}")

    print(f"{'='*70}\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="GKE Cluster Health Checker")
    parser.add_argument("--cluster", required=True, help="GKE cluster name")
    parser.add_argument("--zone", required=True, help="GKE cluster zone/region")
    parser.add_argument("--project", help="GCP project ID")
    parser.add_argument("--namespace", default="nexusdeploy", help="Kubernetes namespace (default: nexusdeploy)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    results = [
        check_cluster_status(args.cluster, args.zone, args.project),
        check_node_health(args.namespace),
        check_pod_status(args.namespace),
        check_pvc_status(args.namespace),
        check_certificates(args.namespace),
    ]

    print_results(results)

    worst = max(r.status for r in results)
    if worst == Status.HEALTHY:
        logger.info("All checks passed")
    elif worst == Status.WARNING:
        logger.warning("Some checks returned warnings")
    else:
        logger.error("Critical issues detected")

    return int(worst)


if __name__ == "__main__":
    sys.exit(main())
