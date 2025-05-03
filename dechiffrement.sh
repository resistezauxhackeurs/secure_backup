#!/bin/bash

set -e

# === Vérification des arguments ===

if [[ $# -lt 1 ]]; then
    echo "❌ Utilisation : $0 archive.secure-backup.tar"
    exit 1
fi

SECURE_ARCHIVE="$1"

# === Configuration ===

# Clé privée RSA pour le déchiffrement (modifie si besoin)
PRIVATE_KEY_PATH="backup_key"

# Répertoire temporaire pour extraction
WORKDIR="restore_temp_$(date +%s)"
mkdir "$WORKDIR"

echo "📦 Extraction de l'archive : $SECURE_ARCHIVE → $WORKDIR"
tar -xf "$SECURE_ARCHIVE" -C "$WORKDIR"

# Détection automatique des fichiers extraits
AES_ENC_FILE=$(find "$WORKDIR" -name "*.tar.gz.enc" | head -n1)
AES_KEY_ENC_FILE=$(find "$WORKDIR" -name "aes.key.enc" | head -n1)

if [[ ! -f "$AES_ENC_FILE" || ! -f "$AES_KEY_ENC_FILE" ]]; then
    echo "❌ Fichiers requis introuvables dans l'archive."
    exit 1
fi

# === Déchiffrement de la clé AES ===

echo "🔐 Déchiffrement de la clé AES"
openssl rsautl -decrypt -inkey "$PRIVATE_KEY_PATH" -in "$AES_KEY_ENC_FILE" -out "$WORKDIR/aes.key"

# === Déchiffrement de l'archive principale ===

ORIGINAL_ARCHIVE="${AES_ENC_FILE%.enc}"  # on retire le .enc
echo "🔓 Déchiffrement de l'archive en $ORIGINAL_ARCHIVE"
openssl enc -d -aes-256-cbc -in "$AES_ENC_FILE" -out "$ORIGINAL_ARCHIVE" -pass file:"$WORKDIR/aes.key"

# === Extraction finale ===

echo "📂 Extraction de l'archive finale"
tar -xzf "$ORIGINAL_ARCHIVE"

echo "✅ Restauration terminée avec succès !"

# === Nettoyage ===

rm -rf "$WORKDIR"
rm "$ORIGINAL_ARCHIVE"

echo "🧹 Nettoyage terminé"