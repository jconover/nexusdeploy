#!/usr/bin/env python3
"""GCP Cost Optimization Analyzer.

Analyzes GCP billing data and provides recommendations for cost reduction.
"""
import argparse
import json
import logging
import sys
from datetime import datetime, timedelta
from typing import Any

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


def get_billing_data(project_id: str, days: int) -> list[dict]:
    """Fetch billing data from GCP Cloud Billing API."""
    try:
        from google.cloud import billing_v1  # noqa: F401
    except ImportError:
        logger.warning("google-cloud-billing not installed, using mock data")
        return _mock_billing_data(project_id, days)

    logger.info("Fetching billing data for project %s (last %d days)", project_id, days)
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)

    # In production: use BigQuery billing export for detailed data
    # client = billing_v1.CloudBillingClient()
    # This is a stub; real implementation queries BigQuery billing export
    return _mock_billing_data(project_id, days)


def _mock_billing_data(project_id: str, days: int) -> list[dict]:
    """Return mock billing data for development/testing."""
    return [
        {"service": "Compute Engine", "cost": 450.20, "currency": "USD"},
        {"service": "Cloud Storage", "cost": 45.10, "currency": "USD"},
        {"service": "Cloud SQL", "cost": 180.50, "currency": "USD"},
        {"service": "Kubernetes Engine", "cost": 220.80, "currency": "USD"},
        {"service": "BigQuery", "cost": 30.00, "currency": "USD"},
    ]


def analyze_idle_resources(project_id: str) -> list[dict]:
    """Identify idle or underutilized GCP resources."""
    logger.info("Analyzing idle resources in project %s", project_id)
    idle_resources = []

    try:
        from google.cloud import compute_v1  # noqa: F401
        # In production: query instance utilization metrics from Cloud Monitoring
        # instances_client = compute_v1.InstancesClient()
        logger.info("Would query Compute Engine for idle instances")
    except ImportError:
        logger.warning("google-cloud-compute not installed, using mock data")

    # Mock idle resources
    idle_resources = [
        {
            "type": "compute_instance",
            "name": "dev-vm-001",
            "zone": "us-central1-a",
            "avg_cpu_utilization": 2.1,
            "monthly_cost": 45.60,
            "recommendation": "Stop or delete - average CPU below 5%",
        },
        {
            "type": "compute_instance",
            "name": "staging-worker-002",
            "zone": "us-central1-b",
            "avg_cpu_utilization": 1.8,
            "monthly_cost": 38.40,
            "recommendation": "Rightsize to e2-micro or stop when not needed",
        },
    ]
    logger.info("Found %d idle resources", len(idle_resources))
    return idle_resources


def recommend_rightsizing(project_id: str) -> list[dict]:
    """Generate rightsizing recommendations for compute resources."""
    logger.info("Generating rightsizing recommendations for project %s", project_id)
    recommendations = []

    # Mock recommendations (real: query Recommender API)
    recommendations = [
        {
            "resource": "projects/{}/zones/us-central1-a/instances/api-server-001".format(project_id),
            "current_machine_type": "n1-standard-4",
            "recommended_machine_type": "n1-standard-2",
            "estimated_monthly_savings": 58.40,
            "confidence": "HIGH",
            "reason": "CPU utilization consistently below 30%",
        },
        {
            "resource": "projects/{}/zones/us-central1-b/instances/worker-001".format(project_id),
            "current_machine_type": "n2-standard-8",
            "recommended_machine_type": "n2-standard-4",
            "estimated_monthly_savings": 110.20,
            "confidence": "MEDIUM",
            "reason": "Memory utilization below 40%, CPU below 50%",
        },
    ]
    logger.info("Generated %d rightsizing recommendations", len(recommendations))
    return recommendations


def identify_unattached_disks(project_id: str) -> list[dict]:
    """Find persistent disks not attached to any VM."""
    logger.info("Scanning for unattached disks in project %s", project_id)
    unattached = []

    try:
        from google.cloud import compute_v1  # noqa: F401
        # In production: list all disks and filter by users == []
        logger.info("Would query Compute Engine Disks API")
    except ImportError:
        logger.warning("google-cloud-compute not installed, using mock data")

    # Mock unattached disks
    unattached = [
        {
            "name": "old-data-disk-001",
            "zone": "us-central1-a",
            "size_gb": 500,
            "disk_type": "pd-standard",
            "monthly_cost": 20.00,
            "last_attached": "2025-12-01",
        },
        {
            "name": "backup-disk-deprecated",
            "zone": "us-central1-b",
            "size_gb": 200,
            "disk_type": "pd-ssd",
            "monthly_cost": 34.00,
            "last_attached": "2025-10-15",
        },
    ]
    logger.info("Found %d unattached disks", len(unattached))
    return unattached


def format_table(data: list[dict], title: str) -> str:
    """Format data as a simple ASCII table."""
    if not data:
        return f"\n{title}: No items found.\n"

    lines = [f"\n{'='*60}", f" {title}", f"{'='*60}"]
    for i, item in enumerate(data, 1):
        lines.append(f"\n[{i}]")
        for key, value in item.items():
            lines.append(f"  {key:<35} {value}")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="GCP Cost Optimization Analyzer",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--project", required=True, help="GCP project ID")
    parser.add_argument("--days", type=int, default=30, help="Lookback period in days (default: 30)")
    parser.add_argument(
        "--output",
        choices=["json", "table"],
        default="table",
        help="Output format (default: table)",
    )
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")

    args = parser.parse_args()

    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    logger.info("Starting cost analysis for project: %s", args.project)

    try:
        results: dict[str, Any] = {
            "project": args.project,
            "analysis_date": datetime.utcnow().isoformat(),
            "lookback_days": args.days,
            "billing_summary": get_billing_data(args.project, args.days),
            "idle_resources": analyze_idle_resources(args.project),
            "rightsizing_recommendations": recommend_rightsizing(args.project),
            "unattached_disks": identify_unattached_disks(args.project),
        }

        # Calculate total potential savings
        savings = sum(r.get("estimated_monthly_savings", 0) for r in results["rightsizing_recommendations"])
        savings += sum(d.get("monthly_cost", 0) for d in results["unattached_disks"])
        savings += sum(r.get("monthly_cost", 0) for r in results["idle_resources"])
        results["estimated_monthly_savings_usd"] = round(savings, 2)

        if args.output == "json":
            print(json.dumps(results, indent=2))
        else:
            total_billing = sum(item["cost"] for item in results["billing_summary"])
            print(f"\n{'#'*60}")
            print(f"# GCP Cost Analysis: {args.project}")
            print(f"# Period: last {args.days} days")
            print(f"# Total Spend: ${total_billing:.2f} USD")
            print(f"# Potential Monthly Savings: ${savings:.2f} USD")
            print(f"{'#'*60}")
            print(format_table(results["billing_summary"], "Billing Summary by Service"))
            print(format_table(results["idle_resources"], "Idle Resources"))
            print(format_table(results["rightsizing_recommendations"], "Rightsizing Recommendations"))
            print(format_table(results["unattached_disks"], "Unattached Persistent Disks"))

        return 0

    except Exception as e:
        logger.error("Analysis failed: %s", e, exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
