/*
  _____       _     _               __ ___    _   _______ _____
 |  __ \     | |   (_)             /_ |__ \  | | |__   __/ ____|
 | |  | | ___| |__  _  __ _ _ __    | |  ) | | |    | | | (___
 | |  | |/ _ \ '_ \| |/ _` | '_ \   | | / /  | |    | |  \___ \
 | |__| |  __/ |_) | | (_| | | | |  | |/ /_  | |____| |  ____) |
 |_____/ \___|_.__/|_|\__,_|_| |_|  |_|____| |______|_| |_____/

  Packer Template to create a bare Debian 12.8.0 VM on Proxmox

*/

# DEPENDENCIES
packer {
  required_plugins {
    proxmox = {
      version = "~>1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}


# VARIABLES
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
  default = "1"
}
variable "memory" {
  type    = string
  default = "2048"
}
variable "balloon" {
  type    = string
  default = "0" # 0 -> Ballooning disabled
}


# PROXMOX VM MACHINE
source "proxmox-iso" "debian-12" {

  # Proxmox Connection Settings
  proxmox_url = "${var.proxmox_api_url}"
  username    = "${var.proxmox_api_token_id}"
  token       = "${var.proxmox_api_token_secret}"
  insecure_skip_tls_verify = true

  # VM Definition
  node                 = "tty13"
  vm_id                = "500"
  vm_name              = "debian-12-template"
  template_description = "Debian 12.8.0 Image"
  tags                 = "T" # Semicolon separated list (e.g. "SaaS;infra")

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
    type = "std" //serial0
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
    disk_size    = "10G"
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
  boot_wait = "10s"
  boot_command = [
    "<wait5><down><enter><down><down><enter><wait30>",
    "http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg",
    "<enter>"
  ]

  # HTTP Server to provision the config files
  http_directory = "preseed"
  # (Optional) Bind IP Address and Port
  # http_bind_address       = "82.66.196.45"
  http_port_min           = 8802
  http_port_max           = 8802

  communicator         = "ssh"
  ssh_password       = "${var.ssh_password}"
  ssh_username       = "${var.ssh_username}"
  ssh_wait_timeout   = "45m"
}


# BUILD TEMPLATE
build {

  name    = "debian-12-template"
  sources = ["source.proxmox-iso.debian-12"]

  provisioner "file" {
    destination = "/tmp/post-install.sh"
    source      = "post-install.sh"
  }


  # Issue some commands to finish the install
  provisioner "shell" {
    inline = [
       "sh -cx 'sudo bash /tmp/post-install.sh'"
# Fix that annoying Debian bug (#790955) that has been around for ~10 years..
      # "wget https://www.kernel.org/pub/linux/utils/kbd/kbd-2.7.1.tar.gz -O /tmp/kbd-2.7.1.tar.gz",
      # "cd /tmp && tar xzf kbd-2.7.1.tar.gz",
      # "mkdir -p /usr/share/keymaps",
      # "cp -Rp /tmp/kbd-2.7.1/data/keymaps/* /usr/share/keymaps/",
      # "localectl set-keymap fr-pc",
      # # Clean-up and initialize cloud-init
      # "apt -y autoremove --purge",
      # "apt -y clean",
      # "apt -y autoclean",
      # "rm /etc/ssh/ssh_host_*",
      # "truncate -s 0 /etc/machine-id",
      # "cloud-init clean",
      # "echo 'datasource_list: [ConfigDrive, NoCloud]' > /etc/cloud/cloud.cfg.d/99_pve.cfg",
      # "sync"
    ]
  }
}