#!/bin/bash
set -euo pipefail

# 03_distribute_ca.sh — Push the Vault root CA cert to all cluster nodes
#
# Run from nuc-00 after 02_setup_vault.sh has completed.
# Idempotent — safe to re-run; unreachable nodes are skipped with a warning.
#
# By default targets all three environments. Override to target one:
#   ENVIRONMENT=carbide bash 03_distribute_ca.sh
#
# What this pushes:
#   - Harvester physical nodes (NUC01-03): root@<ip>
#   - RKE2 VM nodes (rancher/obs/apps -01/-02/-03): sles@<ip>
#
# The Vault root CA is homelab-level infrastructure shared by all environments.
# New nodes trust the CA automatically via install_RKE2.sh; this script
# is for retroactive updates and existing nodes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CA_CERT="${CA_CERT:-/etc/ssl/homelab-root-ca.crt}"
CA_DEST="/etc/pki/trust/anchors/homelab-root-ca.crt"

if [[ ! -f "${CA_CERT}" ]]; then
  echo "ERROR: ${CA_CERT} not found. Run 02_setup_vault.sh first." >&2
  exit 1
fi

# push_ca <user> <ip> <ssh_key>
# Copies the CA cert to the node and updates its trust store.
# Returns 0 (skips with a warning) if the node is unreachable.
push_ca() {
  local user="$1" ip="$2" ssh_key="$3"
  local ssh_opts="-i ${ssh_key} -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"

  if ! ssh ${ssh_opts} "${user}@${ip}" true 2>/dev/null; then
    echo "    SKIP  ${user}@${ip} — not reachable"
    return 0
  fi

  scp -q ${ssh_opts} "${CA_CERT}" "${user}@${ip}:/tmp/homelab-root-ca.crt"

  if [[ "${user}" == "root" ]]; then
    ssh ${ssh_opts} "${user}@${ip}" \
      "cp /tmp/homelab-root-ca.crt ${CA_DEST} && update-ca-certificates && rm /tmp/homelab-root-ca.crt"
  else
    ssh ${ssh_opts} "${user}@${ip}" \
      "sudo cp /tmp/homelab-root-ca.crt ${CA_DEST} && sudo update-ca-certificates && rm /tmp/homelab-root-ca.crt"
  fi

  echo "    OK    ${user}@${ip}"
}

distribute_to_env() {
  local env="$1"
  echo
  echo "==> Environment: ${env}"

  # Source env.sh for this environment to get node IPs and SSH key path.
  # Each iteration re-sources to overwrite vars from the previous environment.
  ENVIRONMENT="${env}" source "${SCRIPT_DIR}/env.sh"

  if [[ ! -f "${SSH_KEY}" ]]; then
    echo "    WARNING: SSH key ${SSH_KEY} not found — skipping ${env}"
    return 0
  fi

  echo "  -- Harvester nodes (root@) --"
  for ip in "${NUC01_IP}" "${NUC02_IP}" "${NUC03_IP}"; do
    push_ca "root" "${ip}" "${SSH_KEY}"
  done

  echo "  -- Rancher RKE2 nodes (sles@) --"
  for ip in "${RANCHER_NODE_01}" "${RANCHER_NODE_02}" "${RANCHER_NODE_03}"; do
    push_ca "sles" "${ip}" "${SSH_KEY}"
  done

  echo "  -- Observability RKE2 nodes (sles@) --"
  for ip in "${OBS_NODE_01}" "${OBS_NODE_02}" "${OBS_NODE_03}"; do
    push_ca "sles" "${ip}" "${SSH_KEY}"
  done

  echo "  -- Apps RKE2 nodes (sles@) --"
  for ip in "${APPS_NODE_01}" "${APPS_NODE_02}" "${APPS_NODE_03}"; do
    push_ca "sles" "${ip}" "${SSH_KEY}"
  done
}

# Determine target environments
if [[ -n "${ENVIRONMENT:-}" && "${ENVIRONMENT}" != "all" ]]; then
  TARGETS=("${ENVIRONMENT}")
else
  TARGETS=(carbide enclave community)
fi

echo "==> Distributing homelab root CA"
echo "    Source:  ${CA_CERT}"
echo "    Targets: ${TARGETS[*]}"

for env in "${TARGETS[@]}"; do
  distribute_to_env "${env}"
done

echo
echo "==> Done. Nodes marked SKIP were unreachable — re-run when they are up."
