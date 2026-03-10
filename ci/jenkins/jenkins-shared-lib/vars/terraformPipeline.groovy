#!/usr/bin/env groovy
/**
 * terraformPipeline – Reusable shared-library step for Terraform operations.
 *
 * Usage in Jenkinsfile:
 *   terraformPipeline(
 *       environment:     'dev',
 *       action:          'apply',          // plan | apply | destroy
 *       gcpKeyCredential:'gcp-sa-key',
 *       autoApprove:     true,             // false shows plan output and pauses
 *       planOutput:      'dev.tfplan',     // optional plan file name
 *       tfVarsFile:      'terraform.tfvars' // optional
 *   )
 */
def call(Map config = [:]) {
    String environment     = config.environment     ?: error('environment is required')
    String action          = config.action          ?: 'plan'
    String gcpKeyCredential = config.gcpKeyCredential ?: 'gcp-sa-key'
    boolean autoApprove    = config.containsKey('autoApprove') ? config.autoApprove : false
    String planOutput      = config.planOutput      ?: "${environment}.tfplan"
    String tfVarsFile      = config.tfVarsFile      ?: "terraform.tfvars"
    String tfDir           = "terraform/environments/${environment}"
    String backendCfg      = "${tfDir}/backend.hcl"

    echo "==> terraformPipeline: action=${action} env=${environment} autoApprove=${autoApprove}"

    withCredentials([file(credentialsId: gcpKeyCredential, variable: 'GCP_KEY')]) {
        sh """
            export GOOGLE_APPLICATION_CREDENTIALS="\${GCP_KEY}"
            gcloud auth activate-service-account --key-file="\${GCP_KEY}"
        """

        dir(tfDir) {
            // ── Init ──────────────────────────────────────────────────────────
            sh """
                terraform init \
                    -backend-config=backend.hcl \
                    -reconfigure \
                    -input=false
            """

            // ── Validate ─────────────────────────────────────────────────────
            sh 'terraform validate'

            switch (action) {
                case 'plan':
                    _terraformPlan(planOutput, tfVarsFile)
                    break

                case 'apply':
                    _terraformPlan(planOutput, tfVarsFile)

                    if (!autoApprove) {
                        // Show plan summary and require human approval
                        sh "terraform show -no-color ${planOutput}"
                        timeout(time: 30, unit: 'MINUTES') {
                            input(
                                message: "Review Terraform plan for ${environment}. Apply?",
                                ok: 'Apply',
                                submitter: 'jenkins-admins,terraform-approvers'
                            )
                        }
                    }

                    sh """
                        terraform apply \
                            -input=false \
                            -parallelism=10 \
                            ${planOutput}
                    """

                    // Archive outputs for downstream stages
                    sh """
                        terraform output -json > terraform-outputs-${environment}.json
                        echo "Outputs saved to terraform-outputs-${environment}.json"
                    """
                    archiveArtifacts artifacts: "terraform-outputs-${environment}.json", allowEmptyArchive: true
                    break

                case 'destroy':
                    timeout(time: 10, unit: 'MINUTES') {
                        input(
                            message: "DESTRUCTIVE: Destroy ${environment} infrastructure?",
                            ok: 'Destroy',
                            submitter: 'jenkins-admins'
                        )
                    }
                    sh """
                        terraform destroy \
                            -var-file=${tfVarsFile} \
                            -auto-approve \
                            -input=false
                    """
                    break

                default:
                    error("Unknown Terraform action: ${action}. Use plan, apply, or destroy.")
            }
        }
    }

    echo "==> terraformPipeline completed: ${action} on ${environment}"
}

private void _terraformPlan(String planOutput, String tfVarsFile) {
    sh """
        terraform plan \
            -var-file=${tfVarsFile} \
            -out=${planOutput} \
            -input=false \
            -detailed-exitcode || PLAN_EXIT=\$?

        # exit code 0 = no changes, 1 = error, 2 = changes present (all OK for us)
        if [ "\${PLAN_EXIT:-0}" -eq 1 ]; then
            echo "Terraform plan failed"
            exit 1
        fi
    """
    archiveArtifacts artifacts: planOutput, allowEmptyArchive: true
}

/**
 * notifySlack – Thin wrapper to send Slack notifications from pipeline steps.
 *
 * Usage:
 *   notifySlack(channel: '#deployments', status: 'success', message: 'Deployed v1.2.3')
 */
def notifySlack(Map config = [:]) {
    String channel = config.channel ?: '#general'
    String status  = config.status  ?: 'info'
    String message = config.message ?: ''

    def colors = [success: 'good', failure: 'danger', warning: 'warning', info: '#439FE0', approval_required: '#FFA500']
    def color  = colors[status] ?: '#439FE0'

    withCredentials([string(credentialsId: 'slack-webhook-url', variable: 'SLACK_URL')]) {
        sh """
            curl -s -X POST \${SLACK_URL} \
                -H 'Content-type: application/json' \
                --data '{
                    "channel": "${channel}",
                    "attachments": [{
                        "color": "${color}",
                        "title": "NexusDeploy CI/CD [${status.toUpperCase()}]",
                        "text": "${message}",
                        "footer": "Jenkins Build #${env.BUILD_NUMBER} | ${env.JOB_NAME}",
                        "ts": '$(date +%s)'
                    }]
                }' || true
        """
    }
}
