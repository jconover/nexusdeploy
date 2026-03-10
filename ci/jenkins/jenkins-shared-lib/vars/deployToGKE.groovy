#!/usr/bin/env groovy
/**
 * deployToGKE – Reusable shared-library step for GKE deployments.
 *
 * Usage in Jenkinsfile:
 *   deployToGKE(
 *       environment:            'dev',
 *       cluster:                'nexusdeploy-dev',
 *       region:                 'us-central1',
 *       manifestDir:            'kubernetes/',
 *       imageTag:               env.IMAGE_TAG,
 *       gcpKeyCredential:       'gcp-sa-key',
 *       namespace:              'default',         // optional
 *       verifyRollout:          true,              // optional, default true
 *       rolloutTimeoutMinutes:  10                 // optional, default 5
 *   )
 */
def call(Map config = [:]) {
    // ── Defaults ──────────────────────────────────────────────────────────────
    String environment            = config.environment            ?: error('environment is required')
    String cluster                = config.cluster                ?: error('cluster is required')
    String region                 = config.region                 ?: 'us-central1'
    String manifestDir            = config.manifestDir            ?: 'kubernetes/'
    String imageTag               = config.imageTag               ?: error('imageTag is required')
    String gcpKeyCredential       = config.gcpKeyCredential       ?: 'gcp-sa-key'
    String namespace              = config.namespace              ?: environment
    boolean verifyRollout         = config.containsKey('verifyRollout') ? config.verifyRollout : true
    int rolloutTimeoutMinutes     = config.rolloutTimeoutMinutes  ?: 5
    String project                = config.project                ?: env.GCP_PROJECT

    echo "==> deployToGKE: ${environment} | cluster=${cluster} | tag=${imageTag}"

    withCredentials([file(credentialsId: gcpKeyCredential, variable: 'GCP_KEY')]) {
        // ── Authenticate ──────────────────────────────────────────────────────
        sh """
            gcloud auth activate-service-account --key-file="\${GCP_KEY}"
            gcloud container clusters get-credentials ${cluster} \
                --region ${region} \
                --project ${project}
        """

        // ── Ensure namespace exists ────────────────────────────────────────────
        sh "kubectl get namespace ${namespace} || kubectl create namespace ${namespace}"

        // ── Update image tags in manifests ────────────────────────────────────
        sh """
            # Replace placeholder image tags with the current build tag
            find ${manifestDir} -name '*.yaml' -o -name '*.yml' | \
            xargs grep -l 'IMAGE_TAG_PLACEHOLDER' | \
            xargs sed -i "s|IMAGE_TAG_PLACEHOLDER|${imageTag}|g" || true
        """

        // ── Apply environment-specific overlay (kustomize if present) ─────────
        script {
            def kustomizeOverlay = "${manifestDir}overlays/${environment}"
            def useKustomize = fileExists(kustomizeOverlay)

            if (useKustomize) {
                echo "Applying kustomize overlay: ${kustomizeOverlay}"
                sh """
                    kubectl apply \
                        --kustomize ${kustomizeOverlay} \
                        --namespace ${namespace}
                """
            } else {
                echo "Applying raw manifests from ${manifestDir}"
                sh """
                    kubectl apply \
                        -f ${manifestDir} \
                        --namespace ${namespace} \
                        --recursive
                """
            }
        }

        // ── Verify rollout ────────────────────────────────────────────────────
        if (verifyRollout) {
            sh """
                # Wait for all deployments in namespace to complete
                kubectl get deployments -n ${namespace} -o name | while read dep; do
                    echo "Waiting for rollout: \$dep"
                    kubectl rollout status "\$dep" \
                        -n ${namespace} \
                        --timeout=${rolloutTimeoutMinutes}m
                done
            """

            // Health check – look for a service endpoint
            sh """
                # Give pods a moment to become ready
                sleep 15
                PODS=\$(kubectl get pods -n ${namespace} --field-selector=status.phase=Running -o name | wc -l)
                echo "Running pods in ${namespace}: \$PODS"
                if [ "\$PODS" -eq 0 ]; then
                    echo "ERROR: No running pods in namespace ${namespace}"
                    kubectl get pods -n ${namespace}
                    kubectl describe pods -n ${namespace}
                    exit 1
                fi
                echo "Rollout verified: \$PODS pods running"
            """
        }
    }

    echo "==> deployToGKE completed successfully for ${environment}"
}

/**
 * rollbackGKE – Roll back all deployments in a namespace to the previous revision.
 *
 * Usage:
 *   rollbackGKE(environment: 'prod', cluster: 'nexusdeploy-prod', region: 'us-central1')
 */
def rollback(Map config = [:]) {
    String environment      = config.environment      ?: error('environment is required')
    String cluster          = config.cluster          ?: error('cluster is required')
    String region           = config.region           ?: 'us-central1'
    String namespace        = config.namespace        ?: environment
    String gcpKeyCredential = config.gcpKeyCredential ?: 'gcp-sa-key'
    String project          = config.project          ?: env.GCP_PROJECT

    echo "==> rollbackGKE: reverting ${environment} namespace ${namespace}"

    withCredentials([file(credentialsId: gcpKeyCredential, variable: 'GCP_KEY')]) {
        sh """
            gcloud auth activate-service-account --key-file="\${GCP_KEY}"
            gcloud container clusters get-credentials ${cluster} \
                --region ${region} \
                --project ${project}

            kubectl get deployments -n ${namespace} -o name | while read dep; do
                echo "Rolling back \$dep"
                kubectl rollout undo "\$dep" -n ${namespace} || true
            done

            # Wait for rollback to complete
            kubectl get deployments -n ${namespace} -o name | while read dep; do
                kubectl rollout status "\$dep" -n ${namespace} --timeout=5m || true
            done
        """
    }

    echo "==> rollbackGKE completed for ${environment}"
}
