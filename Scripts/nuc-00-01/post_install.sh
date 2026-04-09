#!/bin/bash

# nuc-00-01 post_install.sh — Infra VM: DNS, DHCP, TFTP/PXE
#
# Run as: mansible - after a fresh OpenSUSE Leap 15.6 install.
#
# Services installed:
#   BIND   — authoritative DNS for ${BASE_DOMAIN}
#   DHCP   — ISC dhcpd with iPXE boot support for Harvester nodes
#   TFTP   — serves ipxe.efi for initial UEFI PXE handoff
#   kubectl — for cluster management from the infra node
#
# Config files are pulled from the admin node web root during install,
# then managed in-place (or via this repo) going forward.
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
curl ${REPO_BASE}/README.md

# ---------------------------------------------------------------------------
# Base packages (sudo *should* already be installed, but...)
# ---------------------------------------------------------------------------
sudo zypper --non-interactive install sudo 

MYUSER=$(whoami)
echo "${MYUSER} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/${MYUSER}-nopasswd-all

# Install other essential packages
sudo zypper --non-interactive install vim wget curl

# ---------------------------------------------------------------------------
# DNS + DHCP pattern (BIND + ISC dhcpd)
# ---------------------------------------------------------------------------
sudo zypper --non-interactive install -t pattern dhcp_dns_server
sudo zypper --non-interactive install bind-utils

# ---------------------------------------------------------------------------
# TFTP + iPXE EFI binary
# ---------------------------------------------------------------------------
case $(uname -n) in
  nuc-00-01)
    sudo zypper --non-interactive install tftp
    sudo mkdir -p /srv/tftpboot
    sudo wget -O /srv/tftpboot/ipxe.efi https://boot.netboot.xyz/ipxe/netboot.xyz.efi
  ;;
esac

# ---------------------------------------------------------------------------
# BIND configuration
# ---------------------------------------------------------------------------
sudo cp /etc/named.conf /etc/named.conf.$(date +%F)
sudo curl -o /etc/named.conf ${REPO_BASE}/Files/$(uname -n)/etc/named.conf

sudo mkdir -p /var/lib/named/master /var/lib/named/slave /var/lib/named/dyn
case $(uname -n) in
  nuc-00-01)
    echo "blah"
    for ZONE_FILE in \
      db.${BASE_DOMAIN} \
      db-0.0.10.in-addr.arpa \
      db-1.0.10.in-addr.arpa \
      db-2.0.10.in-addr.arpa \
      db-3.0.10.in-addr.arpa
      do
        sudo curl -o /var/lib/named/master/${ZONE_FILE} \
          ${REPO_BASE}/Files/nuc-00-01/var/lib/named/master/${ZONE_FILE}
        named-checkzone /var/lib/named/master/${ZONE_FILE}
      done
  ;;
esac

sudo systemctl enable named --now
sudo systemctl status named

# ---------------------------------------------------------------------------
# DHCP
# ---------------------------------------------------------------------------
case $(uname -n) in
  nuc-00-01)
    sudo cp /etc/dhcpd.conf /etc/dhcpd.conf.$(date +%F)
    sudo curl -o /etc/dhcpd.conf ${REPO_BASE}/Files/nuc-00-01/etc/dhcpd.conf
    sudo mkdir -p /etc/dhcpd.d/
    sudo curl -o /etc/dhcpd.d/dhcpd-hosts.conf \
      ${REPO_BASE}/Files/nuc-00-01/etc/dhcpd.d/dhcpd-hosts.conf

    sudo sed -i -e 's/DHCPD_INTERFACE=""/DHCPD_INTERFACE="eth0"/g' /etc/sysconfig/dhcpd

    sudo mkdir -p /etc/systemd/system/dhcpd.service.d
    printf '[Unit]\nRequires=network-online.target\nAfter=network-online.target\n' \
      | sudo tee /etc/systemd/system/dhcpd.service.d/override.conf
    sudo systemctl daemon-reload

    sudo systemctl enable dhcpd --now
    sudo systemctl status dhcpd
  ;;
esac

# ---------------------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------------------
TCP_PORTS="53 80 443"
UDP_PORTS="53 67 68 69 4011"
SERVICES="http https dns dhcp tftp"

for PORT in $TCP_PORTS; do sudo firewall-cmd --permanent --zone=public --add-port=${PORT}/tcp; done
for PORT in $UDP_PORTS; do sudo firewall-cmd --permanent --zone=public --add-port=${PORT}/udp; done
for SVC  in $SERVICES;  do sudo firewall-cmd --permanent --zone=public --add-service=${SVC}; done

sudo firewall-cmd --reload
sudo firewall-cmd --list-all

host -l "${BASE_DOMAIN}"

# ---------------------------------------------------------------------------
# kubectl
# ---------------------------------------------------------------------------
sudo tee /etc/zypp/repos.d/kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.34/rpm/repomd.xml.key
EOF
sudo zypper refresh
sudo zypper --non-interactive install kubectl

# ---------------------------------------------------------------------------
# Ansible (for future use)
# ---------------------------------------------------------------------------
zypper --non-interactive install ansible

exit 0
