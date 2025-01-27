#!/bin/sh
packer build -var-file='../proxmox_api_credentials.pkr.hcl' -var-file='./credentials.pkr.hcl' ./debian-12.pkr.hcl