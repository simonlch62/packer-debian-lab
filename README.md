# Packer — Debian 13 (Trixie) pour VMware

## Paramètrage de la VM

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

## Branches

| Branche | Cible | Description |
|---|---|---|
| `main` | VMware Workstation / Fusion (local) | Build local, sortie dans `output-*/` |
| `deb13_esx` | ESXi 192.168.1.202 | Déploiement direct sur hôte ESXi distant |

---

## Utilisation

### Build local (branche `main`)

```bash
packer build -var-file=variables.pkrvars.hcl debian13.pkr.hcl
```

### Déploiement sur ESXi (branche `deb13_esx`)

Créer le fichier `secrets.pkrvars.hcl` (jamais commité, voir `.gitignore`) :

```hcl
esxi_username = "root"
esxi_password = "votre_mot_de_passe"
```

Puis lancer le build :

```bash
packer build \
  -var-file=variables.pkrvars.hcl \
  -var-file=secrets.pkrvars.hcl \
  debian13.pkr.hcl
```

La VM est déployée directement sur l'ESXi et reste enregistrée dans son inventaire.

---

## Configuration ESXi (`variables.pkrvars.hcl`)

| Variable | Valeur par défaut | Description |
|---|---|---|
| `esxi_host` | `192.168.1.202` | IP de l'hôte ESXi |
| `esxi_datastore` | `DISK_0` | Datastore de destination |
| `esxi_network` | `VM Network` | Portgroup ESXi |

---

## Maintien du projet

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

Une fois connecté en root sur la VM vous pouvez installer docker si besoin :

```bash
bash /root/docker.sh
```

---

## Structure du projet

```
debian_packer/
├── debian13.pkr.hcl          Configuration principale Packer
├── variables.pkrvars.hcl     Variables overridables (ESXi host, datastore, réseau)
├── secrets.pkrvars.hcl       Credentials ESXi — NON COMMITÉ (.gitignore)
├── .gitignore
├── http/
│   └── preseed.cfg           Installation Debian automatisée (d-i)
└── scripts/
    ├── welcome.sh            Diagnostic affiché à chaque connexion shell
    ├── setup-banner.sh       Bannières console et SSH (services systemd)
    └── docker.sh             Script d'installation Docker (exécution manuelle)
```
