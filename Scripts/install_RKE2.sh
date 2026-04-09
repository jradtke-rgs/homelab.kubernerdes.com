#!/bin/bash
set -euo pipefail

# install_RKE2.sh — Install RKE2 on a cluster node (community install via get.rke2.io)
#
# Run as root (sudo su -) on each node.
#   sudo -i bash ~sles/install_RKE2.sh
#
# Used for: rancher cluster, observability cluster, apps cluster
# Node-aware: *-01 is genesis; subsequent nodes wait and join.
#
# SL-Micro nodes:
#   After rke2-server starts, this script installs a systemd one-shot
#   (rke2-postboot.service) to set up kubeconfig after the mandatory reboot.
#   On non-SL-Micro nodes the kubeconfig setup runs inline.
#
# Manual fallback if the one-shot fails:
#   Run Scripts/install_RKE2_post_install.sh after the node comes back up.

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: This script must be run as root."
  exit 1
fi

ENVIRONMENT="${ENVIRONMENT:-homelab}"
DOMAIN="${DOMAIN:-kubernerdes.com}"
BASE_DOMAIN="${BASE_DOMAIN:-${ENVIRONMENT}.${DOMAIN}}"

case "${ENVIRONMENT}" in
  homelab) IP_PREFIX="10.0.0" ;;
  enclave) IP_PREFIX="10.10.12" ;;
  *) echo "ERROR: Unknown ENVIRONMENT '${ENVIRONMENT}'"; exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Set cluster-specific variables
# ---------------------------------------------------------------------------
case $(uname -n) in
  rancher-0*)
    cat << EOF | tee /root/.rke2.vars
export MY_CLUSTER=rancher
export MY_RKE2_VERSION=v1.34.4+rke2r1
export MY_RKE2_TOKEN=ChangeMe-RancherRKE2
export MY_RKE2_VIP=${IP_PREFIX}.210
export MY_RKE2_HOSTNAME=rancher.${BASE_DOMAIN}
EOF
  ;;
  observability-0*)
    cat << EOF | tee /root/.rke2.vars
export MY_CLUSTER=observability
export MY_RKE2_VERSION=v1.34.4+rke2r1
export MY_RKE2_TOKEN=ChangeMe-ObsRKE2
export MY_RKE2_VIP=${IP_PREFIX}.220
export MY_RKE2_HOSTNAME=observability.${BASE_DOMAIN}
EOF
  ;;
  apps-0*)
    cat << EOF | tee /root/.rke2.vars
export MY_CLUSTER=apps
export MY_RKE2_VERSION=v1.34.4+rke2r1
export MY_RKE2_TOKEN=ChangeMe-AppsRKE2
export MY_RKE2_VIP=${IP_PREFIX}.230
export MY_RKE2_HOSTNAME=apps.${BASE_DOMAIN}
EOF
  ;;
  *)
    echo "ERROR: Unrecognised hostname '$(uname -n)'. Add a case block for this cluster."
    exit 1
  ;;
esac

source /root/.rke2.vars

# ---------------------------------------------------------------------------
# /etc/hosts — static cluster node entries (no DNS dependency at install time)
# ---------------------------------------------------------------------------
sed -i -e "/${MY_CLUSTER}/d" /etc/hosts
case ${MY_CLUSTER} in
  rancher)
    cat << EOF >> /etc/hosts
${IP_PREFIX}.211    rancher-01.${BASE_DOMAIN} rancher-01
${IP_PREFIX}.212    rancher-02.${BASE_DOMAIN} rancher-02
${IP_PREFIX}.213    rancher-03.${BASE_DOMAIN} rancher-03
EOF
  ;;
  observability)
    cat << EOF >> /etc/hosts
${IP_PREFIX}.221    observability-01.${BASE_DOMAIN} observability-01
${IP_PREFIX}.222    observability-02.${BASE_DOMAIN} observability-02
${IP_PREFIX}.223    observability-03.${BASE_DOMAIN} observability-03
EOF
  ;;
  apps)
    cat << EOF >> /etc/hosts
