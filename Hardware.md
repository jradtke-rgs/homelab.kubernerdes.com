# Hardware Inventory

This page documents the physical hardware, bill of materials, and network switch layout for the Kubernerdes Homelab.

## Systems

| System     | Purpose           | Model       | CPU | CPU model   | Mem | Disk0 (SSD) | Disk1 NVMe |
|:-----------|:------------------|:------------|:----|:------------|:----|:------------|:-----------|
| nuc-00     | Admin Host        | NUC10i7FNK  | 12  | i7-10710U   | 64  | —           | 932        |
| nuc-01     | Harvester         | NUC10i7FNH  | 12  | i7-10710U   | 64  | 1843        | 932        |
| nuc-02     | Harvester         | NUC10i7FNH  | 12  | i7-10710U   | 64  | 1843        | 932        |
| nuc-03     | Harvester         | NUC10i7FNH  | 12  | i7-10710U   | 64  | 1843        | 932        |

> **Note:** All nodes are NUC10 (10th gen) units verified 2026-04-09. Harvester nodes have additional storage disks beyond the NVMe (sdb/sdc/sdd/sde ranging 2G–99G).

## Bill of Materials (BOM)

An inventory of everything that goes in the case.

| Total | Unit Cost | Qty | Object |
|------:|----------:|:---:|:-------|
| $350  | $350 | 1   | [Intel NUC NUC13ANHi3](https://download.intel.com/newsroom/2023/client-computing/Intel-NUC-13-Pro-Product-Brief.pdf) |
| $2,700 | $900 | 3   | [Intel NUC NUC13ANHi7](https://download.intel.com/newsroom/2023/client-computing/Intel-NUC-13-Pro-Product-Brief.pdf) |
| $304  | $76  | 4   | Chicony A17-120P2A 20V 6A 120W Power Supply (5.5mm - 2.5mm) |
| $36   | $12  | 3   | 1GB USB-C Network Adapter |
| $110  | $110 | 1   | [portable monitor Viewsonic VA1655](https://www.viewsonic.com/ph/products/lcd/VA1655) |
| $20   | $10  | 2   | power strip |
| $7    | $7   | 1   | mouse |
| $20   | $10  | 20  | 28 AWG Cat6 Network Cables (10 pack) |
| **$4,695** | | | **Estimated Total** |

## Switch Layout

Network port assignments on the unmanaged switch.

| Port | Host     | Purpose | Port | Host       | Purpose |
|:--:|:-----------|:--------|:----:|:-----------|:----|
| 1  | nuc-00     |         | 9    | nuc-02-kvm | |
| 2  | nuc-01     |         | 10   | nuc-03-kvm | | 
| 3  | nuc-02     |         | 11   |            | |
| 4  | nuc-03     |         | 12   |            | |
| 5  | nuc-01-vms |         | 13   |            | |
| 6  | nuc-02-vms |         | 14   |            | |
| 7  | nuc-03-vms |         | 15   | spark-e    | |
| 8  | nuc-01-kvm |         | 16   | uplink     | | 
