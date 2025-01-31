/*

     )   (        )   (            )  (
  ( /(   )\ )  ( /(   )\ )      ( /(  )\ )
  )\()) (()/(  )\()) (()/( (    )\())(()/( (
 ((_)\   /(_))((_)\   /(_)))\  ((_)\  /(_)))\
   ((_) (_))   _((_) (_)) ((_)  _((_)(_)) ((_)
  / _ \ | _ \ | \| | / __|| __|| \| |/ __|| __|
 | (_) ||  _/ | .` | \__ \| _| | .` |\__ \| _|
  \___/ |_|   |_|\_| |___/|___||_|\_||___/|___|

 Packer Template to build a Proxmox OPNsense VM

*/

# A dedicated hardware running OPNsense is always a much
# better choice, however this comes with some increased
# cost, so one might want to run OPNsense on a VM instead
# There is not much overhead and some care is brought to
# mitigate the security concerns

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
///
variable "root_password" {
  type      = string
  sensitive = true
}

/*
You should define 3 bridges on PVE, with Proxmox facing only
the admin_lan bridge, see the following example.
Note : If you have multiple NICs as separate pci devices, it
might be better to passthrough one of them to the VM.

auto vmbr0
iface vmbr0 inet manual
        bridge-ports eno1
        bridge-stp off
        bridge-fd 0
#WAN bridge

auto vmbr1
iface vmbr1 inet manual
        bridge-ports none
        bridge-stp off
        bridge-fd 0
#LAN bridge (VMs)

auto vmbr2
iface vmbr2 inet static
        address 192.168.3.1/24
        gateway 192.168.3.254
        bridge-ports none
        bridge-stp off
        bridge-fd 0
#LAN bridge (Admin)
*/

variable "wan_bridge" {
  type    = string
  default = "vmbr0"
}
variable "lan_bridge" {
  type    = string
  default = "vmbr1"
}
variable "admin_lan_bridge" {
  type    = string
  default = "vmbr2"
}
# # WAN
# variable "wan_bridge" {
#   type    = string
#   default = "vmbr0"
# }
# variable "wan_ip" {
#   type    = string
#   default = "192.168.1.253"
# }
# variable "wan_subnet" {
#   type = string
#   default = "24"
# }
# variable "wan_gw" {
#   type=string
#   default = "192.168.1.254"
# }
# # LAN
# variable "lan_bridge" {
#   type    = string
#   default = "vmbr1"
# }
# variable "lan_ip" {
#   type    = string
#   default = "192.168.13.254"
# }
# variable "lan_subnet" {
#   type = string
#   default = "24"
# }
# # ADMIN_LAN
# variable "admin_lan_bridge" {
#   type    = string
#   default = "vmbr2"
# }
# variable "admin_lan_ip" {
#   type    = string
#   default = "192.168.3.254"
# }
# variable "admin_lan_subnet" {
#   type = string
#   default = "24"
# }

# 64G should be plenty enough to retain sufficient logs
variable "storage_size" {
  type    = string
  default = "64G"
}
# 4 cores should be optimal, could go with 2 for a homelab, increase as needed.
variable "cpu_cores" {
  type    = string
  default = "4"
}
# 8 GB of ram should be enough to permit some extensive logging to take place when needed
variable "memory" {
  type    = string
  default = "8192"
}
variable "balloon" {
  type    = string
  default = "0" # 0 -> Ballooning disabled
}


# ___  ____ ____ _  _ _  _ ____ _  _    _  _ _  _    _  _ ____ ____ _  _ _ _  _ ____
# |__] |__/ |  |  \/  |\/| |  |  \/     |  | |\/|    |\/| |__| |    |__| | |\ | |___
# |    |  \ |__| _/\_ |  | |__| _/\_     \/  |  |    |  | |  | |___ |  | | | \| |___
#

