#!/bin/bash

# nuc-00-03 build_haproxy.sh — HAProxy + Keepalived load balancer setup
#
# Run as root on nuc-00-03 after a fresh OpenSUSE Leap 15.6 install.
# Pulls config files from the admin node web root.
#
# Provides VIPs for:
#   ${IP_PREFIX}.193  — HAProxy keepalived VIP (internal)
#   ${IP_PREFIX}.210  — Rancher Manager cluster (80, 443, 6443, 9345)
#   ${IP_PREFIX}.230  — Applications cluster   (80, 443, 6443, 9345)

# Inline environment config
ENVIRONMENT="${ENVIRONMENT:-community}"
DOMAIN="${DOMAIN:-kubernerdes.com}"
BASE_DOMAIN="${BASE_DOMAIN:-${ENVIRONMENT}.${DOMAIN}}"

case "${ENVIRONMENT}" in
  community)  IP_PREFIX="10.0.0"   ;;
  carbide)    IP_PREFIX="10.10.12" ;;
  enclave)    IP_PREFIX="10.10.12" ;;
  *) echo "Unknown ENVIRONMENT '${ENVIRONMENT}'" >&2 ;;
esac

REPO_BASE="http://${IP_PREFIX}.10/${BASE_DOMAIN}"
echo "# NOTE: using ${REPO_BASE}"
curl -fsSL "${REPO_BASE}/README.md" | tail -2

# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------
for PORT in 9000 80 443 6443 9345; do
  firewall-cmd --permanent --add-port=${PORT}/tcp
done
firewall-cmd --reload

# ---------------------------------------------------------------------------
# Install HAProxy + Keepalived
# ---------------------------------------------------------------------------
zypper -n in haproxy keepalived

# Allow keepalived to bind a VIP before the interface is fully up
echo "net.ipv4.ip_nonlocal_bind = 1" | sudo tee /etc/sysctl.d/20_keepalive.conf
sysctl -p /etc/sysctl.d/20_keepalive.conf

# ---------------------------------------------------------------------------
# Keepalived configuration
# ---------------------------------------------------------------------------
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.orig
curl -fsSL -o /etc/keepalived/keepalived.conf \
  "${REPO_BASE}/Files/nuc-00-03/etc/keepalived/keepalived.conf"

sudo systemctl enable keepalived --now
sleep 15; ip a s

# ---------------------------------------------------------------------------
# HAProxy configuration
# ---------------------------------------------------------------------------
cp /etc/haproxy/haproxy.cfg \
  /etc/haproxy/haproxy.cfg.$(date +%Y%m%d-%H%M%S)
curl -fsSL -o /etc/haproxy/haproxy.cfg \
  "${REPO_BASE}/Files/nuc-00-03/etc/haproxy/haproxy.cfg"

sudo systemctl enable haproxy --now
sudo systemctl status haproxy

echo
echo "==> HAProxy stats: http://${IP_PREFIX}.93:9000/stats"
