# TP-Link TL-SG108E — Managed Switch Configuration

Declarative OpenTofu configuration for the **TP-Link TL-SG108E (Hardware V6.0)** Easy Smart Switch (`switch.dalles.it`).

## Active 802.1Q VLAN & PVID Port Matrix

| Port          | Connected Device      | PVID  | VLAN 10 (`infra`) | VLAN 20 (`trusted`) | VLAN 30 (`guest`) | VLAN 40 (`iot`) | VLAN 101 (`ISP`) | Role                     |
| :------------ | :-------------------- | :---: | :---------------: | :-----------------: | :---------------: | :-------------: | :--------------: | :----------------------- |
| **Port 1**    | ISP Fiber ONT         | `101` |    Not Member     |     Not Member      |    Not Member     |   Not Member    |    **Tagged**    | Carrier WAN In           |
| **Port 2**    | Lenovo M700 (`vmbr0`) | `10`  |    **Tagged**     |     **Tagged**      |    **Tagged**     |   **Tagged**    |    **Tagged**    | Router-on-a-Stick Trunk  |
| **Port 3**    | D-Link M32 Root AP    | `10`  |    **Tagged**     |     **Tagged**      |    **Tagged**     |   **Tagged**    |    Not Member    | Wireless Mesh Trunk      |
| **Ports 4–7** | _Available Access_    | `20`  |    Not Member     |    **Untagged**     |    Not Member     |   Not Member    |    Not Member    | Trusted LAN Access       |
| **Port 8**    | Emergency Rescue Port | `10`  |   **Untagged**    |     Not Member      |    Not Member     |   Not Member    |    Not Member    | Direct Management Rescue |

## Deployment

1. Populate your credentials in `terraform.tfvars` (using `variables.tf` as your reference).
2. Run `tofu init && tofu apply` to push VLAN assignments directly to the switch via UDP management.
