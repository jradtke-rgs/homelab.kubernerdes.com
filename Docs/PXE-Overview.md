# PXE Boot Overview

How network boot works in this environment, from power-on to Harvester install.

## Boot Flow

```
Power on (nuc-01/02/03)
  └─► UEFI firmware → PXE boot via NIC
        └─► DHCP request to nuc-00-01 (${IP_PREFIX}.8)
              └─► DHCP returns:
                    next-server = ${IP_PREFIX}.8 (TFTP)
                    filename    = "ipxe.efi"
                        └─► TFTP downloads ipxe.efi from nuc-00-01
                              └─► iPXE client starts, re-runs DHCP
                                    └─► DHCP detects iPXE user-class
                                          └─► filename = "http://${ADMIN_IP}/harvester/harvester/ipxe-menu"
                                                └─► HTTP fetches iPXE menu script
                                                      └─► Menu displayed (5s timeout → local boot)
                                                            └─► User selects node role
                                                                  └─► Kernel + initrd + squashfs fetched via HTTP
                                                                        └─► Harvester installer boots
                                                                              └─► Reads config-{create,join}-nuc-0x.yaml
                                                                                    └─► Automated install runs
```

## Key Services on nuc-00-01

| Service | Port | Purpose |
|:--------|:-----|:--------|
| BIND (named) | 53/UDP, 53/TCP | Authoritative DNS for `${BASE_DOMAIN}` |
| ISC dhcpd | 67/UDP | DHCP + PXE boot coordination |
| TFTP (tftpd) | 69/UDP | Serves `ipxe.efi` to UEFI clients |
| HTTP (Apache on nuc-00) | 80/TCP | Serves iPXE menu, Harvester artifacts, configs |

## Key Files

| File | Location | Purpose |
|:-----|:---------|:--------|
| `ipxe.efi` | `/srv/tftpboot/ipxe.efi` on nuc-00-01 | Initial UEFI iPXE binary |
| `ipxe-menu.tmpl` | `Files/nuc-00/srv/www/htdocs/harvester/harvester/` | iPXE boot menu script |
| `config-create-nuc-01.yaml.tmpl` | same directory | Harvester create-cluster config |
| `config-join-nuc-02.yaml.tmpl` | same directory | Harvester join-cluster config (nuc-02) |
| `config-join-nuc-03.yaml.tmpl` | same directory | Harvester join-cluster config (nuc-03) |
| `dhcpd.conf` | `Files/nuc-00-01/etc/` | DHCP + PXE coordination |

## Template Rendering

The `.tmpl` files contain `${VAR}` placeholders that are resolved by `envsubst`
at install time. The `nuc-00-01/post_install.sh` pulls these from the admin
node and processes them via `envsubst < file.tmpl > file` before use.

Variables come from `Scripts/env.sh` + `Scripts/env.d/${ENVIRONMENT}.sh`.

## Harvester ISO Hosting

Harvester artifacts must be downloaded and placed on nuc-00 before PXE booting:

```bash
ISO_VERSION="${HARVESTER_VERSION}"
ISO_DIR=/srv/www/htdocs/harvester/${ISO_VERSION}
mkdir -p "${ISO_DIR}"

# Download from GitHub releases
BASE=https://releases.rancher.com/harvester/${ISO_VERSION}
for f in \
  harvester-${ISO_VERSION}-amd64.iso \
  harvester-${ISO_VERSION}-vmlinuz-amd64 \
  harvester-${ISO_VERSION}-initrd-amd64 \
  harvester-${ISO_VERSION}-rootfs-amd64.squashfs
do
  wget -P "${ISO_DIR}" "${BASE}/${f}"
done
```

For Enclave, these files are pre-synced by `modules/enclave/hauler_sync.sh`
and served from the local Hauler file server.
