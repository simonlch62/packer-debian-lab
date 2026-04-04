# Packer — Debian 13 (Trixie) pour VMware

## Prérequis

- [Packer](https://developer.hashicorp.com/packer/install) ≥ 1.9
- VMware Workstation ou VMware Player installé
- Accès Internet (téléchargement de l'ISO + paquets APT)

### Installer Packer sur Debian

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y packer
```

---

## Utilisation

```bash
# 1. Télécharger le plugin VMware
packer init debian13.pkr.hcl

# 2. Valider la configuration
packer validate -var-file=variables.pkrvars.hcl debian13.pkr.hcl

# 3. Lancer le build
packer build -var-file=variables.pkrvars.hcl debian13.pkr.hcl
```

La VM est générée dans `output-debian13/` (fichiers `.vmx` + `.vmdk`).  
Ouvrez le `.vmx` directement dans VMware Workstation/Player.

---

## Ce qui est configuré automatiquement

| Élément | Valeur |
|---|---|
| Langue / Clavier | fr_FR / AZERTY |
| Fuseau horaire | Europe/Paris |
| Utilisateur root | `root` / `root` |
| Utilisateur student | `root` / `root` + sudoers |
| SSH | PermitRootLogin yes, port 22 |
| Paquets | openssh-server, sudo, nano, wget, curl, git, htop, net-tools, dnsutils, bash-completion, tree, open-vm-tools |
| Alias | `ll` disponible pour root et student |
| Welcome screen | `/etc/profile.d/welcome.sh` — affiché à chaque connexion |
| Bannière console | `/etc/issue` — hostname + IP mis à jour au démarrage |
| Bannière SSH | `/etc/ssh/banner` — hostname + IP mis à jour au démarrage |
| Docker | `/root/docker.sh` — script d'install prêt à l'emploi |

---

## Ce qu'il faut éventuellement mettre à jour

### ISO Debian 13

Si la version de l'ISO a changé (point release 13.1, 13.2…), éditez `variables.pkrvars.hcl` :

```hcl
iso_url = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.4.0-amd64-netinst.iso"
```

Le checksum est résolu automatiquement depuis le fichier `SHA256SUMS` officiel Debian.  
Vérifiez le nom exact du fichier sur : https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/

### Ressources de la VM

Dans `variables.pkrvars.hcl`, décommentez et ajustez :

```hcl
memory    = 4096   # RAM en MB
cpus      = 4
disk_size = 40960  # Disque en MB
headless  = true   # true = pas de fenêtre pendant le build
```

### Ajouter des provisioners

Dans `debian13.pkr.hcl`, section `build {}`, un emplacement est prévu en fin de fichier :

```hcl
provisioner "shell" {
  script = "scripts/mon_script.sh"
}
```

### Installer Docker sur la VM

Une fois connecté en root sur la VM :

```bash
bash /root/docker.sh
```

---

## Structure du projet

```
packer-debian-lab/
├── debian13.pkr.hcl          Configuration principale Packer
├── variables.pkrvars.hcl     Variables overridables
├── .gitignore
├── http/
│   └── preseed.cfg           Installation Debian automatisée (d-i)
└── scripts/
    ├── welcome.sh            Diagnostic affiché à chaque connexion shell
    ├── setup-banner.sh       Bannières console et SSH (services systemd)
    └── docker.sh             Script d'installation Docker (exécution manuelle)
```
