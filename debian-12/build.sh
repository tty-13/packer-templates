#!/bin/sh
packer build -var-file='./credentials.pkr.hcl' ./debian-12.pkr.hcl