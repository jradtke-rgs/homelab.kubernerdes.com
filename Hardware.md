# Hardware Inventory

Physical hardware, bill of materials, and network switch layout.

## Systems

| System | Purpose | Environment | Model | CPU | Cores | RAM (GB) | Disk0 (SSD GB) | Disk1 (NVMe GB) |
|:-------|:--------|:------------|:------|:----|------:|:--------:|---------------:|----------------:|
| nuc-00 | Admin Host | (all) | NUC13ANHi3 | i3-1315U | 6 | 32 | — | 512 |
| nuc-01 | Harvester node 1 | enclave / carbide | NUC10i7FNH | i7-10710U | 12 | 64 | 1843 | 932 |
| nuc-02 | Harvester node 2 | enclave / carbide | NUC10i7FNH | i7-10710U | 12 | 64 | 1843 | 932 |
| nuc-03 | Harvester node 3 | enclave / carbide | NUC10i7FNH | i7-10710U | 12 | 64 | 1843 | 932 |
| nuc-11 | Harvester node 1 | community | NUC13ANHi7 | i7-1360P | 16 | 64 | 1843 | 932 |
| nuc-12 | Harvester node 2 | community | NUC13ANHi7 | i7-1360P | 16 | 64 | 1843 | 932 |
| nuc-13 | Harvester node 3 | community | NUC13ANHi7 | i7-1360P | 16 | 64 | 1843 | 932 |

> Gen10 NUCs (nuc-01/02/03) serve enclave and carbide — mutually exclusive, never simultaneously deployed.
> Gen13 NUCs (nuc-11/12/13) are dedicated to community and can run in parallel with enclave or carbide.

## IP Assignments

The supernet is `10.10.12.0/22`. Each environment occupies one `/24`; the last `/24` is the DHCP pool.

| Subnet | Environment | Nodes |
|:-------|:------------|:------|
| 10.10.12.0/24 | enclave | Gen10 NUCs (nuc-01/02/03) |
| 10.10.13.0/24 | carbide | Gen10 NUCs (nuc-01/02/03) |
| 10.10.14.0/24 | community | Gen13 NUCs (nuc-11/12/13) |
| 10.10.15.0/24 | (reserved) | DHCP dynamic pool |

Infrastructure IPs (shared / always present on 10.10.12.x):

| IP | Hostname | Purpose |
|:---|:---------|:--------|
| 10.10.12.1 | gateway | Default gateway / router |
| 10.10.12.8 | nuc-00-01 | DNS primary + DHCP + TFTP (infra VM on nuc-00) |
| 10.10.12.9 | nuc-00-02 | DNS secondary (infra VM on nuc-00) |
| 10.10.12.10 | nuc-00 | Admin host (Apache + KVM) |
| 10.10.12.12 | librenms | Network monitoring (VM, optional) |
| 10.10.12.93 | nuc-00-03 | HAProxy load balancer (infra VM on nuc-00) |
| 10.10.12.193 | nuc-00-03-vip | HAProxy Keepalived VIP |

Per-environment IPs (last octet identical across all environments, prefix differs):

| Last Octet | Hostname | Purpose |
|:----------:|:---------|:--------|
| .100 | harvester | Harvester cluster VIP |
| .101 | nuc-01 or nuc-11 | Harvester node 1 |
| .102 | nuc-02 or nuc-12 | Harvester node 2 |
| .103 | nuc-03 or nuc-13 | Harvester node 3 |
| .111-.113 | nuc-0x-kvm | KVM copy IPs (reserved) |
| .210 | rancher | Rancher Manager cluster VIP |
| .211-.213 | rancher-01/02/03 | Rancher Manager nodes |
| .220 | observability | Observability cluster VIP |
| .221-.223 | observability-01/02/03 | Observability nodes |
| .230 | apps | Applications cluster VIP |
| .231-.233 | apps-01/02/03 | Applications cluster nodes |
| .251 | spark-e | Optional hardware |

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
| nuc-01 | 88:ae:dd:0b:90:70 | enclave / carbide (Gen10) |
| nuc-02 | 1c:69:7a:ab:23:50 | enclave / carbide (Gen10) |
| nuc-03 | 88:ae:dd:0b:af:9c | enclave / carbide (Gen10) |
| nuc-11 | 48:21:0b:65:ce:e5 | community (Gen13) |
| nuc-12 | 48:21:0b:65:c2:c7 | community (Gen13) |
| nuc-13 | 48:21:0b:5d:7a:e6 | community (Gen13) |
