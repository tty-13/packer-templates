#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
packer build -var-file="$HERE/../proxmox_api_credentials.pkr.hcl" -var-file="$HERE/credentials.pkr.hcl" $HERE/debian13.pkr.hcl