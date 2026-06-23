#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
packer init -upgrade debian12.pkr.hcl
packer build -var-file="$HERE/../proxmox_api_credentials.pkr.hcl" -var-file="$HERE/credentials.pkr.hcl" $HERE/debian12.pkr.hcl