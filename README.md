
# 🔐 Secure Backup & Restore for Linux Servers

Ce projet propose deux scripts Bash pour effectuer des **sauvegardes sécurisées** de serveurs Linux :

- `backup_server.sh` : archive et chiffre les répertoires spécifiés
- `dechiffrement.sh` : déchiffre et restaure une sauvegarde


---

## 🔍 Idée et fonctionnement

Ce système de sauvegarde chiffrée repose sur une approche hybride **RSA + AES** pour garantir sécurité et performance :

1. 🧠 Une **clé AES aléatoire** est générée pour chaque sauvegarde.
2. 📦 L’archive des dossiers à sauvegarder est compressée, puis **chiffrée avec AES-256-CBC**.
3. 🔐 La **clé AES est ensuite chiffrée avec une clé publique RSA**, pour que seul le détenteur de la clé privée puisse la récupérer.
4. 📁 Ces deux fichiers (archive AES + clé AES chiffrée) sont regroupés dans une seule archive `.secure-backup.tar`.
5. ✅ Au moment de la restauration, la clé privée RSA permet de déchiffrer la clé AES, puis l’archive.

Cette méthode permet :
- Un **chiffrement rapide** (grâce à AES)
- Une **confidentialité forte** (grâce à RSA)
- Une **restauration simple** et sécurisée sur un poste de confiance

---
    
## ⚙️ Prérequis

- Linux avec `bash` et `openssl`
- Accès root si besoin de sauvegarder `/root`, `/home`, etc.
- Clé **RSA** (clé publique sur le serveur, clé privée conservée ailleurs)

---

## 🔑 Générer une paire de clés RSA

Sur une machine de confiance :

```bash
openssl genrsa -out backup_key 2048
openssl rsa -in backup_key -pubout -out backup_key.pem.pub
```

- Copiez `backup_key.pem.pub` sur le serveur, dans le même dossier que `backup_server.sh`.
- Gardez `backup_key` **hors du serveur**, en sécurité.

---

## 📦 Script de sauvegarde – `backup_server.sh`

### 🧭 Fonctionnement

1. Archive les répertoires définis (par défaut `/root`, `/home`)
2. Génère une clé AES
3. Chiffre l’archive avec AES-256-CBC
4. Chiffre la clé AES avec RSA
5. Regroupe le tout dans une archive `.secure-backup.tar`
6. Supprime les fichiers temporaires
7. Garde les 7 dernières sauvegardes uniquement

### ⚙️ Configuration

Par défaut :
```bash
directories_to_backup=(
    "/root"
    "/home/"
)
backup_dir="/opt/backups"
public_key_path="backup_key.pem.pub"
```

Modifiez ces variables si nécessaire.

### ▶️ Exécution manuelle

```bash
chmod +x backup_server.sh
./backup_server.sh
```

Le fichier final aura un nom du type :
```
2025-05-03_monserveur.secure-backup.tar
```

---

## 🔁 Automatiser avec `cron`

Pour effectuer une sauvegarde tous les jours à 3h30 du matin :

```bash
crontab -e
```

Et ajoutez :

```cron
30 3 * * * /chemin/vers/backup_server.sh >> /var/log/secure-backup.log 2>&1
```

💡 N’oubliez pas de rendre le script exécutable (`chmod +x`) et de vérifier les permissions du dossier `/opt/backups`.

---

## 🔓 Script de restauration – `dechiffrement.sh`

### ▶️ Usage

Sur une machine de confiance avec la clé privée RSA :

```bash
chmod +x dechiffrement.sh
./dechiffrement.sh NOM_ARCHIVE.secure-backup.tar
```

### ⚠️ Configuration

Modifiez `PRIVATE_KEY_PATH` si votre clé privée ne s’appelle pas `backup_key` ou se trouve ailleurs.

### 📁 Résultat

Les fichiers extraits apparaîtront dans le dossier courant après déchiffrement.

---

## 🛡️ Bonnes pratiques

- Ne JAMAIS stocker la clé privée RSA sur le serveur.
- Automatisez le transfert des archives chiffrées vers un cloud ou un NAS.
- Surveillez les logs (`/var/log/secure-backup.log`) pour détecter les échecs.
- Testez régulièrement le processus de restauration.

---

## 🧙 Astuce

Pour restaurer uniquement une partie d’une sauvegarde, vous pouvez extraire manuellement après déchiffrement :

```bash
tar -xzf NOM_ARCHIVE.tar.gz path/to/restore
```

---

## 📂 Structure finale d'une archive chiffrée

```
NOM_ARCHIVE.secure-backup.tar
├── NOM_ARCHIVE.tar.gz.enc       ← Archive chiffrée avec AES
└── aes.key.enc                  ← Clé AES chiffrée avec RSA
```

---

## ✨ Auteur

Scripts conçus pour des sauvegardes robustes et simples à restaurer, même en situation critique.
