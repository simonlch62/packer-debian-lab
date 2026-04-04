packer {
  required_version = ">= 1.9.0"
  required_plugins {
    vmware = {
      version = ">= 1.0.7"
      source  = "github.com/hashicorp/vmware"
    }
  }
}

# ─── Variables ────────────────────────────────────────────────────────────────

variable "vm_name" {
  type    = string
  default = "debian13"
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

variable "headless" {
  type        = bool
  description = "true = pas d'interface graphique pendant l'install"
  default     = false
}

# ─── Source VMware ISO ────────────────────────────────────────────────────────

source "vmware-iso" "debian13" {

  # --- Identification VM
  vm_name       = var.vm_name
  guest_os_type = "debian12-64" # Plus proche disponible dans VMware pour Debian 13

  # --- ISO
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # --- Ressources
  disk_size = var.disk_size
  memory    = var.memory
  cpus      = var.cpus

  # --- Réseau
  network              = "nat"
  network_adapter_type = "vmxnet3"

  # --- Serveur HTTP local pour le preseed (Packer l'expose automatiquement)
  http_directory = "http"
  http_port_min  = 8100
  http_port_max  = 8199

  # --- Connexion SSH post-installation (Packer attend que le SSH réponde)
  ssh_username = "root"
  ssh_password = "root"
  ssh_timeout  = "60m"

  # --- Affichage
  headless = var.headless

  # --- Commande de démarrage
  # Entre dans la ligne de commande GRUB (touche 'c') puis boot avec le preseed
  boot_wait = "12s"
  boot_command = [
    "<esc><wait3>",
    "auto priority=critical url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"
  ]

  # --- Répertoire de sortie (fichiers .vmx + .vmdk)
  output_directory = "output-${var.vm_name}"

  # --- Arrêt propre
  shutdown_command = "shutdown -h now"
}

# ─── Build ────────────────────────────────────────────────────────────────────

build {
  name    = "debian13"
  sources = ["source.vmware-iso.debian13"]

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
