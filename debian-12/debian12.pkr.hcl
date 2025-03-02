/*
  _____       _     _               __ ___    _   _______ _____
 |  __ \     | |   (_)             /_ |__ \  | | |__   __/ ____|
 | |  | | ___| |__  _  __ _ _ __    | |  ) | | |    | | | (___
 | |  | |/ _ \ '_ \| |/ _` | '_ \   | | / /  | |    | |  \___ \
 | |__| |  __/ |_) | | (_| | | | |  | |/ /_  | |____| |  ____) |
 |_____/ \___|_.__/|_|\__,_|_| |_|  |_|____| |______|_| |_____/

  Packer Template to create a bare Debian 12.8.0 VM on Proxmox

*/

# ___  ____ ___  ____ _  _ ___  ____ _  _ ____ _ ____ ____
# |  \ |___ |__] |___ |\ | |  \ |___ |\ | |    | |___ [__
# |__/ |___ |    |___ | \| |__/ |___ | \| |___ | |___ ___]
#

packer {
  required_plugins {
    proxmox = {
      version = "1.2.1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}


# _  _ ____ ____ _ ____ ___  _    ____ ____
# |  | |__| |__/ | |__| |__] |    |___ [__
#  \/  |  | |  \ | |  | |__] |___ |___ ___]
#

variable "proxmox_api_url" {
  type = string
}
variable "proxmox_api_token_id" {
  type = string
}
variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}
variable "packer_srv" {
  type      = string
}
///
variable "ssh_username" {
  type = string
}
variable "ssh_password" {
  type = string
  sensitive = true
}
//
variable "lan_bridge" {
  type    = string
  default = "vmbr1"
}
variable "cpu_cores" {
  type    = string
  default = "2"
}
variable "memory" {
  type    = string
  default = "8192"
}
variable "balloon" {
  type    = string
  default = "0" # 0 -> Ballooning disabled
}
variable "bootloader" {
  type = string
  default = "uki"
}


# ___  ____ ____ _  _ _  _ ____ _  _    _  _ _  _    _  _ ____ ____ _  _ _ _  _ ____
# |__] |__/ |  |  \/  |\/| |  |  \/     |  | |\/|    |\/| |__| |    |__| | |\ | |___
# |    |  \ |__| _/\_ |  | |__| _/\_     \/  |  |    |  | |  | |___ |  | | | \| |___
#

source "proxmox-iso" "debian12" {

  # Proxmox Connection Settings
  proxmox_url = "${var.proxmox_api_url}"
  username    = "${var.proxmox_api_token_id}"
  token       = "${var.proxmox_api_token_secret}"
  insecure_skip_tls_verify = true

  # VM Definition
  node                 = "tty13"
  vm_id                = "501"
  vm_name              = "debian-12-T{{ isotime `0106`}}-${var.bootloader}"
  template_description = "Debian 12.8.0 Bare template"
  tags                 = "t" # Semicolon separated list (e.g. "SaaS;infra")

  # OS
  qemu_agent = true
  os         = "l26" # Linux kernel >=2.6 optimizations
  boot_iso {
    iso_storage_pool = "local"
    iso_url          = "https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/netboot/mini.iso"
    iso_checksum     = "file:https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/current/images/SHA256SUMS"
    iso_download_pve = true # Download ISO from Proxmox directly
    unmount          = true
  }

  # Machine
  bios    = "ovmf"
  machine = "q35"
  efi_config {
    efi_storage_pool = "local-zfs"
    efi_type         = "4m"
  }

  # CPU
  cpu_type = "host"
  cores    = "${var.cpu_cores}"

  # Memory
  memory             = "${var.memory}"
  ballooning_minimum = "${var.balloon}"

  # Display
  vga {
    type = "serial0"
  }
  serials = ["socket"]

  # Network
  network_adapters {
    model         = "virtio"
    bridge        = "${var.lan_bridge}"
    firewall      = "false"
    packet_queues = "${var.cpu_cores}"
  }

  # Storage
  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size    = "64G"
    format       = "raw"
    storage_pool = "local-zfs"
    type         = "scsi"
    cache_mode   = "writeback"
    io_thread    = true
    asyncio      = "io_uring"
    discard      = true
    ssd          = true
  }
  disks {
    disk_size    = "64G"
    format       = "raw"
    storage_pool = "local-zfs"
    type         = "scsi"
    cache_mode   = "writeback"
    io_thread    = true
    asyncio      = "io_uring"
    discard      = true
    ssd          = true
  }

  # Cloud-Init drive
  cloud_init              = true # add empty drive after finish
  cloud_init_storage_pool = "local-zfs"
  cloud_init_disk_type    = "scsi" # Add CI drive as scsi, prevents bug #973 (ide CI drive not working on q35 images)

  # BOOT COMMAND
  #
  # N.B.: set DEBCONF_DEBUG to user, developer or db for more verbosity
  # BOOT_DEBUG to 1/2 is more verbose, 3 is for drop-in shells
  boot_wait = "10s"
  boot_command = [
    "<wait5>c<wait2>",
    "linux /linux auto=true priority=critical ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "bootloader=${var.bootloader} ",
    "DEBIAN_FRONTEND=newt theme=dark ",
    "DEBCONF_DEBUG=user BOOT_DEBUG=1 ",
    "console=ttyS0 ---",
    "<enter><wait3>",
    "initrd /initrd.gz",
    "<enter><wait3>boot<enter>"
  ]

  # HTTP Server to provision the config files
  http_directory = "preseed"
  # (Optional) Bind IP Address and Port
  http_bind_address       = "${var.packer_srv}"
  http_port_min           = 8802
  http_port_max           = 8802

  communicator         = "ssh"
  ssh_password       = "${var.ssh_password}"
  ssh_username       = "${var.ssh_username}"
  ssh_wait_timeout   = "30m"
}


# ___  _  _ _ _    ___     ___ ____ _  _ ___  _    ____ ___ ____
# |__] |  | | |    |  \     |  |___ |\/| |__] |    |__|  |  |___
# |__] |__| | |___ |__/     |  |___ |  | |    |___ |  |  |  |___
#

build {

  name    = "debian-12-template"
  sources = ["source.proxmox-iso.debian-12"]

  provisioner "file" {
    destination = "/tmp/post-install.sh"
    source      = "files/post-install.sh"
  }
  provisioner "file" {
    destination = "/tmp/fstab"
    source      = "files/fstab"
  }


  # Issue some commands to finish the install
  provisioner "shell" {
    inline = [
       "sh -cx 'sudo bash /tmp/post-install.sh'"
    ]
  }
}