source "proxmox-iso" "opnsense" {

  # Proxmox Connection Settings
  proxmox_url              = "${var.proxmox_api_url}"
  username                 = "${var.proxmox_api_token_id}"
  token                    = "${var.proxmox_api_token_secret}"
  insecure_skip_tls_verify = true

  # VM Definition
  node                 = "tty13"
  vm_id                = "500"
  vm_name              = "opnsense-T{{ isotime `0601`}}"
  template_description = "OPNsense 24.7 VM template"
  tags                 = "t;fw;infra" # Semicolon separated list (e.g. "SaaS;infra")

  # OS
  qemu_agent = true
  os         = "other"
  boot_iso {
    iso_storage_pool  = "local"
    iso_file          = "local:iso/OPNsense-24.7-dvd-amd64.iso"
    #iso_url          = "https://mirror.fra10.de.leaseweb.net/opnsense/releases/mirror/OPNsense-24.7-dvd-amd64.iso.bz2"
    #iso_checksum     = "file:https://mirror.fra10.de.leaseweb.net/opnsense/releases/mirror/OPNsense-24.7-checksums-amd64.sha256"
    #iso_download_pve  = true # Download ISO from Proxmox directly
    unmount           = true
  }
  boot = "order=scsi0;ide2;net0"

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
    bridge        = "${var.wan_bridge}"
    firewall      = "false"
    packet_queues = "${var.cpu_cores}"
    #mac_address   = "AC:AB:13:00:00:00"
  }
  network_adapters {
    model         = "virtio"
    bridge        = "${var.lan_bridge}"
    firewall      = "false"
    packet_queues = "${var.cpu_cores}"
    #mac_address   = "AC:AB:13:00:00:01"
  }
  network_adapters {
    model         = "virtio"
    bridge        = "${var.admin_lan_bridge}"
    firewall      = "false"
    packet_queues = "${var.cpu_cores}"
    #mac_address   = "AC:AB:13:00:00:02"
  }

  # Storage
  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size    = "${var.storage_size}"
    format       = "raw"
    storage_pool = "local-zfs"
    type         = "scsi"
    cache_mode   = "writeback"
    io_thread    = true
    asyncio      = "io_uring"
    discard      = true
    ssd          = true
  }



  # CD to provision the config.xml
  additional_iso_files {
    iso_storage_pool  = "local"
    cd_files          = ["./cdrom/*"]
    cd_label          = "config"
    unmount           = true
    keep_cdrom_device = true          # keep this to provide the config to the clones

  }

  # BOOT COMMAND
  boot_wait = "5s"
  boot_command = [
    # Boot with serial as secondary display (we need VGA for boot command)
    # Depending on your hardware, you might need to increase the wait time here
    "5<wait3>1<wait3m>",
    # Let OPNsense boot fully with no involvement, then login
    "root<enter><wait>opnsense<enter><wait>",
    # Start importing the config file from the cdrom we provided
    "8<enter><wait3>opnsense-importer cd0<enter><wait6>",
    # Install qemu-guest-agent
    "pkg install os-qemu-guest-agent<enter><wait15>y<enter><wait15>y<enter><wait15>",
    "sysrc qemu_guest_agent_enable=\"YES\"<enter><wait>",
    # Install on UFS with otherwise default recommended options (also increase the wait time if needed)
    "opnsense-installer<enter><wait5><enter><wait2><down><enter><wait3>",
    "d<enter><wait2>y<wait>y<wait8m>",
    # Change root password with the one we provided in the credentials file
    "r<enter><wait>${var.root_password}<enter><wait>${var.root_password}<enter>",
    # Reboot and login back
    "<wait15>c<enter>"
  ]

  communicator     = "ssh"
  #pause_before_connecting = "15m"
  ssh_port                = "2222"
  ssh_username            = "packer"
  ssh_private_key_file    = "./packerkey"
  ssh_wait_timeout        = "45m"
}


# ___  _  _ _ _    ___     ___ ____ _  _ ___  _    ____ ___ ____
# |__] |  | | |    |  \     |  |___ |\/| |__] |    |__|  |  |___
# |__] |__| | |___ |__/     |  |___ |  | |    |___ |  |  |  |___
#

build {
  name    = "opnsense-template"
  sources = ["source.proxmox-iso.opnsense"]

  provisioner "file" {
    destination = "/tmp/post-install.sh"
    source      = "post-install.sh"
  }

  provisioner "shell" {
    inline = [
       "sudo sh /tmp/post-install.sh"
    ]
  }
}