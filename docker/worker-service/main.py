"""Worker Service - Celery task workers for async processing."""
import logging
import os
import time

from celery import Celery
from celery.utils.log import get_task_logger

logger = get_task_logger(__name__)

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379/0")
GCS_BUCKET = os.getenv("GCS_BUCKET", "nexusdeploy-data")

app = Celery(
    "worker",
    broker=REDIS_URL,
    backend=REDIS_URL,
    include=["main"],
)

app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_acks_late=True,
    worker_prefetch_multiplier=1,
    task_soft_time_limit=300,
    task_time_limit=600,
)


@app.task(bind=True, name="worker.process_data", max_retries=3)
def process_data(self, payload: dict) -> dict:
    """Process incoming data payload."""
    logger.info("Processing data task: %s", self.request.id)
    try:
        # Simulate processing
        time.sleep(0.1)
        result = {
            "task_id": self.request.id,
            "status": "processed",
            "records": len(payload.get("data", [])),
            "timestamp": time.time(),
        }
        logger.info("Data processing complete: %s", result)
        return result
    except Exception as exc:
        logger.error("process_data failed: %s", exc)
        raise self.retry(exc=exc, countdown=2**self.request.retries)


@app.task(bind=True, name="worker.generate_report", max_retries=2)
def generate_report(self, report_config: dict) -> dict:
    """Generate a report and optionally upload to GCS."""
    logger.info("Generating report: %s", report_config.get("name", "unnamed"))
    try:
        report_type = report_config.get("type", "summary")
        output_format = report_config.get("format", "json")

        # Simulate report generation
        time.sleep(0.2)

        result = {
            "task_id": self.request.id,
            "report_name": report_config.get("name", "report"),
            "type": report_type,
            "format": output_format,
            "status": "generated",
            "timestamp": time.time(),
        }

        if report_config.get("upload_to_gcs"):
            result["gcs_path"] = f"gs://{GCS_BUCKET}/reports/{result['report_name']}.{output_format}"
            logger.info("Report would be uploaded to: %s", result["gcs_path"])

        return result
    except Exception as exc:
        logger.error("generate_report failed: %s", exc)
        raise self.retry(exc=exc, countdown=5)


@app.task(name="worker.health_check")
def health_check() -> dict:
    """Health check task for monitoring."""
    return {"status": "healthy", "timestamp": time.time()}


if __name__ == "__main__":
    app.start()
