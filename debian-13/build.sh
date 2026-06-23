#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
packer init -upgrade $HERE/debian13.pkr.hcl
packer build -force -var-file="$HERE/../proxmox_api_credentials.pkr.hcl" -var-file="$HERE/credentials.pkr.hcl" $HERE/debian13.pkr.hcl