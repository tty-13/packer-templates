#!/usr/bin/env bash

# oooooooooo.              .o8        o8o                               .o    .oooo.
# `888'   `Y8b            "888        `"'                             o888  .dP""Y88b
#  888      888  .ooooo.   888oooo.  oooo   .oooo.   ooo. .oo.         888        ]8P'
#  888      888 d88' `88b  d88' `88b `888  `P  )88b  `888P"Y88b        888      .d8P'
#  888      888 888ooo888  888   888  888   .oP"888   888   888        888    .dP'
#  888     d88' 888    .o  888   888  888  d8(  888   888   888        888  .oP     .o
# o888bood8P'   `Y8bod8P'  `Y8bod8P' o888o `Y888""8o o888o o888o      o888o 8888888888
#  ___  ____ ____ ___    _ _  _ ____ ___ ____ _    _       ____ ____ ____ _ ___  ___
#  |__] |  | [__   |  __ | |\ | [__   |  |__| |    |       [__  |    |__/ | |__]  |
#  |    |__| ___]  |     | | \| ___]  |  |  | |___ |___    ___] |___ |  \ | |     |

# This script is loosely inspired from Fabricio Boreli's post-install script
# https://gitlab.com/fabricioboreli.eti.br/packer_debian²_bullseye_kvm
#
# I included some more security options for use in production, added bugfixes and
# tailored it to fit my needs

# Fail on error
set -euo pipefail
# Whatever that is
IFS=$'\n\t'


# ____ ____ _  _ ___
# | __ |__/ |  | |__]
# |__] |  \ |__| |__]
#

# Reduce timeout
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
# Disable consistent interface device naming and enable serial tty
sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 console=tty1 console=ttyS0"/' /etc/default/grub
# Disable quiet boot
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
# Apply grub changes
grub-mkconfig -o /boot/grub/grub.cfg
update-grub

# ___  ____ ____ _  _ ____ ____ ____ ____
# |__] |__| |    |_/  |__| | __ |___ [__
# |    |  | |___ | \_ |  | |__] |___ ___]
#

# Fix the keyboard mapping bug that has been around for >=10y...
wget https://www.kernel.org/pub/linux/utils/kbd/kbd-2.7.1.tar.gz -O /tmp/kbd-2.7.1.tar.gz
cd /tmp && tar xzf kbd-2.7.1.tar.gz
mkdir -p /usr/share/keymaps
cp -Rp /tmp/kbd-2.7.1/data/keymaps/* /usr/share/keymaps/
localectl set-keymap fr-pc

# Configure localepurge to remove unused locales. This makes the image smaller.
echo "localepurge	localepurge/use-dpkg-feature	boolean	true" | debconf-set-selections
echo "localepurge	localepurge/nopurge	multiselect	en, en_US.UTF-8, fr, fr_FR.UTF-8"  | debconf-set-selections

DEBIAN_FRONTEND=noninteractive apt-get update

# QEMU guest utilities and stuff
DEBIAN_FRONTEND=noninteractive apt-get install \
  acpid \
  cloud-guest-utils \
  cloud-init \
  lsb-release \
  net-tools \
  qemu-guest-agent \
  pollinate \
  xxd \
  --yes

# Some essentials
DEBIAN_FRONTEND=noninteractive apt-get install \
  localepurge \
  python3-apt \
  python3 \
  curl \
  rsync \
  tree \
  screen \
  --yes

# Sysadmin tools
DEBIAN_FRONTEND=noninteractive apt-get install \
  vim \
  --yes

# Monitoring tools
DEBIAN_FRONTEND=noninteractive apt-get install \
  iptraf-ng \
  iftop \
  htop \
  --yes

# ____ ___ ____
# |___  |  |
# |___  |  |___
#

# Networking set to auto
cat << EOF > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
EOF

# Configure Pollinate to use ubuntu entropy server
sed -i 's/^SERVER=.*/SERVER="https:\/\/entropy.ubuntu.com\/"/' /etc/default/pollinate

# ____ _    ____ _  _ ___     _ _  _ _ ___
# |    |    |  | |  | |  \ __ | |\ | |  |
# |___ |___ |__| |__| |__/    | | \| |  |
#

# Distro-specific cloud-init
cat <<EOF > /etc/cloud/cloud.cfg.d/91_debian.cfg
# Distro specific settings
system_info:
   distro: debian
   default_user:
     name: debian
     lock_passwd: true
     groups: [sudo, adm, cdrom, netdev, plugdev, audio, video, dialout, dip]
     sudo: ["ALL=(ALL) ALL"]
     shell: /bin/bash
   package_mirrors:
     - arches: [default]
       failsafe:
         primary: http://deb.debian.org/debian
         security: http://security.debian.org/
   ssh_svcname: ssh
