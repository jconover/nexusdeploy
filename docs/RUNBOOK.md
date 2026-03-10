# NexusDeploy Operations Runbook

This runbook covers operational procedures for the NexusDeploy platform. It is the first document to consult during incidents and planned maintenance.

**On-call rotation**: Managed via PagerDuty. Escalation paths are in the team wiki.
**Incident severity definitions**: P1 (service down), P2 (degraded, SLO at risk), P3 (minor degradation), P4 (no user impact).

---

## Table of Contents

1. [Deployment Procedures](#1-deployment-procedures)
2. [Rollback Procedures](#2-rollback-procedures)
3. [Scaling Procedures](#3-scaling-procedures)
4. [Secret Rotation](#4-secret-rotation)
5. [Incident Response Playbook](#5-incident-response-playbook)
6. [Common Troubleshooting](#6-common-troubleshooting)
7. [Maintenance Windows](#7-maintenance-windows)
8. [Backup and Restore](#8-backup-and-restore)
9. [Disaster Recovery](#9-disaster-recovery)

---

## 1. Deployment Procedures

### 1.1 Standard Application Deployment (via CI/CD)

All production deployments should go through the CI/CD pipeline. Manual deployment is only for emergencies.

**Standard flow:**
1. Merge PR to `main` branch
2. CI pipeline runs automatically: lint → test → security scan → build → deploy dev → integration tests → deploy staging
3. Staging smoke tests pass automatically
4. Engineer reviews staging deployment and approves the pipeline gate
5. CI deploys to production using canary strategy (5% → 20% → 100%)
6. Monitor SLO dashboards for 30 minutes post-deploy

### 1.2 Emergency Manual Deployment

Use only when CI/CD is unavailable and the change is urgent.

```bash
# Authenticate
gcloud auth login
gcloud container clusters get-credentials nexusdeploy-prod \
  --region us-central1 --project YOUR_PROJECT_ID

# Deploy specific image
helm upgrade nexusdeploy kubernetes/helm/nexusdeploy \
  --namespace production \
  --set image.tag=SHA_OR_TAG \
  --set canary.enabled=false \
  --wait --timeout 10m

# Verify
kubectl rollout status deployment/api-gateway -n production
python scripts/health-checks/verify_deployment.py --env prod
```

### 1.3 Infrastructure Changes (Terraform)

```bash
cd terraform/environments/prod
terraform init
terraform plan -out=tfplan

# Review the plan carefully — share with team for changes affecting VPC, GKE, or Cloud SQL
terraform apply tfplan
```

**Never** run `terraform apply` without a saved plan file in production.

---

## 2. Rollback Procedures

### 2.1 Application Rollback (Helm)

```bash
# List recent releases
helm history nexusdeploy -n production

# Rollback to previous release
helm rollback nexusdeploy -n production

# Rollback to specific revision
helm rollback nexusdeploy REVISION_NUMBER -n production --wait
```

### 2.2 Rollback via CI/CD Pipeline

The recommended approach: create a revert commit pointing to the last known-good image SHA, and run through the pipeline. This preserves the audit trail.

```bash
git revert HEAD --no-edit
git push origin main
# CI pipeline will deploy the reverted commit
```

### 2.3 Canary Abort

If the canary stage is in progress and metrics are degrading:

```bash
# Immediately shift all traffic away from canary
helm upgrade nexusdeploy kubernetes/helm/nexusdeploy \
  --namespace production \
  --set canary.weight=0 \
  --wait

# Then roll back
helm rollback nexusdeploy -n production
```

### 2.4 Terraform Rollback

Terraform state changes are tracked in GCS with versioning. To revert:

```bash
# List state versions in GCS
gsutil ls -la gs://YOUR_PROJECT_ID-tfstate/prod/terraform.tfstate

# Restore a previous state version
gsutil cp gs://YOUR_PROJECT_ID-tfstate/prod/terraform.tfstate#VERSION_ID \
  gs://YOUR_PROJECT_ID-tfstate/prod/terraform.tfstate

# Re-plan to confirm the desired state
terraform plan
```

---

## 3. Scaling Procedures

### 3.1 Manual HPA Scaling (Emergency)

```bash
# Scale up immediately (bypasses HPA)
kubectl scale deployment/worker-service \
  --replicas=20 -n production

# Verify
kubectl get pods -n production -l app=worker-service

# Return to HPA control after incident
kubectl scale deployment/worker-service \
  --replicas=5 -n production
# HPA will take over based on metrics
```

### 3.2 Node Pool Scaling

```bash
# Resize node pool immediately
gcloud container clusters resize nexusdeploy-prod \
  --node-pool=application \
  --num-nodes=10 \
  --region=us-central1

# Update Terraform to persist the change
# Edit terraform/environments/prod/terraform.tfvars:
# gke_application_pool_min = 3
# gke_application_pool_max = 15
```

### 3.3 Cloud SQL Read Replica Scaling

If read query load is high, promote or add a read replica:

```bash
# Create an additional read replica via Terraform
# In terraform/environments/prod/terraform.tfvars:
# cloud_sql_read_replica_count = 2
terraform apply -target=module.cloud_sql
```

---

## 4. Secret Rotation

### 4.1 Rotating Database Credentials

```bash
# 1. Generate new password
NEW_PASS=$(openssl rand -base64 32)

# 2. Add new version to Secret Manager
echo -n "$NEW_PASS" | gcloud secrets versions add nexusdeploy-db-password \
  --data-file=-

# 3. Update Cloud SQL user password
gcloud sql users set-password nexusdeploy \
  --instance=nexusdeploy-prod \
  --password="$NEW_PASS"

# 4. Trigger rolling restart of affected deployments
kubectl rollout restart deployment/api-gateway deployment/auth-service -n production

# 5. Verify new pods start successfully
kubectl rollout status deployment/api-gateway -n production

# 6. Disable the old secret version (after 24h grace period)
OLD_VERSION=$(gcloud secrets versions list nexusdeploy-db-password \
  --filter="state=ENABLED" --format="value(name)" | sort | head -1)
gcloud secrets versions disable "$OLD_VERSION" \
  --secret=nexusdeploy-db-password
```

### 4.2 Rotating API Keys (External Services)

1. Obtain new key from the external provider
2. Add to Secret Manager: `gcloud secrets versions add SECRET_NAME --data-file=<(echo -n NEW_KEY)`
3. Rolling restart the consuming service
4. Verify logs show successful authentication with new key
5. Revoke the old key from the external provider's console
6. Disable old secret version after 24h

### 4.3 Rotating TLS Certificates

Certificates managed by Certificate Manager are rotated automatically. For manually managed certificates:

```bash
# Add new cert version
gcloud secrets versions add nexusdeploy-tls-cert --data-file=new-cert.pem
gcloud secrets versions add nexusdeploy-tls-key --data-file=new-key.pem

# Rolling restart
kubectl rollout restart deployment/api-gateway -n production
```

---

## 5. Incident Response Playbook

### 5.1 Incident Severity and Response Times

| Severity | Definition | Initial Response | Escalation |
|----------|-----------|-----------------|------------|
| P1 | Service down, >10% error rate | 5 minutes | 15 minutes to on-call lead |
| P2 | SLO at risk, >1% error rate | 15 minutes | 1 hour |
| P3 | Minor degradation, no SLO risk | 1 hour | Next business day |
| P4 | No user impact | Next business day | — |

### 5.2 P1 Response Checklist

```
[ ] Acknowledge PagerDuty alert within 5 minutes
[ ] Open incident channel: #incident-YYYY-MM-DD in Slack
[ ] Post initial status to status page (even if "investigating")
[ ] Check Cloud Monitoring dashboard for spike in error rate or latency
[ ] Check recent deployments: helm history nexusdeploy -n production
[ ] If recent deployment: initiate rollback (Section 2.1)
[ ] If no recent deployment: check GCP service health dashboard
[ ] Identify blast radius: which services are affected?
[ ] Assign roles: Incident Commander, Tech Lead, Comms
[ ] Update status page every 15 minutes until resolved
[ ] Post-incident review within 48 hours
```

### 5.3 Common Incident Patterns

**High error rate after deployment**: Roll back (Section 2.1), then investigate root cause in staging.

**Database connection exhaustion**: Check PgBouncer pool stats, scale down high-connection pods temporarily, review connection pool configuration.

**OOMKilled pods**: Check `kubectl describe pod POD_NAME -n production` for memory limit; temporarily increase limits via Helm override; follow up with VPA recommendation.

**GKE node NotReady**: Check `kubectl describe node NODE_NAME`; drain and cordon the node; node auto-repair should replace it within 10 minutes.

---

## 6. Common Troubleshooting

### 6.1 Pod CrashLoopBackOff

```bash
# Check events and logs
kubectl describe pod POD_NAME -n production
kubectl logs POD_NAME -n production --previous

# Common causes:
# - Secret not found: verify gcloud secrets versions list SECRET_NAME
# - Database unreachable: check Cloud SQL private IP and firewall rules
# - OOMKilled: check memory limits in helm values
```

### 6.2 Service Unreachable (504 from Load Balancer)

```bash
# Check backend health
kubectl get endpoints SERVICE_NAME -n production
kubectl get pods -n production -l app=SERVICE_NAME

# Check ingress
kubectl describe ingress nexusdeploy -n production

# Check GCP backend service health
gcloud compute backend-services get-health BACKEND_SERVICE_NAME --global
```

### 6.3 Terraform Plan Shows Unexpected Destroy

```bash
# Do NOT apply if you see unexpected resource destruction
# Check if state drift occurred
terraform refresh
terraform plan

# If drift is confirmed, investigate why the resource changed outside Terraform
# Never use terraform taint or terraform import without peer review in prod
```

### 6.4 Vertex AI Endpoint Returning Errors

```bash
# Check endpoint status
gcloud ai endpoints describe ENDPOINT_ID --region=us-central1

# Check deployed model
gcloud ai endpoints list-deployed-models ENDPOINT_ID --region=us-central1

# Check Cloud Logging for prediction errors
gcloud logging read 'resource.type="aiplatform.googleapis.com/Endpoint"
  AND severity>=ERROR' --limit=50 --format=json
```

### 6.5 Cloud Functions Not Processing Events

```bash
# Check subscription backlog
gcloud pubsub subscriptions describe SUBSCRIPTION_NAME

# Check function logs
gcloud functions logs read FUNCTION_NAME --limit=100

# Check IAM — function service account must have pubsub.subscriber role
gcloud projects get-iam-policy PROJECT_ID \
  --filter="bindings.members:serviceAccount:FUNCTION_SA"
```

---

## 7. Maintenance Windows

### 7.1 Scheduled Maintenance Policy

| Environment | Window | Frequency | Approval Required |
|------------|--------|-----------|------------------|
| dev | Anytime | As needed | No |
| staging | Weekdays 06:00–08:00 UTC | Weekly | Team lead |
| prod | Sundays 02:00–06:00 UTC | Monthly (or as needed) | Change advisory board |

### 7.2 GKE Node Upgrade Procedure

GKE node upgrades are triggered automatically during maintenance windows when `auto_upgrade = true` is set. For manual upgrades:

```bash
# Upgrade control plane first
gcloud container clusters upgrade nexusdeploy-prod \
  --master --cluster-version=TARGET_VERSION \
  --region=us-central1

# Upgrade node pool (one pool at a time)
gcloud container clusters upgrade nexusdeploy-prod \
  --node-pool=application \
  --cluster-version=TARGET_VERSION \
  --region=us-central1
```

### 7.3 Cloud SQL Maintenance

Maintenance is scheduled via the Cloud SQL instance settings. For emergency patching:

1. Trigger maintenance in Cloud Console (Database → Maintenance)
2. HA failover happens automatically to standby replica
3. Verify connection pool reconnects within 60 seconds
4. Monitor error rate during and after

---

## 8. Backup and Restore

### 8.1 Cloud SQL Backup Status

```bash
# List recent automated backups
gcloud sql backups list --instance=nexusdeploy-prod

# Trigger manual backup before high-risk operations
gcloud sql backups create --instance=nexusdeploy-prod
```

### 8.2 Restore Cloud SQL from Backup

```bash
# List available backups
gcloud sql backups list --instance=nexusdeploy-prod --format="table(id,status,startTime)"

# Restore to same instance (WARNING: overwrites current data)
gcloud sql backups restore BACKUP_ID \
  --restore-instance=nexusdeploy-prod

# Restore to a new instance (safer for verification)
gcloud sql backups restore BACKUP_ID \
  --restore-instance=nexusdeploy-restore-test \
  --backup-instance=nexusdeploy-prod
```

### 8.3 GCS Data Backup

Application data stored in GCS is protected by:
- Object versioning (enabled on all buckets)
- Cross-region replication (prod only)
- Retention policies preventing deletion within the retention window

```bash
# Restore a deleted or overwritten object
gsutil cp gs://BUCKET/path/to/object#GENERATION_NUMBER \
  gs://BUCKET/path/to/object
```

---

## 9. Disaster Recovery

### 9.1 Region Failover (< 45 minute RTO)

Execute when the primary region (us-central1) is unavailable:

```bash
# Step 1: Promote Cloud SQL read replica in DR region (us-east1)
gcloud sql instances promote-replica nexusdeploy-prod-replica-us-east1

# Step 2: Deploy infrastructure in DR region
cd terraform/environments/prod
# Update region in tfvars: region = "us-east1"
terraform init -reconfigure
terraform apply -var-file=dr.tfvars

# Step 3: Update GKE credentials
gcloud container clusters get-credentials nexusdeploy-prod-dr \
  --region us-east1 --project YOUR_PROJECT_ID

# Step 4: Deploy application
helm upgrade --install nexusdeploy kubernetes/helm/nexusdeploy \
  --namespace production \
  --values kubernetes/helm/nexusdeploy/values-dr.yaml \
  --wait

# Step 5: Update DNS to point to DR region load balancer
gcloud dns record-sets update api.nexusdeploy.example.com \
  --rrdatas=DR_LB_IP --ttl=60 --type=A \
  --zone=nexusdeploy-zone

# Step 6: Verify
python scripts/health-checks/verify_deployment.py --env prod-dr

# Step 7: Communicate status
# Update status page, notify stakeholders
```

### 9.2 Data Validation After DR Failover

After promotion of the read replica, validate data integrity:

```bash
python scripts/health-checks/db_integrity_check.py \
  --host DR_SQL_IP \
  --expected-row-counts scripts/health-checks/expected_counts.json
```

### 9.3 Failback to Primary Region

After the primary region recovers:

1. Confirm primary region is stable (wait for GCP incident to resolve)
2. Sync data from DR replica back to primary (Cloud SQL replication)
3. Promote primary instance
4. Update DNS back to primary region
5. Run integrity checks
6. Mark incident resolved
7. Conduct post-mortem within 48 hours

---

## Appendix: Useful Commands Reference

```bash
# Check cluster info
kubectl cluster-info
kubectl get nodes -o wide

# View all workloads
kubectl get all -n production

# Check resource usage
kubectl top nodes
kubectl top pods -n production

# View recent events
kubectl get events -n production --sort-by='.lastTimestamp' | tail -20

# Get logs with timestamps
kubectl logs -f deployment/api-gateway -n production --timestamps

# Port-forward for local debugging (never in prod unless emergency)
kubectl port-forward svc/api-gateway 8080:80 -n production

# GCP audit log for IAM changes
gcloud logging read 'protoPayload.serviceName="iam.googleapis.com"
  AND protoPayload.methodName=~"setIamPolicy"' \
  --freshness=24h --format=json | jq '.[] | .protoPayload.request'
```
