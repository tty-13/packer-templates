# Debian 12 bare VM
This creates a very bare Debian bookworm VM template for proxmox with the following settings :
- Q35 machine and UEFI bios
- Cloud-init
- SSH public-key-only authentication
- ANSSI-compliant partitioning with remount hooks for maintenance

Rename *credentials.template* to *credentials.pkr.hcl*. Also don't forget to set your credentials
for communicating with the Proxmox API in the parent folder (*../proxmox_api_credentials.pkr.hcl*)

Proxmox should be able to reach your packer machine, either through VPN or NAT rules or whatever.

Run with ./build.sh

For best security practices you should create a packer-only API token with only the relevant permissions on PVE.