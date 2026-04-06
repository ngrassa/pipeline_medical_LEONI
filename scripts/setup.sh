#!/bin/bash
# =============================================================
#  setup.sh — Installation complète sur EC2 Ubuntu 24.04 LTS
#  Télécharge le projet depuis GitHub Releases
#  Installe tous les prérequis, importe les bases, prépare le run
# =============================================================

set -e

# ─── Couleurs ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Fonction : attendre que MySQL soit prêt ─────────────────
wait_for_mysql() {
    local max_attempts=30
    local attempt=0
    log "Attente que MySQL soit prêt..."
    while [ $attempt -lt $max_attempts ]; do
        if mysqladmin ping --silent 2>/dev/null; then
            success "MySQL est prêt"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    error "MySQL n'a pas démarré après ${max_attempts} secondes"
}

# ─── Variables ───────────────────────────────────────────────
PROJECT_ROOT="/home/ubuntu/medical-projet"
BACKEND_DIR="$PROJECT_ROOT/pfe-backend"
FRONTEND_DIR="$PROJECT_ROOT/pfe-frontend"
VENV_DIR="$PROJECT_ROOT/venv"
DB_USER="django_user"
DB_PASSWORD="123"
DB_MEDICAL="medical_db"
DB_IM="im_db"
SQL_MEDICAL="$BACKEND_DIR/medical_db.sql"
SQL_IM="$BACKEND_DIR/im_db.sql"

# URLs de téléchargement (GitHub Releases)
BACKEND_URL="https://github.com/WiemHamila/medical-ressources/releases/download/v1.0.0/pfe-backend.tar.gz"
FRONTEND_URL="https://github.com/WiemHamila/medical-ressources/releases/download/v1.0.0/pfe-frontend.tar.gz"

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}   Setup EC2 — Projet Medical Django + React     ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# ─── Étape 1 : Mise à jour système + outils ──────────────────
log "Étape 1/8 — Mise à jour système et installation des outils..."

export DEBIAN_FRONTEND=noninteractive

apt update -qq
apt upgrade -y -qq
apt install -y -qq \
    python3 python3-pip python3-venv python3-full python3-dev \
    libmysqlclient-dev build-essential pkg-config \
    mysql-server \
    curl wget unzip dos2unix

success "Outils système installés"

# ─── Étape 2 : Node.js v20 ───────────────────────────────────
log "Étape 2/8 — Installation de Node.js v20..."

NODE_VERSION=$(node --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1 || echo "0")

if [ "$NODE_VERSION" -lt 20 ] 2>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt install -y -qq nodejs
    success "Node.js $(node --version) installé"
else
    success "Node.js $(node --version) déjà OK"
fi

# ─── Étape 3 : Télécharger le projet ─────────────────────────
log "Étape 3/8 — Téléchargement du projet depuis GitHub Releases..."

mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

# Télécharger le backend
log "Téléchargement du backend..."
wget -q --show-progress -O pfe-backend.tar.gz "$BACKEND_URL"
tar -xzf pfe-backend.tar.gz
rm -f pfe-backend.tar.gz
success "Backend téléchargé et extrait"

# Télécharger le frontend
log "Téléchargement du frontend..."
wget -q --show-progress -O pfe-frontend.tar.gz "$FRONTEND_URL"
tar -xzf pfe-frontend.tar.gz
rm -f pfe-frontend.tar.gz
success "Frontend téléchargé et extrait"

# Vérifier la structure
[ -d "$BACKEND_DIR" ]  || error "Dossier backend introuvable après extraction : $BACKEND_DIR"
[ -d "$FRONTEND_DIR" ] || error "Dossier frontend introuvable après extraction : $FRONTEND_DIR"
[ -f "$BACKEND_DIR/manage.py" ] || error "manage.py introuvable dans $BACKEND_DIR"

success "Structure du projet vérifiée"

# ─── Étape 4 : Corriger les fins de ligne ────────────────────
log "Étape 4/8 — Correction des fins de ligne (CRLF → LF)..."

