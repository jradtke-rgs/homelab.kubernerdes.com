#!/bin/bash

# nuc-00 post_install.sh — Admin node bootstrap
#
# Run as the initial user after a fresh OpenSUSE Leap 15.6 install on nuc-00.
# Intended for cut-and-paste execution — review each section before running.
#
# What this does:
#   1. SSH key + passwordless sudo
#   2. Disable power-saving (server role)
#   3. Apache web server + PHP (serves ISOs and this repo to all homelab nodes)
#   4. libvirt / KVM (hosts infra VMs: nuc-00-01, nuc-00-02, nuc-00-03)
#   5. Network bridge for VMs
#   6. Download OpenSUSE Leap 15.6 ISO for infra VM installs
#   7. Deploy infra VMs
#   8. Install tools (git, kubectl, helm, k9s)
#   9. Clone this repo to the Apache web root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../env.sh
source "${SCRIPT_DIR}/../env.sh"

# ---------------------------------------------------------------------------
# 1. SSH key + sudo
# ---------------------------------------------------------------------------
echo | ssh-keygen -t rsa -b 4096 -N '' -f "${HOME}/.ssh/id_rsa-${ENVIRONMENT}"

MYUSER=$(whoami)
echo "${MYUSER} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/${MYUSER}-sudo

# bashrc.d sourcing pattern
cat << 'EOF' >> ~/.bashrc

if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    [ -f "$rc" ] && . "$rc"
  done
fi
unset rc
EOF
mkdir -p ~/.bashrc.d

# ---------------------------------------------------------------------------
# 2. Disable power-saving
# ---------------------------------------------------------------------------
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# ---------------------------------------------------------------------------
# 3. Apache + PHP (serves ISOs, images, and this repo to homelab nodes)
# ---------------------------------------------------------------------------
sudo zypper --non-interactive install apache2 \
  apache2-mod_php8 \
  php8-cli php8-ctype php8-dom php8-iconv php8-openssl \
  php8-pdo php8-sqlite php8-tokenizer php8-xmlreader php8-xmlwriter

sudo a2enmod php8
sudo sed -i -e 's/Options None/Options +Indexes/g' /etc/apache2/default-server.conf
sudo systemctl enable apache2 --now
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

sudo usermod -a -G wwwrun "${MYUSER}"
sudo mkdir -p /srv/www/.kube
sudo chown "${MYUSER}":wwwrun /srv/www/.kube

# ---------------------------------------------------------------------------
# 4. Virtualization (libvirt / KVM)
# ---------------------------------------------------------------------------
sudo systemctl stop packagekit.service
sudo zypper install -t pattern kvm_server kvm_tools
sudo zypper --non-interactive install virt-manager virt-viewer virt-install \
  libguestfs bridge-utils

sudo systemctl enable libvirt-guests.service --now
sudo systemctl enable virtqemud.socket --now
sudo systemctl enable virtnetworkd.socket --now
sudo systemctl enable virtstoraged.socket --now

# ---------------------------------------------------------------------------
# 5. Network bridge for VMs
# ---------------------------------------------------------------------------
BRIDGE=$(ip link show type bridge up 2>/dev/null \
  | grep -v docker | awk -F': ' '/^[0-9]+:/ {print $2; exit}')

if [ -z "${BRIDGE}" ]; then
  PRIMARY_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
  CONN_NAME=$(nmcli -t -f NAME,DEVICE connection show --active \
    | grep ":${PRIMARY_IFACE}$" | cut -d: -f1)
  IP_CONFIG=$(nmcli -t -f IP4.ADDRESS connection show "${CONN_NAME}" | cut -d: -f2)
  GW=$(nmcli -t -f IP4.GATEWAY connection show "${CONN_NAME}" | cut -d: -f2)
  DNS=$(nmcli -t -f IP4.DNS connection show "${CONN_NAME}" | cut -d: -f2 | tr '\n' ' ')

  sudo nmcli connection add type bridge \
    con-name virbr0 ifname virbr0 \
    ipv4.method manual \
    ipv4.addresses "${IP_CONFIG}" \
    ipv4.gateway "${GW}" \
    ipv4.dns "${DNS}" \
    bridge.stp no

  sudo nmcli connection add type ethernet \
    con-name bridge-slave-${PRIMARY_IFACE} \
    ifname ${PRIMARY_IFACE} \
    master virbr0

  sudo nmcli connection up virbr0
  sudo nmcli connection delete "${CONN_NAME}"
