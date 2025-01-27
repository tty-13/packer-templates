# Debian 12 bare VM
This creates a very bare Debian bookworm VM template for proxmox with the following settings :
- LVM on 10G scsi disk
- Q35 machine and UEFI bios
- 2G ram and 1 cpu core
- Cloud-init

Rename *credentials.template* to *credentials.pkr.hcl* and fill in your credentials.
Proxmox should be able to reach your packer machine, either through VPN or NAT rules or whatever.

Run with ./build.sh

For best security practices you should create a packer-only API token on PVE.