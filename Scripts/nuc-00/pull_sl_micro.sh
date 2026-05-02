#!/usr/bin/env bash
# pull_sl_micro.sh — Login to Carbide registry and verify SL-Micro VM image
#
# Run as mansible on nuc-00 (10.10.12.10).
# Images must be downloaded manually from the Carbide portal and placed in
# IMAGE_DIR before running subsequent steps.
#
# Carbide portal: https://portal.ranchercarbide.dev/product/suse%20linux%20micro
#   - Select the Base QCOW2 for your SL_MICRO_VERSION and click to download.
#   - scp the file to nuc-00:${IMAGE_DIR}/
#
# This script:
#   1. Logs in to the Carbide OCI registry (persists creds for RKE2/Rancher pulls)
#   2. Verifies the required SL-Micro qcow2 is present in IMAGE_DIR

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../env.sh
source "${SCRIPT_DIR}/../env.sh"

IMAGE_DIR="/srv/www/htdocs/images"
RGS_CREDS="${HOME}/.config/RGS.creds"

# ---------------------------------------------------------------------------
# Validate prerequisites
# ---------------------------------------------------------------------------
[[ -f "${RGS_CREDS}" ]] || { echo "ERROR: ${RGS_CREDS} not found"; exit 1; }
source "${RGS_CREDS}"

sudo mkdir -p "${IMAGE_DIR}"

# ---------------------------------------------------------------------------
# 1. Login to Carbide OCI registry
#    Credentials are persisted to ~/.docker/config.json and used automatically
#    by docker/hauler when pulling RKE2 and Rancher container images.
# ---------------------------------------------------------------------------
REGISTRY="${CARBIDE_REGISTRY:-registry.ranchercarbide.dev}"
echo "==> Logging in to Carbide registry: ${REGISTRY}"
printf "%s" "${CARBIDE_PASSWORD}" | hauler login "${REGISTRY}" \
  --username "${CARBIDE_USERNAME}" --password-stdin

# ---------------------------------------------------------------------------
# 2. Verify SL-Micro qcow2 image
#
#    The Base qcow2 is the root disk for Harvester VMs (Rancher Manager nodes).
#    Download URL is session-based — must be obtained by clicking in the portal:
#      https://portal.ranchercarbide.dev/product/suse%20linux%20micro
#    Then copy to this host:
#      scp SL-Micro.x86_64-${SL_MICRO_VERSION}-Base-qcow-GM.qcow2 \
#          mansible@10.10.12.10:${IMAGE_DIR}/
# ---------------------------------------------------------------------------
SL_MICRO_QCOW2="SL-Micro.x86_64-${SL_MICRO_VERSION}-Base-qcow-GM.qcow2"
IMAGE_PATH="${IMAGE_DIR}/${SL_MICRO_QCOW2}"

echo "==> Checking for SL-Micro ${SL_MICRO_VERSION} image..."
if [[ -f "${IMAGE_PATH}" ]]; then
  echo "  Found: ${IMAGE_PATH} ($(du -sh "${IMAGE_PATH}" | cut -f1))"
  echo "  HTTP:  http://10.10.12.10/images/${SL_MICRO_QCOW2}"
else
  echo
  echo "  MISSING: ${IMAGE_PATH}"
  echo
  echo "  To download:"
  echo "    1. Browse to https://portal.ranchercarbide.dev/product/suse%20linux%20micro"
  echo "    2. Click the Base QCOW2 link for version ${SL_MICRO_VERSION}"
  echo "    3. Copy the downloaded file to this host:"
  echo "       scp SL-Micro.x86_64-${SL_MICRO_VERSION}-Base-qcow-GM.qcow2 \\"
  echo "           mansible@10.10.12.10:${IMAGE_DIR}/"
  echo "    4. Re-run this script to confirm."
  echo
  exit 1
fi

echo
echo "==> All images in ${IMAGE_DIR}:"
ls -lh "${IMAGE_DIR}"/SL-Micro* 2>/dev/null || echo "  (none)"
echo
echo "==> Carbide registry login stored in ~/.docker/config.json"
echo "    Next: build Rancher Manager VMs using the image above, then install RKE2"

exit 0
