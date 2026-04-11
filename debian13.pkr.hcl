packer {
  required_version = ">= 1.9.0"
  required_plugins {
    vsphere = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

# ─── Variables ────────────────────────────────────────────────────────────────

variable "vm_name" {
  type    = string
  default = "TPL_DEB_13"
}

variable "iso_url" {
  type        = string
  description = "URL de l'ISO Debian 13 netinst (amd64)"
  # Mettre à jour avec la dernière version disponible sur :
  # https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/
  default = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum auto-résolu depuis le fichier SHA256SUMS officiel Debian"
  default     = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"
}

variable "disk_size" {
  type        = number
  description = "Taille du disque en MB"
  default     = 20480 # 20 Go
}

variable "memory" {
  type        = number
  description = "RAM allouée en MB"
  default     = 2048 # 2 Go
}

variable "cpus" {
  type    = number
  default = 2
}

# ─── Variables ESXi ───────────────────────────────────────────────────────────

variable "esxi_host" {
  type        = string
  description = "Adresse IP ou FQDN de l'hôte ESXi"
  default     = "192.168.1.202"
}

variable "esxi_username" {
  type        = string
  description = "Utilisateur de l'ESXi (ex : root)"
  sensitive   = true
}

variable "esxi_password" {
  type        = string
  description = "Mot de passe de l'ESXi"
  sensitive   = true
}

variable "esxi_datastore" {
  type        = string
  description = "Nom du datastore ESXi où déployer la VM"
  default     = "DISK_0"
}

variable "esxi_network" {
  type        = string
  description = "Nom du portgroup ESXi"
  default     = "VM Network"
}

# ─── Source vSphere ISO ───────────────────────────────────────────────────────
# Le builder vsphere-iso se connecte directement à l'API ESXi (sans vCenter).

source "vsphere-iso" "debian13" {

  # --- Connexion ESXi
  vcenter_server      = var.esxi_host
  host                = var.esxi_host  # Hôte ESXi cible (requis même sans vCenter)
  username            = var.esxi_username
  password            = var.esxi_password
  insecure_connection = true # Certificat auto-signé ESXi

  # --- Identification VM
  vm_name       = var.vm_name
  guest_os_type = "debian13_64Guest"

  # --- Ressources
  CPUs = var.cpus
  RAM  = var.memory

  # --- Disque
  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }
  disk_controller_type = ["pvscsi"]

  # --- Réseau
  network_adapters {
    network      = var.esxi_network
    network_card = "vmxnet3"
  }

  # --- Datastore de destination
  datastore = var.esxi_datastore

  # convert_to_template non supporté sur ESXi standalone (nécessite vCenter)
  # → Conversion manuelle via l'UI ESXi après le build (clic droit > Convert to template)

  # --- open-vm-tools géré par apt, pas par vSphere
  tools_upgrade_policy = false

  # --- Retirer le lecteur CD après le build (template propre)
  remove_cdrom = true

  # --- Description visible dans l'UI ESXi
  notes = "Debian 13 (Trixie) — Template générée par Packer\nUtilisateur : root/root — student/root\nPaquets : openssh-server, sudo, open-vm-tools, docker.sh"

  # --- ISO (Packer télécharge et uploade sur le datastore automatiquement)
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # --- Serveur HTTP local pour le preseed (Packer l'expose automatiquement)
  http_directory = "http"
  http_port_min  = 8100
  http_port_max  = 8199

  # --- Connexion SSH post-installation (Packer attend que le SSH réponde)
  ssh_username = "root"
  ssh_password = "root"
  ssh_timeout  = "60m"

  # --- Firmware EFI
  firmware = "efi"

  # --- Commande de démarrage (GRUB EFI — touche 'e' pour éditer l'entrée Install)
  boot_wait = "15s"
  boot_command = [
    "e<wait2>",
    "<down><down><down><end>",
    " auto=true priority=critical url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<wait>",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]
}

# ─── Build ────────────────────────────────────────────────────────────────────

build {
  name    = "debian13"
  sources = ["source.vsphere-iso.debian13"]

  # ── Clavier AZERTY (TTY / VMRC) ──────────────────────────────────────────────
  provisioner "shell" {
    inline = [
      "echo 'XKBMODEL=\"pc105\"'    >  /etc/default/keyboard",
      "echo 'XKBLAYOUT=\"fr\"'      >> /etc/default/keyboard",
      "echo 'XKBVARIANT=\"\"'       >> /etc/default/keyboard",
      "echo 'XKBOPTIONS=\"\"'       >> /etc/default/keyboard",
      "echo 'BACKSPACE=\"guess\"'   >> /etc/default/keyboard",
      "setupcon --force",
    ]
  }

  # ── Welcome screen ──────────────────────────────────────────────────────────
  # Dépose le script dans /etc/profile.d/ → exécuté à chaque connexion shell
  provisioner "file" {
    source      = "scripts/welcome.sh"
    destination = "/etc/profile.d/welcome.sh"
  }

  provisioner "shell" {
    inline = ["chmod 755 /etc/profile.d/welcome.sh"]
  }

  # ── Alias ll ─────────────────────────────────────────────────────────────────
  provisioner "shell" {
    inline = [
      "echo \"alias ll='ls -lh --color=auto'\" >> /root/.bashrc",
      "echo \"alias ll='ls -lh --color=auto'\" >> /home/student/.bashrc",
    ]
  }

  # ── Script d'installation Docker ─────────────────────────────────────────────
  # Déposé dans /root — à exécuter manuellement : bash /root/docker.sh
  provisioner "file" {
    source      = "scripts/docker.sh"
    destination = "/root/docker.sh"
  }

  provisioner "shell" {
    inline = ["chmod 755 /root/docker.sh"]
  }

  # ── Bannière de connexion (console + SSH) ────────────────────────────────────
  # En dernier : le script fait un restart sshd qui couperait les provisioners suivants
  provisioner "shell" {
    script = "scripts/setup-banner.sh"
  }

  # ── Emplacement réservé pour vos provisioners futurs ────────────────────────
  # provisioner "shell" {
  #   script = "scripts/setup.sh"
  # }
  #
  # provisioner "ansible" {
  #   playbook_file = "ansible/site.yml"
  # }
}
