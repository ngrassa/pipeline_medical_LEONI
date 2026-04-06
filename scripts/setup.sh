#!/bin/bash
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

wait_for_mysql() {
    local max_attempts=30
    local attempt=0
    log "Attente MySQL..."
    while [ $attempt -lt $max_attempts ]; do
        if mysqladmin ping --silent 2>/dev/null; then
            success "MySQL prêt"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    error "MySQL KO"
}

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

BACKEND_URL="https://github.com/WiemHamila/medical-ressources/releases/download/v1.0.0/pfe-backend.tar.gz"
FRONTEND_URL="https://github.com/WiemHamila/medical-ressources/releases/download/v1.0.0/pfe-frontend.tar.gz"

echo "===== SETUP PROD ====="

# ─── 1. SYSTEM ───────────────────────────────────────────────
log "Install packages..."
apt update -qq
apt install -y -qq \
 python3 python3-pip python3-venv python3-dev \
 build-essential pkg-config \
 mysql-server nginx curl wget unzip dos2unix

# ─── 2. NODE 20 ──────────────────────────────────────────────
log "Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null
apt remove -y nodejs npm >/dev/null 2>&1 || true
apt install -y nodejs
hash -r

# ─── 3. DOWNLOAD ─────────────────────────────────────────────
mkdir -p "$PROJECT_ROOT"
cd "$PROJECT_ROOT"

wget -q -O backend.tar.gz "$BACKEND_URL"
tar -xzf backend.tar.gz && rm backend.tar.gz

wget -q -O frontend.tar.gz "$FRONTEND_URL"
tar -xzf frontend.tar.gz && rm frontend.tar.gz

# ─── 4. FIX FILES ────────────────────────────────────────────
find "$PROJECT_ROOT" -type f | xargs dos2unix -q || true

# ─── 5. PYTHON ───────────────────────────────────────────────
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"
ln -sf $(which python3) "$VENV_DIR/bin/python"

pip install --upgrade pip
pip install -r "$BACKEND_DIR/requirements.txt"
pip install gunicorn

# ─── 6. MYSQL ────────────────────────────────────────────────
service mysql start
wait_for_mysql

mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_MEDICAL};
CREATE DATABASE IF NOT EXISTS ${DB_IM};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_MEDICAL}.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON ${DB_IM}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

[ -f "$SQL_MEDICAL" ] && mysql -u root "$DB_MEDICAL" < "$SQL_MEDICAL" || true
[ -f "$SQL_IM" ] && mysql -u root "$DB_IM" < "$SQL_IM" || true

# ─── 7. DJANGO ───────────────────────────────────────────────
cd "$BACKEND_DIR"
source "$VENV_DIR/bin/activate"

python manage.py migrate
python manage.py collectstatic --noinput

# ─── 8. FRONTEND BUILD ───────────────────────────────────────
cd "$FRONTEND_DIR"
npm install
npm run build

# ─── 9. GUNICORN SERVICE ─────────────────────────────────────
cat > /etc/systemd/system/gunicorn.service <<EOF
[Unit]
Description=Gunicorn Django
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$BACKEND_DIR
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn medical_platform.wsgi:application --bind 127.0.0.1:8000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable gunicorn
systemctl start gunicorn

# ─── 10. NGINX ───────────────────────────────────────────────
cat > /etc/nginx/sites-available/medical <<EOF
server {
    listen 80;

    location / {
        root $FRONTEND_DIR/dist;
        index index.html;
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
    }

    location /static/ {
        alias $BACKEND_DIR/staticfiles/;
    }
}
EOF

ln -sf /etc/nginx/sites-available/medical /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

systemctl restart nginx

# ─── DONE ────────────────────────────────────────────────────
echo ""
echo "✅ PRODUCTION READY"
echo "👉 http://IP_EC2"
