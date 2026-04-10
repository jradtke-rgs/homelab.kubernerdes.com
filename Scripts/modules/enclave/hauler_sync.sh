#!/bin/bash
set -euo pipefail

# modules/enclave/hauler_sync.sh — Sync all artifacts via Hauler
#
# Run from nuc-00 BEFORE deployment when ENVIRONMENT=enclave.
# Requires internet access. After sync, the environment is fully air-gapped.
#
# This script:
#   1. Installs Hauler on nuc-00 if not present
#   2. Syncs all required artifacts (Harvester ISO, RKE2, Rancher, NeuVector,
#      Observability, cert-manager, cloud images) into the local Hauler store
#   3. Starts the Hauler file server so nodes can pull artifacts locally
#
# After this script completes:
#   - Run modules/enclave/harbor_setup.sh to stand up the image registry
#   - Then proceed with the numbered deployment scripts
#
# Reference:
#   https://docs.hauler.dev/docs/intro

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../env.sh
source "${SCRIPT_DIR}/../../env.sh"

if [[ "${ENVIRONMENT}" != "enclave" ]]; then
  echo "ERROR: This module is for ENVIRONMENT=enclave only (got: ${ENVIRONMENT})" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Install Hauler
# ---------------------------------------------------------------------------
if ! command -v hauler &>/dev/null; then
  echo "==> Installing Hauler..."
  curl -sfL https://get.hauler.dev | bash
fi
echo "==> Hauler $(hauler version 2>/dev/null || echo '(version unknown)')"

mkdir -p "${HAULER_STORE}"

# ---------------------------------------------------------------------------
# Hauler manifest — describes everything to sync
# ---------------------------------------------------------------------------
MANIFEST="${HAULER_STORE}/hauler-manifest.yaml"

cat > "${MANIFEST}" <<EOF
apiVersion: content.hauler.cattle.io/v1alpha1
kind: ThingCollection
metadata:
  name: ${ENVIRONMENT}-collection
spec:
  charts:
    - name: cert-manager
      repoURL: https://charts.jetstack.io
      version: "${CERTMGR_VERSION}"
    - name: rancher
      repoURL: https://charts.rancher.com/server-charts/prime
      version: "${RANCHER_VERSION}"

  images:
    - name: registry.rancher.com/rgs/rancher:${RANCHER_VERSION}
    - name: registry.rancher.com/rgs/neuvector-controller:${NEUVECTOR_VERSION}
    - name: registry.rancher.com/rgs/neuvector-manager:${NEUVECTOR_VERSION}
    - name: registry.rancher.com/rgs/neuvector-scanner:${NEUVECTOR_VERSION}
    - name: registry.rancher.com/rgs/neuvector-enforcer:${NEUVECTOR_VERSION}

  files:
    - path: https://releases.rancher.com/harvester/${HARVESTER_VERSION}/harvester-${HARVESTER_VERSION}-amd64.iso
    - path: https://releases.rancher.com/harvester/${HARVESTER_VERSION}/harvester-${HARVESTER_VERSION}-vmlinuz-amd64
    - path: https://releases.rancher.com/harvester/${HARVESTER_VERSION}/harvester-${HARVESTER_VERSION}-initrd-amd64
    - path: https://releases.rancher.com/harvester/${HARVESTER_VERSION}/harvester-${HARVESTER_VERSION}-rootfs-amd64.squashfs
    - path: https://get.rke2.io/install-rke2.sh
      name: rke2/install.sh
EOF

# ---------------------------------------------------------------------------
# Sync (requires internet access + RGS credentials for registry.rancher.com)
# ---------------------------------------------------------------------------
if [[ -z "${RGS_TOKEN:-}" ]]; then
  echo "ERROR: RGS_TOKEN is not set — required for RGS image sync."
  exit 1
fi

echo "==> Starting Hauler sync (this will take a while)..."
hauler store sync \
  --store "${HAULER_STORE}" \
  --files "${MANIFEST}"

echo "==> Sync complete. Store size: $(du -sh "${HAULER_STORE}" | cut -f1)"

# ---------------------------------------------------------------------------
# Start Hauler file server (serves RKE2 install script and Harvester artifacts)
# ---------------------------------------------------------------------------
echo "==> Starting Hauler file server on port ${HAULER_SERVE_PORT}..."
hauler store serve fileserver \
  --store "${HAULER_STORE}" \
  --port "${HAULER_SERVE_PORT}" &

echo "    File server running at http://${ADMIN_IP}:${HAULER_SERVE_PORT}"
echo
echo "==> Hauler sync complete."
echo "    Next: run modules/enclave/harbor_setup.sh to stand up the image registry."
