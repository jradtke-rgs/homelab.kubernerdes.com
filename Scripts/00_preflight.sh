#!/usr/bin/env bash
set -euo pipefail

# 00_preflight.sh — Verify prerequisites before starting deployment
#
# Run as the admin user on nuc-00 before any other script.
# This script checks that all required tools are installed, the environment
# is correctly configured, and the network is reachable.
#
# It does NOT install anything — it only validates and reports.
# Fix any reported issues before proceeding to 02_setup_ca.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${SCRIPT_DIR}/env.sh"

PASS=0
FAIL=0

ok()   { echo "  [OK]   $*";  ((PASS++)); }
fail() { echo "  [FAIL] $*";  ((FAIL++)); }
info() { echo "  [INFO] $*"; }

echo
echo "============================================================"
echo "  Preflight check — ENVIRONMENT=${ENVIRONMENT}"
echo "  BASE_DOMAIN=${BASE_DOMAIN}   IP_PREFIX=${IP_PREFIX}"
echo "============================================================"
echo

# ---------------------------------------------------------------------------
# Required CLI tools
# ---------------------------------------------------------------------------
echo "--- Required tools ---"
for tool in curl wget git kubectl helm ssh openssl envsubst; do
  command -v "${tool}" &>/dev/null \
    && ok "${tool} found ($(command -v ${tool}))" \
    || fail "${tool} not found — install before continuing"
done

if [[ "${ENVIRONMENT}" == "enclave" ]]; then
  command -v hauler &>/dev/null \
    && ok "hauler found" \
    || fail "hauler not found — required for enclave (see modules/enclave/hauler_sync.sh)"
fi

echo
echo "--- SSH key ---"
if [[ -f "${SSH_KEY}" ]]; then
  ok "SSH key found: ${SSH_KEY}"
else
  fail "SSH key not found: ${SSH_KEY}"
  info "Generate with: ssh-keygen -t rsa -b 4096 -f ${SSH_KEY}"
fi

# ---------------------------------------------------------------------------
# Network reachability
# ---------------------------------------------------------------------------
echo
echo "--- Network ---"

ping_check() {
  local host="$1" label="$2"
  if ping -c1 -W2 "${host}" &>/dev/null 2>&1; then
    ok "${label} (${host}) is reachable"
  else
    fail "${label} (${host}) is NOT reachable"
  fi
}

ping_check "${GATEWAY}"    "Gateway"
ping_check "${DNS1_IP}"    "DNS primary (${DNS_HOST})"
ping_check "${DNS2_IP}"    "DNS secondary (${DNS2_HOST})"
ping_check "${ADMIN_IP}"   "Admin host (${ADMIN_HOST})"

echo
echo "--- DNS resolution ---"
dns_check() {
  local fqdn="$1"
  if host "${fqdn}" "${DNS1_IP}" &>/dev/null 2>&1; then
    ok "${fqdn} resolves via ${DNS1_IP}"
  else
    fail "${fqdn} does not resolve — check DNS zone on ${DNS_HOST}"
  fi
}
dns_check "rancher.${BASE_DOMAIN}"
dns_check "apps.${BASE_DOMAIN}"
dns_check "observability.${BASE_DOMAIN}"

echo
echo "--- Internet access ---"
if [[ "${ENVIRONMENT}" == "enclave" ]]; then
  info "Enclave environment — internet access not required after Hauler sync"
else
  if curl -fsSL --connect-timeout 5 https://get.rke2.io/install-rke2.sh -o /dev/null 2>/dev/null; then
    ok "Internet reachable (get.rke2.io)"
  else
    fail "Cannot reach get.rke2.io — check internet connectivity"
  fi
fi

# ---------------------------------------------------------------------------
# Environment-specific checks
# ---------------------------------------------------------------------------
if [[ "${ENVIRONMENT}" == "carbide" || "${ENVIRONMENT}" == "enclave" ]]; then
  echo
  echo "--- RGS credentials ---"
  if [[ -n "${RGS_TOKEN:-}" ]]; then
    ok "RGS_TOKEN is set"
  else
    fail "RGS_TOKEN is not set — export RGS_TOKEN=<your-token> before deploying"
  fi
fi

if [[ "${ENVIRONMENT}" == "enclave" ]]; then
  echo
  echo "--- Hauler store ---"
  if [[ -d "${HAULER_STORE}" ]]; then
    ok "Hauler store found at ${HAULER_STORE}"
  else
    fail "Hauler store not found at ${HAULER_STORE} — run modules/enclave/hauler_sync.sh first"
  fi

  echo
  echo "--- Harbor registry ---"
  if curl -fsSL --connect-timeout 5 "https://${HARBOR_HOSTNAME}/api/v2.0/ping" -o /dev/null 2>/dev/null; then
    ok "Harbor reachable at ${HARBOR_HOSTNAME}"
  else
    fail "Harbor not reachable at ${HARBOR_HOSTNAME} — run modules/enclave/harbor_setup.sh first"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "============================================================"
echo

if [[ ${FAIL} -gt 0 ]]; then
  echo "  Fix the above failures before proceeding."
  exit 1
else
  echo "  All checks passed. Ready to deploy."
  echo "  Next step: sudo bash Scripts/02_setup_ca.sh"
fi
echo
