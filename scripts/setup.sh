#!/bin/bash
# =============================================================
# setup.sh — Installation complète sur EC2 Ubuntu 24.04 LTS
# Télécharge le projet depuis GitHub Releases
# Installe tous les prérequis, importe les bases, prépare le run
# =============================================================
set -e

# ─── Couleurs ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Fonction : attendre que MySQL soit prêt ───────────────────
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

# ─── Variables ─────────────────────────────────────────────────
PROJECT_ROOT="/home/ubuntu/medical-projet"
BACKEND_DIR="$PROJECT_ROOT/pfe-backend"
FRONTEND_DIR="$PROJECT_ROOT/pfe-frontend"
VENV_DIR="$BACKEND_DIR/.venv"
DB_USER="django_user"
DB_PASSWORD="123"
DB_MEDICAL="medical_db"
DB_IM="im_db"
SQL_MEDICAL="$BACKEND_DIR/medical_db.sql"
SQL_IM="$BACKEND_DIR/im_db.sql"
BACKEND_URL="https://github.com/WiemHamila/medical-ressources/releases/download/v1.0.0/pfe-backend.tar.gz"
FRONTEND_URL="https://github.com/WiemHamila/medical-ressources/releases/download/v1.0.0/pfe-frontend.tar.gz"
TMUX_SESSION="medical"

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}   Setup EC2 — Projet Medical Django + React    ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# ─── Étape 1 : Mise à jour système + outils ───────────────────
log "Étape 1/8 — Mise à jour système et installation des outils..."
export DEBIAN_FRONTEND=noninteractive
apt update -qq
apt upgrade -y -qq
apt install -y -qq \
  python3 python3-pip python3-venv python3-full python3-dev \
  libmysqlclient-dev build-essential pkg-config \
  mysql-server \
  curl wget unzip dos2unix \
  tmux
success "Outils système installés"

# ─── Étape 2 : Node.js v20 ────────────────────────────────────
log "Étape 2/8 — Installation de Node.js v20..."
NODE_VERSION=$(node --version 2>/dev/null | cut -d'v' -f2 | cut -d'.' -f1 || echo "0")
if [ "$NODE_VERSION" -lt 20 ] 2>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
  apt install -y -qq nodejs
  success "Node.js $(node --version) installé"
else
  success "Node.js $(node --version) déjà OK"
fi

if ! command -v npm >/dev/null 2>&1; then
  warn "npm non trouvé — installation..."
  apt install -y -qq npm || true
fi

if command -v npm >/dev/null 2>&1; then
  success "npm $(npm --version) disponible"
else
  error "npm n'est toujours pas installé"
fi

# ─── Étape 3 : Télécharger le projet ──────────────────────────
log "Étape 3/8 — Téléchargement du projet depuis GitHub Releases..."
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

log "Téléchargement du backend..."
wget -q --show-progress -O pfe-backend.tar.gz "$BACKEND_URL"
tar -xzf pfe-backend.tar.gz
rm -f pfe-backend.tar.gz
success "Backend téléchargé et extrait"

log "Téléchargement du frontend..."
wget -q --show-progress -O pfe-frontend.tar.gz "$FRONTEND_URL"
tar -xzf pfe-frontend.tar.gz
rm -f pfe-frontend.tar.gz
success "Frontend téléchargé et extrait"

[ -d "$BACKEND_DIR" ]           || error "Dossier backend introuvable : $BACKEND_DIR"
[ -d "$FRONTEND_DIR" ]          || error "Dossier frontend introuvable : $FRONTEND_DIR"
[ -f "$BACKEND_DIR/manage.py" ] || error "manage.py introuvable"
success "Structure du projet vérifiée"

# ─── Étape 4 : CRLF → LF ─────────────────────────────────────
log "Étape 4/8 — Correction des fins de ligne..."
find "$BACKEND_DIR" \( -name "*.py" -o -name "*.js" -o -name "*.jsx" \) \
  | grep -v node_modules | grep -v __pycache__ \
  | xargs dos2unix -q 2>/dev/null || true
success "Fins de ligne corrigées"

# ─── Étape 5 : Python venv ────────────────────────────────────
log "Étape 5/8 — Environnement Python..."

# Trouver le bon binaire python3
PYTHON_BIN=$(which python3.12 2>/dev/null || which python3.11 2>/dev/null || which python3.10 2>/dev/null || which python3 2>/dev/null)
[ -z "$PYTHON_BIN" ] && error "Aucun binaire python3 trouvé"
log "Python utilisé : $PYTHON_BIN ($(${PYTHON_BIN} --version))"

