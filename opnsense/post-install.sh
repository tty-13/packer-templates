#!/bin/sh

# Display some usage information to packer output
df -h

# Remove this very script
rm -f $(readlink -f $0)