EOF

# Security
cat <<EOF > /etc/cloud/cloud.cfg.d/92_security.cfg
# Don't ouput SSH keys info to the console
ssh:
  emit_keys_to_console: false
ssh_quiet_keygen: true

# We don't deal with Amazon
disable_ec2_metadata: true

# Disable SSH password login
ssh_pwauth: false

# Seed some entropy from remote server
random_seed:
  command: [pollinate]
  command_required: true
  file: /dev/urandom
EOF


# Set user-data datasource
cat <<EOF > /etc/cloud/cloud.cfg.d/93_pve.cfg
# Allow only Cloud-init drive for Proxmox PVE
datasource_list:
- NoCloud
EOF

# Ansible
# cat <<EOF > /etc/cloud/cloud.cfg.d/94_ansible.cfg
# # Install and configure ansible

# EOF

# Prevent cloud-init from messing up with the network configuration
# ( IP assignation is done in OPNsense)
cat <<EOF > /etc/cloud/cloud.cfg.d/95_disable_network_config.cfg
# Disable network config
network:
  config: disabled
EOF

# ____ _   _ ____ ___ ____ _  _  ___
# [__   \_/  [__   |  |___ |\/|  |  \
# ___]   |   ___]  |  |___ |  |  |__/
#

# Configure cloud-init to start once multi-user has been started.
systemctl add-wants multi-user.target cloud-init.target

# Keep terminal output when boot is over
SYSTEMD_NO_CLEAR_FILE=/etc/systemd/system/getty@tty1.service.d/no-clear.conf
mkdir --parents "$(dirname "$SYSTEMD_NO_CLEAR_FILE")"
cat <<EOF > "$SYSTEMD_NO_CLEAR_FILE"
[Service]
TTYVTDisallocate=no
EOF
# Don't start getty prompt until cloud-init has finished
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/wait-cloud-init.conf
[Unit]
After=cloud-init.target
EOF
systemctl daemon-reload

# Configure the ACPI daemon to gently turn off the VM when the "power button" is pressed
cp /usr/share/doc/acpid/examples/powerbtn /etc/acpi/events/powerbtn
cp /usr/share/doc/acpid/examples/powerbtn.sh /etc/acpi/powerbtn.sh
chmod +x /etc/acpi/powerbtn.sh
systemctl enable acpid

# QEMU guest agent
systemctl enable qemu-guest-agent

# Serial console
systemctl enable serial-getty@ttyS0.service

# ____ _    ____ ____ _  _  _  _ ___
# |    |    |___ |__| |\ |  |  | |__]
# |___ |___ |___ |  | | \|  |__| |
#

# Remove all but the lastest kernel
DEBIAN_FRONTEND=noninteractive apt-get autoremove --yes --purge $(dpkg -l "linux-image*" | grep "^ii" | grep -v linux-image-cloud-amd64 | head -n -1 | cut -d " " -f 3)

# Remove package clutter
DEBIAN_FRONTEND=noninteractive apt-get install --yes deborphan # Let's try to remove some more
DEBIAN_FRONTEND=noninteractive apt-get autoremove \
  $(deborphan) \
  deborphan \
  dictionaries-common \
  iamerican \
  ibritish \
  localepurge \
  task-english \
  tasksel \
  tasksel-data \
  --purge --yes
DEBIAN_FRONTEND=noninteractive apt-get clean

# Remove artifacts to make the image more agnostic
find \
  /var/cache/apt \
  /var/lib/apt \
  /var/lib/dhcp \
  /var/log \
  -mindepth 1 -print -delete

rm -vf \
  /etc/adjtime \
  /etc/hostname \
  /etc/hosts \
  /etc/ssh/*key* \
  /var/cache/ldconfig/aux-cache \
  /var/lib/systemd/random-seed \
  ~/.bash_history \
  ${SUDO_USER}/.bash_history

truncate -s 0 /etc/machine-id

# Recreate some useful files.
touch /var/log/lastlog
chown root:utmp /var/log/lastlog
chmod 664 /var/log/lastlog

# Free all unused storage block.
fstrim --all --verbose
sync
# Display some usage information to packer output
df -h

# Remove temporary sudoers file then remove this very script
rm -f /etc/sudoers.d/debian
rm -f $(readlink -f $0)