# Supprimer un venv cassé si présent
[ -d "$VENV_DIR" ] && rm -rf "$VENV_DIR"

# Créer le venv avec --copies pour éviter les symlinks cassés
$PYTHON_BIN -m venv --copies "$VENV_DIR"

# Vérifier que pip est bien présent dans le venv
[ -f "$VENV_DIR/bin/pip" ]    || [ -f "$VENV_DIR/bin/pip3" ] || {
  log "pip absent du venv — bootstrap via ensurepip..."
  $PYTHON_BIN -m ensurepip --upgrade
  $PYTHON_BIN -m venv --copies "$VENV_DIR"
}

# Utiliser python du venv directement pour éviter tout problème de PATH
VENV_PYTHON="$VENV_DIR/bin/python"
[ -f "$VENV_PYTHON" ] || error "Le venv n'a pas de binaire python : $VENV_PYTHON"

log "Mise à jour de pip..."
"$VENV_PYTHON" -m pip install --quiet --upgrade pip

log "Installation des dépendances Python..."
"$VENV_PYTHON" -m pip install --quiet -r "$BACKEND_DIR/requirements.txt"

success "Python venv prêt : $VENV_DIR"

# ─── Étape 6 : MySQL ──────────────────────────────────────────
log "Étape 6/8 — MySQL..."
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
chmod 755 /var/run/mysqld
service mysql start || systemctl start mysql
wait_for_mysql

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_MEDICAL};
CREATE DATABASE IF NOT EXISTS ${DB_IM};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_MEDICAL}.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_IM}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
success "DB OK"

# ─── Étape 7 : Import SQL ─────────────────────────────────────
log "Étape 7/8 — Import SQL..."
[ -f "$SQL_MEDICAL" ] && mysql -u root "$DB_MEDICAL" < "$SQL_MEDICAL" && success "medical_db OK" || warn "medical_db ignorée"
[ -f "$SQL_IM" ]      && mysql -u root "$DB_IM"      < "$SQL_IM"      && success "im_db OK"      || warn "im_db ignorée"

# ─── Étape 8 : Migrations + npm install ───────────────────────
log "Étape 8/8 — Migrations Django + npm install..."

cd "$BACKEND_DIR"
"$VENV_PYTHON" manage.py migrate --run-syncdb 2>/dev/null || "$VENV_PYTHON" manage.py migrate
success "Migrations Django OK"

cd "$FRONTEND_DIR"
[ -d "node_modules" ] && rm -rf node_modules package-lock.json
npm install --silent
success "npm install OK"

chown -R ubuntu:ubuntu "$PROJECT_ROOT"

# ─── Lancement : tmux avec backend + frontend en parallèle ────
log "Lancement des serveurs dans tmux (session: $TMUX_SESSION)..."

# Tuer une ancienne session si elle existe
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true

# Créer la session tmux
tmux new-session -d -s "$TMUX_SESSION" -x 220 -y 50

# Panneau 0 — Backend Django
tmux send-keys -t "$TMUX_SESSION:0" \
  "cd '$BACKEND_DIR' && '$VENV_PYTHON' -m pip install -q -r requirements.txt && '$VENV_PYTHON' manage.py runserver 0.0.0.0:8000" Enter

# Panneau 1 — Frontend React (split vertical)
tmux split-window -h -t "$TMUX_SESSION:0"
tmux send-keys -t "$TMUX_SESSION:0.1" \
  "cd '$FRONTEND_DIR' && npm run dev" Enter

echo ""
echo -e "${GREEN}✅ Installation terminée !${NC}"
echo ""
echo -e "${BLUE}  Backend  →${NC} http://$(hostname -I | awk '{print $1}'):8000"
echo -e "${BLUE}  Frontend →${NC} http://$(hostname -I | awk '{print $1}'):5173"
echo ""
echo -e "${YELLOW}  Commandes tmux utiles :${NC}"
echo -e "  tmux attach -t $TMUX_SESSION        # voir les deux serveurs"
echo -e "  Ctrl+B D                             # détacher (serveurs restent actifs)"
echo -e "  Ctrl+B flèche droite/gauche          # naviguer entre les panneaux"
echo -e "  tmux kill-session -t $TMUX_SESSION   # tout arrêter"
echo ""
