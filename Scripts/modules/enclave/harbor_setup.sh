#!/bin/bash
set -euo pipefail

# modules/enclave/harbor_setup.sh — Deploy local Harbor registry
#
# Run from nuc-00 after hauler_sync.sh completes, when ENVIRONMENT=enclave.
#
# What this does:
#   1. Deploys Harbor on a dedicated VM (${HARBOR_HOSTNAME}) or on nuc-00
#   2. Pushes Hauler store contents into Harbor
#   3. Configures all cluster nodes to mirror from Harbor
#
# After this script completes, the environment is fully air-gapped:
#   - All images are served from ${HARBOR_HOSTNAME}
#   - All Helm charts are served from ${HARBOR_HOSTNAME}
#   - Internet connectivity is no longer required
#
# Reference:
#   https://goharbor.io/docs/
#   https://docs.hauler.dev/docs/guides/push-to-registry

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../env.sh
source "${SCRIPT_DIR}/../../env.sh"

if [[ "${ENVIRONMENT}" != "enclave" ]]; then
  echo "ERROR: This module is for ENVIRONMENT=enclave only (got: ${ENVIRONMENT})" >&2
  exit 1
fi

if [[ ! -d "${HAULER_STORE}" ]]; then
  echo "ERROR: Hauler store not found at ${HAULER_STORE}"
  echo "  Run modules/enclave/hauler_sync.sh first."
  exit 1
fi

# ---------------------------------------------------------------------------
# TODO: Harbor deployment
#
# Options:
#   A. Deploy Harbor via docker-compose on nuc-00 (simplest for homelab)
#   B. Deploy Harbor on a dedicated VM (${HARBOR_HOSTNAME} at ${HARBOR_IP})
#   C. Deploy Harbor via Helm on an existing K8s cluster
#
# For now, this is a stub. Implement the preferred approach here.
# ---------------------------------------------------------------------------

echo "==> Harbor setup — ENVIRONMENT=${ENVIRONMENT}"
echo "    Harbor host:  ${HARBOR_HOSTNAME} (${HARBOR_IP})"
echo "    Harbor admin: ${HARBOR_ADMIN_PASSWORD}"
echo
echo "TODO: Implement Harbor deployment for enclave environment."
echo "      See comments in this file for options."
echo

# ---------------------------------------------------------------------------
# Push Hauler store into Harbor (once Harbor is running)
# ---------------------------------------------------------------------------
# hauler store copy \
#   --store "${HAULER_STORE}" \
#   --destination "registry://${HARBOR_HOSTNAME}" \
#   --username admin \
#   --password "${HARBOR_ADMIN_PASSWORD}"

# ---------------------------------------------------------------------------
# Configure cluster nodes to use Harbor as registry mirror
# ---------------------------------------------------------------------------
# For each cluster node, create /etc/rancher/rke2/registries.yaml:
#
# mirrors:
#   "*":
#     endpoint:
#       - "https://${HARBOR_HOSTNAME}"
# configs:
#   "${HARBOR_HOSTNAME}":
#     tls:
#       ca_file: /etc/ssl/${ENVIRONMENT}-ca/ca.crt

echo "==> Harbor setup stub complete."
echo "    Next: once Harbor is running, proceed with Scripts/00_preflight.sh"
