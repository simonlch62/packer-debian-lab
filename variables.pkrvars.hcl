# Surcharges de variables — modifiez ce fichier selon votre environnement.
# Usage : packer build -var-file=variables.pkrvars.hcl debian13.pkr.hcl

# vm_name  = "debian13-custom"
# memory   = 4096
# cpus     = 4
# headless = true

# Pour mettre à jour l'ISO :
#   1. Allez sur https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/
#   2. Copiez le nom exact du fichier netinst
#   3. Le checksum est résolu automatiquement depuis SHA256SUMS (pas besoin de le changer)
#
# iso_url = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.X.X-amd64-netinst.iso"
