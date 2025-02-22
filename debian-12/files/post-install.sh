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

# Some bits of code here are taken from  https://gitlab.com/fabricioboreli.eti.br/packer_debian_bullseye_kvm
# I included a lot more security options for use in production, added bugfixes and tailored it to fit my needs

# Fail on error
set -euo pipefail
# Whatever that is
IFS=$'\n\t'

# ____ ____ _  _ ___
# | __ |__/ |  | |__]
# |__] |  \ |__| |__]
#

# If present, configure GRUB
if [ ! -f /uki ]; then
  echo "VM was generated with GRUB as main bootloader"
  mount /boot -vo remount
  # Reduce timeout
  sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
  # Disable consistent interface device naming and enable serial tty
  sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 console=tty1 console=ttyS0"/' /etc/default/grub
  # Disable quiet boot
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
  # Apply grub changes
  grub-mkconfig -vo /boot/grub/grub.cfg
  update-grub
else echo "VM was generated with UKI, skipping GRUB configuration" && rm /uki
fi

# ____ ____ ___ ____ ___
# |___ [__   |  |__| |__]
# |    ___]  |  |  | |__]
#

# Find EFI and put its UUID in provided fstab, then replace d-i-generated fstab with the proper one
sed -i "s|XXXX-XXXX|$(findmnt --output=UUID --noheadings --target=/boot/efi)|" /tmp/fstab
cat /tmp/fstab > /etc/fstab

# ___  ____ ____ _  _ ____ ____ ____ ____
# |__] |__| |    |_/  |__| | __ |___ [__
# |    |  | |___ | \_ |  | |__] |___ ___]
#

# This has been deprecated in systemd 253-4
# Keeping this fix around  as a comment because it seem the bug is still there,
# they only avoid it by preventing localectl from setting keymaps altogether...
#
# Fix the keyboard mapping bug that has been around for >=10y...
# wget https://www.kernel.org/pub/linux/utils/kbd/kbd-2.7.1.tar.gz -O /tmp/kbd-2.7.1.tar.gz
# cd /tmp && tar xzf kbd-2.7.1.tar.gz
# mkdir -p /usr/share/keymaps
# cp -Rp /tmp/kbd-2.7.1/data/keymaps/* /usr/share/keymaps/
# localectl set-keymap fr-pc

# Instead, this is the new fix :
cat <<EOF > /etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="fr"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"
EOF
setupcon

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

# System
DEBIAN_FRONTEND=noninteractive apt-get install \
  systemd-boot \
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
  bash-completion \
  command-not-found \
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

update-alternatives --set editor /usr/bin/vim.basic

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

# Configure the ACPI daemon to gently turn off the VM when the "power button" is pressed
cp /usr/share/doc/acpid/examples/powerbtn /etc/acpi/events/powerbtn
cp /usr/share/doc/acpid/examples/powerbtn.sh /etc/acpi/powerbtn.sh
chmod +x /etc/acpi/powerbtn.sh
systemctl enable acpid

# QEMU guest agent
systemctl enable qemu-guest-agent

# Serial console
systemctl enable serial-getty@ttyS0.service

# Reload the daemon to take into account previous modifications
systemctl daemon-reload

# _  _ _  _ ____ _    _  _ ___ ___ ____ ____
# |  | |\ | |    |    |  |  |   |  |___ |__/
# |__| | \| |___ |___ |__|  |   |  |___ |  \
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

# ___  ___  _  _ ____    _  _ ____ ____ _  _ ____
# |  \ |__] |_/  | __    |__| |  | |  | |_/  [__
# |__/ |    | \_ |__]    |  | |__| |__| | \_ ___]
#

# Configure DPKG to remount the filesystem properly before and after it is run
cat <<EOF > /usr/local/bin/dpkg-remount-pre
#!/bin/sh
echo "Running pre-dpkg remount hooks..."
mount /usr -vo remount,rw && echo "/usr remounted writable"
mount /opt -vo remount,rw && echo "/opt remounted writable"
mount /tmp -vo remount,exec && echo "/tmp remounted executable"
mount /var/tmp -vo remount,exec && echo "/var/tmp remounted executable"
mount /var -vo remount,exec && echo "/var remounted executable"
if mount | grep /boot > /dev/null; then
    echo "/boot already mounted"
else
    mount /boot && echo "/boot mounted"
fi
if mount | grep /boot/efi > /dev/null; then
    echo "/boot/efi already mounted"
else
    mount /boot/efi && echo "/boot/efi mounted"
fi
EOF

cat <<EOF > /usr/local/bin/dpkg-remount-post
#!/bin/bash
echo "Running post-dpkg remount hook..."
mount /usr -vo remount && echo "/usr remounted "
mount /opt -vo remount && echo "/opt remounted "
mount /tmp -vo remount && echo "/tmp remounted "
mount /var/tmp -vo remount && echo "/var/tmp remounted "
mount /var -vo remount && echo "/var remounted "
# Unmount BOOT if it is set to noauto in fstab
if [[ \$(grep "/boot.*noauto" /etc/fstab) > /dev/null ]] && [[ \$(grep "/boot/efi.*noauto" /etc/fstab) > /dev/null ]]; then
  umount -qR /boot && echo "Boot partitions unmounted"
else
  echo "Boot partitions in fstab are not set to noauto, they will not be unmounted"
fi
EOF

chmod +x /usr/local/bin/dpkg-remount-pre /usr/local/bin/dpkg-remount-post

cat <<EOF > /etc/apt/apt.conf.d/50remount
DPkg
{
    Pre-Invoke  { "/usr/local/bin/dpkg-remount-pre" };
    Post-Invoke { "/usr/local/bin/dpkg-remount-post" };
};
EOF

# ____ _    ____ ____ _  _  _  _ ___
# |    |    |___ |__| |\ |  |  | |__]
# |___ |___ |___ |  | | \|  |__| |
#

# Remove artifacts to make the image more agnostic
find \
  /var/cache/apt \
  /var/lib/apt \
  /var/lib/dhcp \
  /var/log \
  ! -name "audit" \
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

# ____ _  _ ___ ___  _  _ ___
# |  | |  |  |  |__] |  |  |
# |__| |__|  |  |    |__|  |
#

echo "Post-install script ended sucessfully, printing some info about the VM.."

# Display some disk, partition, and usage information to packer output
lsblk
fdisk -l
df -h

# Remove temporary sudoers file then remove this very script
rm -f /etc/sudoers.d/debian
rm -f $(readlink -f $0)
