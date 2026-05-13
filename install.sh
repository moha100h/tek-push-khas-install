#!/bin/bash

echo ""
echo "=================================================="
echo "   Session Manager Pro - Auto Installer"
echo "=================================================="
echo ""

# رنگ‌ها
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!!]${NC} $1"; }
err()    { echo -e "${RED}[ERR]${NC} $1"; exit 1; }
info()   { echo -e "${CYAN}[>>]${NC} $1"; }

# متغیرها
BOT_TOKEN="8857350914:AAEovAJjOjLIKVQW7ocSDaX5zEE0sTu_F4Q"
API_ID="32351310"
API_HASH="9b4e6a3d9fa116dccef9a20c3c961840"
POSTGRES_DB="tisdata"
POSTGRES_USER="tisadmin"
POSTGRES_PASSWORD='SN662499$rr'
INSTALL_DIR="/var/www/session-manager-pro"
REPO_URL="https://github.com/moha100h/session-manager-pro.git"

echo "[1/6] دریافت IP سرور..."
SERVER_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
echo "      IP: $SERVER_IP"

# چک root
if [ "$EUID" -ne 0 ]; then
    err "باید با root اجرا شود. دستور: sudo bash install.sh"
fi
log "دسترسی root تایید شد"

echo ""
echo "[2/6] آپدیت سیستم..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q 2>&1 | tail -1
apt-get install -y -q curl git wget ufw ca-certificates gnupg 2>&1 | tail -1
log "سیستم آپدیت شد"

echo ""
echo "[3/6] نصب Docker..."
if command -v docker &>/dev/null; then
    log "Docker قبلا نصب است: $(docker --version)"
else
    info "در حال نصب Docker..."
    curl -fsSL https://get.docker.com | sh 2>&1 | tail -3
    systemctl enable docker 2>/dev/null
    systemctl start docker 2>/dev/null
    sleep 3
    log "Docker نصب شد: $(docker --version)"
fi

echo ""
echo "[4/6] دریافت پروژه..."
mkdir -p /var/www
if [ -d "$INSTALL_DIR/.git" ]; then
    info "پروژه موجود است - آپدیت..."
    cd "$INSTALL_DIR" && git pull origin main 2>&1 | tail -1 || warn "git pull ناموفق"
else
    rm -rf "$INSTALL_DIR"
    info "کلون پروژه..."
    git clone "$REPO_URL" "$INSTALL_DIR" 2>&1 | tail -2
    if [ ! -d "$INSTALL_DIR" ]; then
        err "کلون ناموفق بود"
    fi
fi
cd "$INSTALL_DIR"
log "پروژه آماده: $INSTALL_DIR"
ls -la

echo ""
echo "[5/6] ساخت .env..."
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "fallback_jwt_secret_change_me_32ch")
ENCRYPTION_KEY=$(openssl rand -hex 16 2>/dev/null || echo "fallback_enc_key!")

cat > "$INSTALL_DIR/.env" << ENVEOF
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
REDIS_URL=redis://redis:6379
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRE_HOURS=720
ENCRYPTION_KEY=${ENCRYPTION_KEY}
ADMIN_USERNAME=admin
ADMIN_PASSWORD=${POSTGRES_PASSWORD}
BOT_TOKEN=${BOT_TOKEN}
ADMIN_IDS=123456789
API_ID=${API_ID}
API_HASH=${API_HASH}
CHECK_INTERVAL_MINUTES=30
LOG_LEVEL=INFO
REACT_APP_API_URL=http://${SERVER_IP}/api
BACKUP_BOT_TOKEN=${BOT_TOKEN}
BACKUP_CHAT_ID=-1001234567890
BACKUP_INTERVAL_HOURS=1
USDT_TRC20_WALLET=YOUR_USDT_TRC20_ADDRESS
TON_WALLET=YOUR_TON_WALLET_ADDRESS
TRX_WALLET=YOUR_TRX_WALLET_ADDRESS
DOMAIN=${SERVER_IP}
ENVEOF
log ".env ساخته شد"

echo ""
echo "[6/6] Build و راه‌اهدازی Docker..."
cd "$INSTALL_DIR"
docker compose down --remove-orphans 2>/dev/null || true
info "Build در ؖال انجام است (چڪ دقیفه شقوکم می‌کنج)..."
docker compose build --no-cache 2>&1 | grep -E "Step|Successfully|error|Error|=>|DONE|ERROR" || true
log "Build کمله شد"
info "راه‌اهدازی سرویس‌ها..."
docker compose up -d
sleep 10

echo ""
echo "وضمویت سرویس‌ها:"
docker compose ps

echo ""
info "تست API..."
for i in 1 2 3 4 5 6; do
    if curl -sf "http://localhost:8000/api/health" &>/dev/null; then
        log "API آنلاین!"
        break
    fi
    [ $i -eq 6 ] && warn "API هنو֚ در چڪ راه‌اهدازی"
    sleep 5
done

echo ""
echo "=================================================="
echo "  نصب کامل شد!"
echo "  سیت:  http://${SERVER_IP}"
echo "  API:   http://${SERVER_IP}/api/health"
echo "  مشان:"
echo "    cd ${INSTALL_DIR} && docker compose logs -f"
echo "==================================================="
echo ""
echo "ADMIN_IDS را دز n.env با ایدی تلٯرام خودت ظماغ ظماغ ظماغ"
echo ""
