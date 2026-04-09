#!/bin/bash

sudo su -

ENVIRONMENT="${ENVIRONMENT:-homelab}"
DOMAIN="${DOMAIN:-kubernerdes.com}"
BASE_DOMAIN="${BASE_DOMAIN:-${ENVIRONMENT}.${DOMAIN}}"

case "${ENVIRONMENT}" in
  homelab) IP_PREFIX="10.0.0" ;;
  enclave) IP_PREFIX="10.10.12" ;;
  *) echo "Unknown ENVIRONMENT '${ENVIRONMENT}'" >&2 ;;
esac

REPO_SERVER=http://${IP_PREFIX}.10/
REPO_NAME="${BASE_DOMAIN}"
REPO_BASE="${REPO_SERVER}${REPO_NAME}"
echo "# NOTE: using $REPO_BASE to pull bits"
curl ${REPO_BASE}/README.md | tail -2

# Open Ports
TCP_PORTS="9000 80 443 6443 11434 12000 9345"
for PORT in $TCP_PORTS
do 
  firewall-cmd --permanent --add-port=${PORT}/tcp
done
UDP_PORTS="9345"
for PORT in $UDP_PORTS
do
  firewall-cmd --permanent --add-port=${PORT}/udp
done
firewall-cmd --reload

# using Keepalived for floating/VIP (and to future proof)
zypper -n in haproxy keepalived

# Allow keepalive to attach before interface is up/available
echo "net.ipv4.ip_nonlocal_bind = 1" | sudo tee -a /etc/sysctl.d/20_keepalive.conf
mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.orig
curl -o /etc/keepalived/keepalived.conf ${REPO_BASE}/Files/nuc-00-03/etc/keepalived/keepalived.conf

sdiff /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.orig
sudo systemctl enable keepalived --now
sleep 15; ip a s

cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.$(uuidgen | tr -d '-' | head -c 6)
curl -o /etc/haproxy/haproxy.cfg ${REPO_BASE}/Files/nuc-00-03/etc/haproxy/haproxy.cfg

sudo systemctl enable haproxy --now

