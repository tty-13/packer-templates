# Packer templates to be used with Proxmox

For now only Debian 12 and OPNsense, might add some more later.

I made that public so others can take inspiration from it, it was kinda hard to find relevant debian-specific documentation online (and virtually nothing on OPNsense, as you'd expect).

Rename *proxmox_api_credentials.template* to *proxmox_api_credentials.pkr.hcl* and fill in your Proxmox API credentials.

For best security practices you should create a packer-only API token with only the relevant permissions on PVE.

Please note many options are tailored to fit my needs and should be changed (like the proxmox node, vm IDs and other stuff),
I provide these files as-is and do not intend to make them agnostic yet.