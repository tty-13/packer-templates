# Debian 12 LTS
# ---
# Packer Template to create a Debian 12.8.0 server on Proxmox

# Dependencies
packer {
  required_plugins {
    proxmox = {
      version = "~>1.2.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# VARIABLES
# pve
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
# virtual hardware
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
  # Skip TLS Verification
  insecure_skip_tls_verify = true

  # VM Definition
  node                 = "tty13"
  vm_id                = "500"
  vm_name              = "debian-12"
  template_description = "Debian 12.8.0 Image"
  tags                 = "T" # Semicolon separated list (e.g. "SaaS;infra")

  # OS
  qemu_agent = true
  os = "l26" # Linux kernel >=2.6 optimizations
  boot_iso {
    iso_storage_pool = "local"
    iso_url = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.8.0-amd64-netinst.iso"
    iso_checksum = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS"
    iso_download_pve = true # Download ISO from Proxmox directly
    unmount = true
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
    disk_size    = "10G"
    format       = "raw"
    storage_pool = "local-zfs"
    type       = "scsi"
    cache_mode = "writeback"
    io_thread  = true
    asyncio    = "io_uring"
    discard    = true
    ssd        = true
  }

  # VM Cloud-Init Settings
  cloud_init              = true # add empty drive after finish
  cloud_init_storage_pool = "local-zfs"

  # PACKER Boot Commands
  /*
  boot_command = [
    "<wait3>c<wait3>",
    "linux /install.amd/vmlinuz ",
    "auto=true ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.preseed_file} ",
    "hostname=${var.vm_name} ",
    "domain=${var.domain} ",
    "interface=auto ",
    "vga=788 noprompt quiet --<enter>",
    "initrd /install.amd/initrd.gz<enter>",
    "boot<enter>"
  ] // This is the debian one */
  /* Christan Lampa's
  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><wait>",
    "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
    "<f10><wait>"
  ]*/

  boot_command = [
    "<wait5>",
    "c",
    "<wait3>",
    "linux /install.amd/vmlinuz auto url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---",
    "<enter>",
    "initrd /install.amd/initrd.gz",
    "<enter>"
    "boot"
    "<enter>"
  ]

  boot         = "c"
  boot_wait    = "10s"
  communicator = "ssh"

  # PACKER Autoinstall Settings
  http_directory = "preseed"
  # (Optional) Bind IP Address and Port
  # http_bind_address       = "0.0.0.0"
  # http_port_min           = 8802
  # http_port_max           = 8802

  ssh_username = "your-user-name"

  # (Option 1) Add your Password here
  # ssh_password        = "your-password"
  # - or -
  # (Option 2) Add your Private SSH KEY file here
  # ssh_private_key_file    = "~/.ssh/id_rsa"

  # Raise the timeout, when installation takes longer
  ssh_timeout = "30m"
  ssh_pty     = true
}





# Build Definition to create the VM Template
build {

  name    = "ubuntu-server-noble"
  sources = ["source.proxmox-iso.ubuntu-server-noble"]

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #1
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo rm /etc/ssh/ssh_host_*",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt -y autoremove --purge",
      "sudo apt -y clean",
      "sudo apt -y autoclean",
      "sudo cloud-init clean",
      "sudo rm -f /etc/cloud/cloud.cfg.d/subiquity-disable-cloudinit-networking.cfg",
      "sudo rm -f /etc/netplan/00-installer-config.yaml",
      "sudo sync"
    ]
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #2
  provisioner "file" {
    source      = "files/99-pve.cfg"
    destination = "/tmp/99-pve.cfg"
  }

  # Provisioning the VM Template for Cloud-Init Integration in Proxmox #3
  provisioner "shell" {
    inline = ["sudo cp /tmp/99-pve.cfg /etc/cloud/cloud.cfg.d/99-pve.cfg"]
  }

  # Add additional provisioning scripts here
  # ...
}