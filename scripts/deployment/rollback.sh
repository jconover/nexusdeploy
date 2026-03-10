#!/usr/bin/env bash
# rollback.sh — Rollback a deployment to a previous version
# Usage: ./rollback.sh <environment> <service> [version]
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

# ── Args ──────────────────────────────────────────────────────────────────────
ENVIRONMENT="${1:-}"
SERVICE="${2:-}"
VERSION="${3:-}"  # Optional: roll back to specific image tag; omit for previous revision

if [[ -z "${ENVIRONMENT}" || -z "${SERVICE}" ]]; then
    echo -e "${RED}Usage: $0 <environment> <service> [version]${NC}"
    echo -e "  environment: dev | staging | prod"
    echo -e "  service:     api-gateway | auth-service | worker-service | all"
    echo -e "  version:     (optional) image tag to roll back to"
    exit 1
fi

VALID_ENVS="dev staging prod"
VALID_SVCS="api-gateway auth-service worker-service all"

if ! echo "${VALID_ENVS}" | grep -qw "${ENVIRONMENT}"; then
    echo -e "${RED}Invalid environment: ${ENVIRONMENT}${NC}"; exit 1
fi
if ! echo "${VALID_SVCS}" | grep -qw "${SERVICE}"; then
    echo -e "${RED}Invalid service: ${SERVICE}${NC}"; exit 1
fi

# ── Namespace ─────────────────────────────────────────────────────────────────
NAMESPACE="nexusdeploy"
[[ "${ENVIRONMENT}" == "dev" ]]     && NAMESPACE="nexusdeploy-dev"
[[ "${ENVIRONMENT}" == "staging" ]] && NAMESPACE="nexusdeploy-staging"

# ── Services to roll back ─────────────────────────────────────────────────────
if [[ "${SERVICE}" == "all" ]]; then
    SERVICES=("api-gateway" "auth-service" "worker-service")
else
    SERVICES=("${SERVICE}")
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
log()  { echo -e "${BOLD}[$(date -u '+%H:%M:%S')]${NC} $*"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✗${NC} $*"; }

check_prereqs() {
    if ! command -v kubectl &>/dev/null; then
        fail "kubectl not found in PATH"; exit 1
    fi
    log "kubectl version: $(kubectl version --client --short 2>/dev/null | head -1)"
}

get_current_image() {
    local svc="$1"
    kubectl get deployment "${svc}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "unknown"
}

rollback_to_version() {
    local svc="$1"
    local version="$2"
    local registry="${REGISTRY:-}"

    local image="${registry}/${svc}:${version}"
    [[ -z "${registry}" ]] && image="${svc}:${version}"

    log "Setting image: ${svc} -> ${image}"
    if ! kubectl set image "deployment/${svc}" "${svc}=${image}" -n "${NAMESPACE}"; then
        fail "Failed to set image for ${svc}"; return 1
    fi
}

rollback_to_previous() {
    local svc="$1"
    log "Rolling back ${svc} to previous revision"

    if ! kubectl rollout undo "deployment/${svc}" -n "${NAMESPACE}"; then
        fail "kubectl rollout undo failed for ${svc}"; return 1
    fi
}

wait_for_rollout() {
    local svc="$1"
    log "Waiting for rollout: ${svc}..."
    if kubectl rollout status "deployment/${svc}" -n "${NAMESPACE}" --timeout=300s; then
        ok "${svc} rollback complete"
        return 0
    else
        fail "${svc} rollback did not complete within timeout"
        return 1
    fi
}

verify_rollback() {
    local svc="$1"
    local new_image
    new_image=$(get_current_image "${svc}")

    log "Verifying ${svc}..."
    local ready
    ready=$(kubectl get deployment "${svc}" -n "${NAMESPACE}" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
    local desired
    desired=$(kubectl get deployment "${svc}" -n "${NAMESPACE}" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo 1)

    if [[ "${ready}" -ge "${desired}" ]]; then
        ok "${svc}: ${ready}/${desired} ready — image: ${new_image}"
        return 0
    else
        fail "${svc}: only ${ready}/${desired} pods ready"
        return 1
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}NexusDeploy Rollback${NC}"
    echo -e "  Environment : ${ENVIRONMENT}"
    echo -e "  Namespace   : ${NAMESPACE}"
    echo -e "  Services    : ${SERVICES[*]}"
    echo -e "  Version     : ${VERSION:-<previous revision>}"
    echo ""

    check_prereqs

    local failed=0

    for svc in "${SERVICES[@]}"; do
        echo ""
        log "Processing service: ${svc}"
        log "Current image: $(get_current_image "${svc}")"

        if [[ -n "${VERSION}" ]]; then
            rollback_to_version "${svc}" "${VERSION}" || { failed=$((failed+1)); continue; }
        else
            rollback_to_previous "${svc}" || { failed=$((failed+1)); continue; }
        fi

        wait_for_rollout "${svc}"  || { failed=$((failed+1)); continue; }
        verify_rollback "${svc}"   || { failed=$((failed+1)); continue; }
    done

    echo ""
    if [[ ${failed} -eq 0 ]]; then
        ok "All rollbacks completed successfully"
        exit 0
    else
        fail "${failed} service(s) failed to roll back"
        exit 1
    fi
}

main
