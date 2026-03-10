#!/usr/bin/env bash
# readiness.sh — Check service readiness: HTTP endpoints, DNS, TLS certificates
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── State ─────────────────────────────────────────────────────────────────────
PASS=0
WARN=0
FAIL=0
declare -a RESULTS=()

# ── Helpers ───────────────────────────────────────────────────────────────────
log_pass() { echo -e "${GREEN}✓${NC} $*"; PASS=$((PASS+1)); RESULTS+=("PASS|$*"); }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; WARN=$((WARN+1)); RESULTS+=("WARN|$*"); }
log_fail() { echo -e "${RED}✗${NC} $*"; FAIL=$((FAIL+1)); RESULTS+=("FAIL|$*"); }
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
section()  { echo -e "\n${BOLD}── $* ──${NC}"; }

# ── HTTP endpoint check ───────────────────────────────────────────────────────
check_http() {
    local name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local timeout="${4:-10}"

    if ! command -v curl &>/dev/null; then
        log_warn "${name}: curl not found, skipping"
        return
    fi

    local http_code
    http_code=$(curl -sk --max-time "${timeout}" -o /dev/null -w "%{http_code}" "${url}" 2>/dev/null || echo "000")

    if [[ "${http_code}" == "${expected_status}" ]]; then
        log_pass "${name}: HTTP ${http_code} (${url})"
    elif [[ "${http_code}" == "000" ]]; then
        log_fail "${name}: Connection refused / timeout (${url})"
    else
        log_warn "${name}: HTTP ${http_code} (expected ${expected_status}) (${url})"
    fi
}

# ── DNS resolution check ──────────────────────────────────────────────────────
check_dns() {
    local hostname="$1"

    if nslookup "${hostname}" &>/dev/null 2>&1 || dig +short "${hostname}" &>/dev/null 2>&1; then
        log_pass "DNS: ${hostname} resolves"
    else
        log_fail "DNS: ${hostname} does not resolve"
    fi
}

# ── TLS certificate expiry check ──────────────────────────────────────────────
check_cert() {
    local hostname="$1"
    local port="${2:-443}"
    local warn_days="${3:-30}"

    if ! command -v openssl &>/dev/null; then
        log_warn "CERT ${hostname}: openssl not found, skipping"
        return
    fi

    local expiry_date
    expiry_date=$(echo | openssl s_client -servername "${hostname}" -connect "${hostname}:${port}" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "")

    if [[ -z "${expiry_date}" ]]; then
        log_warn "CERT ${hostname}: Could not retrieve certificate"
        return
    fi

    local expiry_epoch now_epoch days_left
    expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "${expiry_date}" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

    if [[ ${days_left} -le 0 ]]; then
        log_fail "CERT ${hostname}: EXPIRED (${expiry_date})"
    elif [[ ${days_left} -le ${warn_days} ]]; then
        log_warn "CERT ${hostname}: Expires in ${days_left} days (${expiry_date})"
    else
        log_pass "CERT ${hostname}: Valid for ${days_left} days (expires ${expiry_date})"
    fi
}

# ── Kubernetes service check ──────────────────────────────────────────────────
check_k8s_deployment() {
    local name="$1"
    local namespace="${2:-nexusdeploy}"

    if ! command -v kubectl &>/dev/null; then
        log_warn "K8S ${name}: kubectl not found, skipping"
        return
    fi

    local desired available
    desired=$(kubectl get deployment "${name}" -n "${namespace}" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
    available=$(kubectl get deployment "${name}" -n "${namespace}" \
        -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")

    if [[ -z "${desired}" ]]; then
        log_fail "K8S ${name}: Deployment not found in ${namespace}"
    elif [[ "${available}" -ge "${desired}" ]]; then
        log_pass "K8S ${name}: ${available}/${desired} replicas available"
    elif [[ "${available}" -gt 0 ]]; then
        log_warn "K8S ${name}: ${available}/${desired} replicas available (degraded)"
    else
        log_fail "K8S ${name}: 0/${desired} replicas available"
    fi
}

# ── Summary table ─────────────────────────────────────────────────────────────
print_summary() {
    local total=$((PASS + WARN + FAIL))
    echo ""
    echo -e "${BOLD}┌─────────────────────────────────┐${NC}"
    echo -e "${BOLD}│       Readiness Summary         │${NC}"
    echo -e "${BOLD}├──────────┬──────────┬────────────┤${NC}"
    echo -e "${BOLD}│${NC} ${GREEN}PASS: %-3d${NC} ${BOLD}│${NC} ${YELLOW}WARN: %-3d${NC} ${BOLD}│${NC} ${RED}FAIL: %-4d${NC} ${BOLD}│${NC}" "${PASS}" "${WARN}" "${FAIL}"
    echo -e "${BOLD}└──────────┴──────────┴────────────┘${NC}"
    echo -e "  Total checks: ${total}"
    echo ""

    if [[ ${FAIL} -gt 0 ]]; then
        echo -e "${RED}${BOLD}RESULT: NOT READY (${FAIL} failures)${NC}"
        return 2
    elif [[ ${WARN} -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}RESULT: DEGRADED (${WARN} warnings)${NC}"
        return 1
    else
        echo -e "${GREEN}${BOLD}RESULT: READY${NC}"
        return 0
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    local env="${NEXUSDEPLOY_ENV:-development}"
    local api_host="${API_HOST:-localhost}"
    local api_port="${API_PORT:-8080}"
    local auth_port="${AUTH_PORT:-8081}"
    local ingress_host="${INGRESS_HOST:-}"

    echo -e "${BOLD}NexusDeploy Readiness Check — $(date -u '+%Y-%m-%d %H:%M UTC')${NC}"
    echo -e "Environment: ${env}"

    # ── HTTP Health Endpoints ──────────────────────────────────────────────────
    section "HTTP Health Endpoints"
    check_http "api-gateway /health"  "http://${api_host}:${api_port}/health"
    check_http "api-gateway /ready"   "http://${api_host}:${api_port}/ready"
    check_http "auth-service /health" "http://${api_host}:${auth_port}/health"
    check_http "auth-service /ready"  "http://${api_host}:${auth_port}/ready"

    # ── DNS ────────────────────────────────────────────────────────────────────
    section "DNS Resolution"
    check_dns "api-gateway"
    check_dns "auth-service"
    check_dns "redis"
    if [[ -n "${ingress_host}" ]]; then
        check_dns "${ingress_host}"
    fi

    # ── TLS Certificates ──────────────────────────────────────────────────────
    if [[ -n "${ingress_host}" ]]; then
        section "TLS Certificates"
        check_cert "${ingress_host}" 443 30
    fi

    # ── Kubernetes Deployments ────────────────────────────────────────────────
    section "Kubernetes Deployments"
    local namespace="nexusdeploy"
    [[ "${env}" == "dev" ]]     && namespace="nexusdeploy-dev"
    [[ "${env}" == "staging" ]] && namespace="nexusdeploy-staging"

    check_k8s_deployment "api-gateway"   "${namespace}"
    check_k8s_deployment "auth-service"  "${namespace}"
    check_k8s_deployment "worker-service" "${namespace}"

    # ── Final Summary ─────────────────────────────────────────────────────────
    print_summary
}

main "$@"