${IP_PREFIX}.231    apps-01.${BASE_DOMAIN} apps-01
${IP_PREFIX}.232    apps-02.${BASE_DOMAIN} apps-02
${IP_PREFIX}.233    apps-03.${BASE_DOMAIN} apps-03
EOF
  ;;
esac

# ---------------------------------------------------------------------------
# RKE2 config
# ---------------------------------------------------------------------------
mkdir -p /etc/rancher/rke2

case $(uname -n) in
  *-01)
    cat << EOF > /etc/rancher/rke2/config.yaml
token: ${MY_RKE2_TOKEN}
tls-san:
  - ${MY_RKE2_VIP}
  - ${MY_RKE2_HOSTNAME}
EOF
  ;;
  *)
    cat << EOF > /etc/rancher/rke2/config.yaml
server: https://${MY_RKE2_VIP}:9345
token: ${MY_RKE2_TOKEN}
tls-san:
  - ${MY_RKE2_VIP}
  - ${MY_RKE2_HOSTNAME}
EOF
  ;;
esac

# ---------------------------------------------------------------------------
# Install RKE2 — from get.rke2.io (community), pinned version
# ---------------------------------------------------------------------------
case $(uname -n) in
  *-01) echo "==> Genesis node — installing immediately" ;;
  *)
    SLEEPY_TIME=$(shuf -i 45-90 -n 1)
    echo "==> Worker node — waiting ${SLEEPY_TIME}s before install..."
    sleep "${SLEEPY_TIME}"
  ;;
esac

curl -sfL "https://get.rke2.io/install-rke2.sh" \
  | INSTALL_RKE2_VERSION="${MY_RKE2_VERSION}" sh -

# PATH additions for RKE2 binaries
RKE2_PATH='export PATH=$PATH:/opt/rke2/bin:/var/lib/rancher/rke2/bin'
grep -qxF "${RKE2_PATH}" /root/.bashrc || echo "${RKE2_PATH}" >> /root/.bashrc
grep -qxF "${RKE2_PATH}" ~sles/.bashrc 2>/dev/null \
  || echo "${RKE2_PATH}" >> ~sles/.bashrc 2>/dev/null || true
export PATH=$PATH:/opt/rke2/bin:/var/lib/rancher/rke2/bin

# ---------------------------------------------------------------------------
# Enable and start RKE2
# ---------------------------------------------------------------------------
case $(uname -n) in
  *-01) echo "==> Starting rke2-server (genesis)" ;;
  *)
    SLEEPY_TIME=$(shuf -i 45-90 -n 1)
    echo "==> Waiting ${SLEEPY_TIME}s for genesis node to be ready..."
    sleep "${SLEEPY_TIME}"
  ;;
esac

systemctl enable rke2-server.service --now

# ---------------------------------------------------------------------------
# Post-install kubeconfig setup
#
# SL-Micro: copy the postboot script to /var (survives snapshot reboot) and
#           reboot. After reboot run install_RKE2_postboot.sh manually if it
#           did not run automatically.
# Other:    run the postboot script inline — no reboot needed.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POSTBOOT_SCRIPT="${SCRIPT_DIR}/install_RKE2_postboot.sh"

. /etc/*release* 2>/dev/null || true
case ${NAME:-} in
  SL-Micro)
    echo "==> SL-Micro detected — copying postboot script and rebooting"
    cp "${POSTBOOT_SCRIPT}" /var/lib/install_RKE2_postboot.sh
    chmod 0700 /var/lib/install_RKE2_postboot.sh

    echo "==> After reboot, run: sudo bash /var/lib/install_RKE2_postboot.sh"
    echo "==> Rebooting to commit transactional update..."
    case $(uname -n) in
      *-01) sleep 5 ;;
      *)    sleep $(shuf -i 30-45 -n 1) ;;
    esac
    shutdown -r now
  ;;
  *)
    bash "${POSTBOOT_SCRIPT}"
  ;;
esac
