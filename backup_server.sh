#!/bin/bash

set -e  # Stop en cas d'erreur

# === Configuration ===

# Répertoires à sauvegarder
directories_to_backup=(
    "/root"
    "/home/"
)

# Dossier de destination
backup_dir="/opt/backups"

public_key_path="backup_key.pem.pub"


embedded_key_base64=$(cat <<'EOF'
xxxxxxxxxxxxxxxxxxxxxx
EOF
)


echo "$embedded_key_base64" | base64 -d > "$public_key_path"

# Clé publique RSA utilisée pour chiffrer la clé AES


# Dossier des configs Nginx
nginx_conf_dir="/etc/nginx/sites-enabled"

# === Préparation ===

# Récupération du nom de domaine depuis les fichiers de config nginx
domain=$(grep -hEo "server_name\s+[^;]+" "$nginx_conf_dir"/* \
         | head -n 1 \
         | sed -E 's/server_name\s+//' \
         | awk '{print $1}' \
         | tr -d ';')

if [[ -z "$domain" ]]; then
    echo "❌ Aucun domaine trouvé, utilisation du hostname"
    domain=$(hostname)
fi

# Timestamps et noms de fichiers
timestamp=$(date +"%Y-%m-%d")
base_name="${timestamp}_${domain}"
archive_name="${base_name}.tar.gz"
encrypted_archive="${archive_name}.enc"
key_encrypted="aes.key.enc"
final_package="${base_name}.secure-backup.tar"

# Crée le dossier de backup
mkdir -p "$backup_dir"

# === Étape 1 : Créer l'archive de sauvegarde ===

existing_dirs=()

for dir in "${directories_to_backup[@]}"; do
    if [[ -d "$dir" ]]; then
        existing_dirs+=("$dir")
    else
        echo "⚠️ Répertoire ignoré (inexistant) : $dir"
    fi
done

if [[ ${#existing_dirs[@]} -eq 0 ]]; then
    echo "❌ Aucun répertoire valide à sauvegarder. Abandon."
    exit 1
fi

# === Création de l'archive uniquement avec les répertoires valides ===

tar -czf "$backup_dir/$archive_name" "${existing_dirs[@]}"
echo "📦 Archive créée : $archive_name"

# === Étape 2 : Générer une clé AES aléatoire ===

openssl rand -base64 32 > "$backup_dir/aes.key"
echo "🔑 Clé AES générée"

# === Étape 3 : Chiffrer l'archive avec AES ===

openssl enc -aes-256-cbc -salt \
    -in "$backup_dir/$archive_name" \
    -out "$backup_dir/$encrypted_archive" \
    -pass file:"$backup_dir/aes.key"

echo "🔐 Archive chiffrée avec AES"

# === Étape 4 : Chiffrer la clé AES avec la clé publique RSA ===

openssl rsautl -encrypt \
    -inkey "$public_key_path" -pubin \
    -in "$backup_dir/aes.key" \
    -out "$backup_dir/$key_encrypted"

echo "🔐 Clé AES chiffrée avec la clé RSA"

# === Étape 5 : Regrouper les deux fichiers chiffrés dans une archive finale ===

tar -cf "$backup_dir/$final_package" -C "$backup_dir" "$encrypted_archive" "$key_encrypted"
echo "✅ Backup final créé : $final_package"

# === Nettoyage des fichiers temporaires ===

rm "$backup_dir/$archive_name" \
   "$backup_dir/$encrypted_archive" \
   "$backup_dir/$key_encrypted" \
   "$backup_dir/aes.key"

echo "🧹 Fichiers temporaires supprimés"
max_backups=7

# Lister les backups par date de modification (plus anciens en premier)
backups_list=($(ls -1t "$backup_dir"/*.secure-backup.tar 2>/dev/null))

# S'il y a plus que le max autorisé, on supprime les plus anciens
if (( ${#backups_list[@]} > max_backups )); then
    to_delete=("${backups_list[@]:$max_backups}")
    for old_file in "${to_delete[@]}"; do
        echo "🗑️ Suppression ancien backup : $old_file"
        rm -f "$old_file"
    done
fi