find "$BACKEND_DIR" \( -name "*.py" -o -name "*.js" -o -name "*.jsx" \) \
    | grep -v node_modules | grep -v __pycache__ \
    | xargs dos2unix -q 2>/dev/null || true

success "Fins de ligne corrigées"

# ─── Étape 5 : Environnement Python virtuel ──────────────────
log "Étape 5/8 — Création de l'environnement Python virtuel..."

python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet -r "$BACKEND_DIR/requirements.txt"

success "Dépendances Python installées"

# ─── Étape 6 : MySQL — Démarrage + configuration ─────────────
log "Étape 6/8 — Configuration de MySQL..."

# S'assurer que le dossier socket existe
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
chmod 755 /var/run/mysqld

# Démarrer MySQL
service mysql start || systemctl start mysql
wait_for_mysql

# Créer les bases et l'utilisateur
log "Création des bases de données et de l'utilisateur..."

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_MEDICAL} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS ${DB_IM} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_MEDICAL}.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_IM}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

success "Bases de données et utilisateur créés"

# ─── Étape 7 : Import des bases de données ───────────────────
log "Étape 7/8 — Import des bases de données SQL..."

if [ -f "$SQL_MEDICAL" ] && [ -s "$SQL_MEDICAL" ]; then
    mysql -u root "$DB_MEDICAL" < "$SQL_MEDICAL"
    success "medical_db importée"
else
    warn "Fichier $SQL_MEDICAL introuvable ou vide — import ignoré"
fi

if [ -f "$SQL_IM" ] && [ -s "$SQL_IM" ]; then
    mysql -u root "$DB_IM" < "$SQL_IM"
    success "im_db importée"
else
    warn "Fichier $SQL_IM introuvable ou vide — import ignoré"
fi

# ─── Étape 8 : Migrations Django + Frontend ──────────────────
log "Étape 8/8 — Migrations Django et préparation du frontend..."

# Migrations Django
cd "$BACKEND_DIR"
source "$VENV_DIR/bin/activate"

# Mettre à jour settings.py pour écouter sur 0.0.0.0 si ALLOWED_HOSTS est restreint
if grep -q "ALLOWED_HOSTS" "$BACKEND_DIR"/*/settings.py 2>/dev/null; then
    SETTINGS_FILE=$(find "$BACKEND_DIR" -name "settings.py" -path "*/settings.py" | head -1)
    if [ -n "$SETTINGS_FILE" ]; then
        # Ajouter '*' aux ALLOWED_HOSTS si pas déjà présent
        if ! grep -q "'\\*'" "$SETTINGS_FILE"; then
            sed -i "s/ALLOWED_HOSTS\s*=\s*\[/ALLOWED_HOSTS = ['*', /" "$SETTINGS_FILE"
            success "ALLOWED_HOSTS mis à jour avec '*'"
        fi
    fi
fi

python manage.py migrate --run-syncdb 2>/dev/null || python manage.py migrate
success "Migrations Django appliquées"

# Installer les dépendances frontend
cd "$FRONTEND_DIR"

# Supprimer node_modules Windows si présent
if [ -d "node_modules" ]; then
    if find node_modules -name "*.node" | xargs file 2>/dev/null | grep -q "PE32" 2>/dev/null; then
        warn "node_modules Windows détecté — réinstallation..."
        rm -rf node_modules package-lock.json
    fi
fi

npm install --silent
success "Dépendances frontend installées"

# ─── Fixer les permissions ────────────────────────────────────
chown -R ubuntu:ubuntu "$PROJECT_ROOT"

# ─── Résumé final ────────────────────────────────────────────
echo ""
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   ✅ Installation terminée avec succès !         ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""
echo -e "  Le projet est prêt à être lancé."
echo -e "  Backend  : $BACKEND_DIR"
echo -e "  Frontend : $FRONTEND_DIR"
echo -e "  Venv     : $VENV_DIR"
echo ""
