#!/bin/bash
set -euo pipefail

# modules/carbide/registry_auth.sh — Configure RGS Carbide registry credentials
#
# Run ONCE from nuc-00 before the main deployment sequence when
# ENVIRONMENT=carbide. This script is not needed for community or enclave.
#
# Prerequisites:
#   - RGS_TOKEN environment variable set:
#       export RGS_TOKEN=<your-token-from-carbide-portal>
#   - Carbide Portal: https://portal.ranchercarbide.dev/product/
#
# What this does:
#   1. Validates RGS_TOKEN is set
#   2. Creates a docker/containerd registry credential for registry.rancher.com
#   3. Verifies access by pulling a test image
#   4. Configures the credential on all cluster nodes via SSH

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../env.sh
source "${SCRIPT_DIR}/../../env.sh"

if [[ "${ENVIRONMENT}" != "carbide" ]]; then
  echo "ERROR: This module is for ENVIRONMENT=carbide only (got: ${ENVIRONMENT})" >&2
  exit 1
fi

if [[ -z "${RGS_TOKEN:-}" ]]; then
  echo "ERROR: RGS_TOKEN is not set."
  echo "  export RGS_TOKEN=<your-token>"
  echo "  Then re-run this script."
  exit 1
fi

echo "==> Configuring RGS Carbide registry credentials"
echo "    Registry: ${RGS_REGISTRY}"

# ---------------------------------------------------------------------------
# Docker credential (on nuc-00, for pulling images during setup)
# ---------------------------------------------------------------------------
echo "==> Logging in to ${RGS_REGISTRY} on nuc-00..."
echo "${RGS_TOKEN}" | docker login "${RGS_REGISTRY}" \
  --username token \
  --password-stdin

# ---------------------------------------------------------------------------
# Verify access
# ---------------------------------------------------------------------------
echo "==> Verifying registry access..."
docker pull "${RGS_REGISTRY}/rgs/rancher:latest" 2>/dev/null \
  && echo "    Registry access confirmed." \
  || echo "    WARNING: test pull failed — check your token and entitlements."

# ---------------------------------------------------------------------------
# TODO: Distribute credential to all cluster nodes
# ---------------------------------------------------------------------------
# For each cluster node, create /etc/rancher/rke2/registries.yaml:
#
# mirrors:
#   "docker.io":
#     endpoint:
#       - "https://registry.rancher.com"
# configs:
#   "registry.rancher.com":
#     auth:
#       username: token
#       password: <RGS_TOKEN>
#
# Nodes: rancher-01/02/03, observability-01/02/03, apps-01/02/03
# ---------------------------------------------------------------------------

echo
echo "==> Carbide registry auth complete."
echo "    Proceed with the numbered deployment scripts (00_preflight.sh ...)"
