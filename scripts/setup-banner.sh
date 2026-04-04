#!/bin/bash

echo "=== Installation des messages de connexion personnalisés ==="

# Étape 1 : Créer le script de mise à jour de /etc/issue (console physique)
echo "[1/6] Création du script de mise à jour pour la console..."
cat > /usr/local/bin/update-issue.sh << 'EOF'
#!/bin/bash

# Attendre que l'IP soit disponible (max 30 secondes)
for i in {1..30}; do
    IP=$(hostname -I | awk '{print $1}')
    if [ -n "$IP" ]; then
        break
    fi
    sleep 1
done

# Si toujours pas d'IP après 30 secondes, mettre "En attente..."
if [ -z "$IP" ]; then
    IP="En attente..."
fi

HOSTNAME=$(hostname)

cat > /etc/issue << 'FIN'
================================================================================
                    MACHINE VIRTUELLE DE TEST
================================================================================

Nom de la machine : NOM_ICI
Adresse IP        : IP_ICI

Cette machine virtuelle est destinée uniquement à des fins de test.
Accès réservé aux utilisateurs autorisés.

================================================================================

FIN

sed -i "s/NOM_ICI/$HOSTNAME/" /etc/issue
sed -i "s/IP_ICI/$IP/" /etc/issue
EOF

# Étape 2 : Créer le script de mise à jour de la bannière SSH
echo "[2/6] Création du script de mise à jour pour SSH..."
cat > /usr/local/bin/update-ssh-banner.sh << 'EOF'
#!/bin/bash

# Attendre que l'IP soit disponible (max 30 secondes)
for i in {1..30}; do
    IP=$(hostname -I | awk '{print $1}')
    if [ -n "$IP" ]; then
        break
    fi
    sleep 1
done

if [ -z "$IP" ]; then
    IP="En attente..."
fi

HOSTNAME=$(hostname)

cat > /etc/ssh/banner << 'FIN'
================================================================================
                    MACHINE VIRTUELLE DE TEST
================================================================================

Nom du serveur : NOM_ICI
Adresse IP     : IP_ICI

⚠️  AVERTISSEMENT ⚠️
Cette machine virtuelle est destinée uniquement à des fins de test.
Toute connexion est enregistrée et surveillée.
Accès réservé aux utilisateurs autorisés uniquement.

================================================================================
FIN

sed -i "s/NOM_ICI/$HOSTNAME/" /etc/ssh/banner
sed -i "s/IP_ICI/$IP/" /etc/ssh/banner
EOF

# Étape 3 : Rendre les scripts exécutables
echo "[3/6] Configuration des permissions..."
chmod +x /usr/local/bin/update-issue.sh
chmod +x /usr/local/bin/update-ssh-banner.sh

# Étape 4 : Créer le service systemd pour /etc/issue
echo "[4/6] Création du service systemd pour la console..."
cat > /etc/systemd/system/update-issue.service << 'EOF'
[Unit]
Description=Afficher IP et nom sur écran de connexion
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-issue.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Étape 5 : Créer le service systemd pour la bannière SSH
echo "[5/6] Création du service systemd pour SSH..."
cat > /etc/systemd/system/update-ssh-banner.service << 'EOF'
[Unit]
Description=Afficher IP et nom dans la bannière SSH
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-ssh-banner.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Étape 6 : Configurer SSH pour utiliser la bannière
echo "[6/6] Configuration de SSH..."
if ! grep -q "^Banner /etc/ssh/banner" /etc/ssh/sshd_config; then
    echo "Banner /etc/ssh/banner" >> /etc/ssh/sshd_config
fi

# Activer et démarrer les services
systemctl daemon-reload
systemctl enable update-issue.service
systemctl enable update-ssh-banner.service
systemctl start update-issue.service
systemctl start update-ssh-banner.service

# Redémarrer SSH pour appliquer la bannière
systemctl restart sshd

# Exécuter maintenant pour tester
/usr/local/bin/update-issue.sh
/usr/local/bin/update-ssh-banner.sh

echo ""
echo "✓ Installation terminée !"
echo ""
echo "Aperçu du message de connexion console :"
echo "========================================"
cat /etc/issue
echo ""
echo "Aperçu de la bannière SSH :"
echo "==========================="
cat /etc/ssh/banner
echo ""
echo "Pour tester :"
echo "  - Console : déconnectez-vous et reconnectez-vous"
echo "  - SSH     : connectez-vous en SSH depuis un autre terminal"
echo "  - Reboot  : reboot"