fi

cat > /tmp/virbr0-net.xml << 'EOF'
<network>
  <name>virbr0</name>
  <forward mode="bridge"/>
  <bridge name="virbr0"/>
</network>
EOF
sudo virsh net-define /tmp/virbr0-net.xml
sudo virsh net-start virbr0
sudo virsh net-autostart virbr0
virsh net-list --all

# ---------------------------------------------------------------------------
# 6. OpenSUSE Leap 15.6 ISO (for infra VM installs)
# ---------------------------------------------------------------------------
ISO_URL=https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-DVD-x86_64-Media.iso
ISO_NAME=openSUSE-Leap-15.6-DVD-x86_64-Media.iso
ISO_DIR=/srv/www/htdocs/images
ISO_MOUNT=/srv/www/htdocs/OS/openSUSE-Leap-15.6-DVD-x86_64-Media
OS_VARIANT=opensuse15.6

sudo mkdir -p "${ISO_DIR}" "${ISO_MOUNT}"

[ ! -f "${ISO_DIR}/${ISO_NAME}" ] \
  && { echo "Downloading Leap 15.6 ISO..."; sudo curl -L "${ISO_URL}" -o "${ISO_DIR}/${ISO_NAME}"; } \
  || echo "ISO already present."

echo "${ISO_DIR}/${ISO_NAME} ${ISO_MOUNT} iso9660 defaults,ro 0 0" \
  | sudo tee -a /etc/fstab
sudo mount -a

# ---------------------------------------------------------------------------
# 7. Deploy infra VMs
# ---------------------------------------------------------------------------
ADMIN_NODE_IP=$(ip -4 addr show virbr0 | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+')

for VM_HOSTNAME in nuc-00-01 nuc-00-02 nuc-00-03; do
  sudo mkdir -p /var/lib/libvirt/images/${VM_HOSTNAME}
  sudo virt-install \
    --name ${VM_HOSTNAME} \
    --memory 4096 \
    --vcpus 4 \
    --disk path=/var/lib/libvirt/images/${VM_HOSTNAME}/${VM_HOSTNAME}.qcow2,size=40,format=qcow2 \
    --os-variant ${OS_VARIANT} \
    --network network=virbr0 \
    --graphics none \
    --location "http://${ADMIN_NODE_IP}/OS/openSUSE-Leap-15.6-DVD-x86_64-Media" \
    --extra-args "console=ttyS0 textmode=1 hostname=${VM_HOSTNAME}.${BASE_DOMAIN}" \
    --noautoconsole
  sleep 10
done

# ---------------------------------------------------------------------------
# 8. Tools
# ---------------------------------------------------------------------------
sudo zypper --non-interactive install git vim curl wget iotop

# kubectl
sudo tee /etc/zypp/repos.d/kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.33/rpm/repomd.xml.key
EOF
sudo zypper refresh
sudo zypper --non-interactive install kubectl

# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ---------------------------------------------------------------------------
# 9. Clone this repo to the web root (serves config files to all nodes)
# ---------------------------------------------------------------------------
sudo mkdir -p /srv/www/htdocs/${BASE_DOMAIN}
sudo git clone "https://github.com/jradtke-rgs/homelab.kubernerdes.com.git" \
  /srv/www/htdocs/${BASE_DOMAIN}

echo
echo "==> nuc-00 setup complete."
echo "    Next: log into nuc-00-01 and run Scripts/nuc-00-01/post_install.sh"
echo

exit 0
