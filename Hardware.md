# Hardware Inventory

Physical hardware, bill of materials, and network switch layout.

## Systems

| System | Purpose | Model | CPU | Cores | RAM (GB) | Disk0 (SSD GB) | Disk1 (NVMe GB) |
|:-------|:--------|:------|:----|------:|:--------:|---------------:|----------------:|
| nuc-00 | Admin Host | NUC10i7FNK | i7-10710U | 12 | 64 | — | 932 |
| nuc-01 | Harvester node 1 | NUC10i7FNH | i7-10710U | 12 | 64 | 1843 | 932 |
| nuc-02 | Harvester node 2 | NUC10i7FNH | i7-10710U | 12 | 64 | 1843 | 932 |
| nuc-03 | Harvester node 3 | NUC10i7FNH | i7-10710U | 12 | 64 | 1843 | 932 |

> All nodes are NUC10 (10th gen) units. Harvester nodes have additional storage
> beyond the listed disks (sdb/sdc/sdd ranging 2G–99G).

## IP Assignments

All IPs are derived from `${IP_PREFIX}` set in `Scripts/env.sh`.

| Last Octet | Hostname | Purpose |
|:----------:|:---------|:--------|
| .1 | gateway | Default gateway / router |
| .8 | nuc-00-01 | DNS primary + DHCP + TFTP (infra VM on nuc-00) |
| .9 | nuc-00-02 | DNS secondary (infra VM on nuc-00) |
| .10 | nuc-00 | Admin host (Apache + KVM) |
| .12 | librenms | Network monitoring (VM, optional) |
| .93 | nuc-00-03 | HAProxy load balancer (infra VM on nuc-00) |
| .100 | harvester | Harvester cluster VIP |
| .101 | nuc-01 | Harvester node 1 |
| .102 | nuc-02 | Harvester node 2 |
| .103 | nuc-03 | Harvester node 3 |
| .111-.113 | nuc-0x-kvm | KVM copy IPs (reserved) |
| .193 | nuc-00-03-vip | HAProxy Keepalived VIP |
| .210 | rancher | Rancher Manager cluster VIP |
| .211-.213 | rancher-01/02/03 | Rancher Manager nodes |
| .220 | observability | Observability cluster VIP |
| .221-.223 | observability-01/02/03 | Observability nodes |
| .230 | apps | Applications cluster VIP |
| .231-.233 | apps-01/02/03 | Applications cluster nodes |
| .251 | spark-e | Optional hardware |
| .3.1–.3.254 | (dynamic) | DHCP pool (last /24 of the /22) |

Wildcard DNS: `*.apps.${ENVIRONMENT}.kubernerdes.com` → `${IP_PREFIX}.230`

## Bill of Materials

| Total | Unit Cost | Qty | Item |
|------:|----------:|:---:|:-----|
| $350 | $350 | 1 | Intel NUC NUC13ANHi3 (admin host) |
| $2,700 | $900 | 3 | Intel NUC NUC13ANHi7 (Harvester nodes) |
| $304 | $76 | 4 | Chicony A17-120P2A 20V 6A 120W PSU (5.5mm–2.5mm) |
| $36 | $12 | 3 | 1GB USB-C network adapter |
| $110 | $110 | 1 | Portable monitor (ViewSonic VA1655) |
| $20 | $10 | 2 | Power strip |
| $7 | $7 | 1 | Mouse |
| $20 | $10 | 20 | 28 AWG Cat6 cables (10-pack) |
| **$4,547** | | | **Estimated total** |

## Network Switch Layout

16-port unmanaged switch port assignments.

| Port | Host | Notes | Port | Host | Notes |
|:----:|:-----|:------|:----:|:-----|:------|
| 1 | nuc-00 | Admin host | 9 | nuc-02-kvm | KVM secondary NIC |
| 2 | nuc-01 | Harvester node 1 | 10 | nuc-03-kvm | KVM secondary NIC |
| 3 | nuc-02 | Harvester node 2 | 11 | | |
| 4 | nuc-03 | Harvester node 3 | 12 | | |
| 5 | nuc-01-vms | VM traffic NIC | 13 | | |
| 6 | nuc-02-vms | VM traffic NIC | 14 | | |
| 7 | nuc-03-vms | VM traffic NIC | 15 | spark-e | Optional |
| 8 | nuc-01-kvm | KVM secondary NIC | 16 | uplink | Internet |

## MAC Addresses

MAC addresses are set per environment in `Scripts/env.d/${ENVIRONMENT}.sh`.

| Host | MAC | Environment |
|:-----|:----|:------------|
| nuc-01 | 88:ae:dd:0b:90:70 | community |
| nuc-02 | 1c:69:7a:ab:23:50 | community |
| nuc-03 | 88:ae:dd:0b:af:9c | community |
| nuc-01 | *(TBD)* | carbide/enclave |
| nuc-02 | *(TBD)* | carbide/enclave |
| nuc-03 | *(TBD)* | carbide/enclave |
