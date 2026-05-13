#!/bin/bash
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()    { echo -e "${GREEN}[✔]${NC} $1"; }
warn()   { echo -e "${YELLOW}[⚠]${NC} $1"; }
error()  { echo -e "${RED}[✘]${NC} $1"; exit 1; }
info()   { echo -e "${CYAN}[➤]${NC} $1"; }
header() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}\n"; }

BOT_TOKEN="8857350914:AAEovAJjOjLIKVQW7ocSDaX5zEE0sTu_F4Q"
API_ID="32351310"
API_HASH="9b4e6a3d9fa116dccef9a20c3c961840"
POSTGRES_DB="tisdata"
POSTGRES_USER="tisadmin"
POSTGRES_PASSWORD='SN662499$rr'
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
INSTALL_DIR="/var/www/session-manager-pro"
REPO_URL="https://github.com/moha100h/session-manager-pro.git"

check_root() { [[ $EUID -ne 0 ]] && error "با root اجرا کن: sudo bash install.sh"; }

wait_for_docker_healthy() {
    local container=$1 max=60 count=0
    info "منتظر $container ..."
    while true; do
        status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "missing")
        [[ "$status" == "healthy" ]] && { log "$container سالم است"; return 0; }
        [[ "$status" == "missing" ]] && { warn "$container بدون healthcheck"; return 0; }
        sleep 2; count=$((count+1))
        [[ $count -ge $max ]] && { warn "$container timeout"; return 0; }
    done
}

check_root

header "مرحله ۱/۶ - آپدیت سیستم"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -q
apt-get upgrade -y -q -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt-get install -y -q curl git wget ufw ca-certificates gnupg
log "سیستم آپدیت شد"

header "مرحله ۲/۶ - نصب Docker"
if ! command -v docker &>/dev/null; then
    info "نصب Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    sleep 3
fi
log "Docker: $(docker --version)"

header "مرحله ۳/۶ - دریافت پروژه"
mkdir -p /var/www
if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "پروژه موجود است - آپدیت..."
    cd "$INSTALL_DIR" && git pull origin main || warn "git pull ناموفق"
else
    rm -rf "$INSTALL_DIR"
    info "کمون پروژه..."
    git clone "$REPO_URL" "$INSTALL_DIR" || error "کمون ناموفق - ریپو را چک کنید"
fi
cd "$INSTALL_DIR"
log "پروژه آماده: $INSTALL_DIR"

header "مرحله ۴/۶ - ساخت .env"
JWT_SECRET=$(openssl rand -hex 32)
ENCRYPTION_KEY=$(openssl rand -hex 16)
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
log ".env Yاخت شد"

header "مرحله ص/ٶ - فيروال"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
log "فیر؈ال: 22, 80, 443"

header "مرحله ض/ٶ - Build وراهاندازی"
cd "$INSTALL_DIR"
docker compose down --remove-orphans 2>/dev/null || true
info "Build دز Xام انجام است (چڪ دقیفه شقوکم می‌کنج)..."
docker compose build --no-cache 2>&1 | grep -E "Step|Successfully|error|Error|=>|DONE" || true
log "Build کمله شد"
docker compose up -d
sleep 8

wait_for_docker_healthy "smp_postgres"
wait_for_docker_healthy "smp_redis"
wait_for_docker_healthy "smp_api"

echo ""
echo "وضمیت سرویس‌هإ:"
docker compose ps
echo ""

for i in 1 2 3 4 5; do
    if curl -sf "http://localhost:8000/api/health" &>/dev/null; then
        log "API آنلاین ✔"
        break
    fi
    [[ $i -eq 5 ]] && warn "API هنوؚ در چڪ راه —چڪ مشان شودی"
    sleep 6
done

if curl -sf "http://localhost" &>/dev/null; then
    log "پروژه آنصلاین ✔"
else
    warn "پروژه هنو֚ در چڪ راه —چڪ مشان شودی"
fi

echo -e "\n${GREEN}╓║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║║╕�{NC}"
echo -e "${GREEN}║      نصب ba موفقیت انخام شد! ✅        ║${NC}"
echo -e "${GREEN}╕╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╓╗${NC}"
echo -e "   🌖 Sیب:   ${CYAN}http://${SERVER_IP}${NC}"
echo -e "   🔊 API:    ${CYAN}http://${SERVER_IP}/api/health${NC}"
echo -e "   📁 مسرت: ${CYAN}${INSTALL_DIR}${NC}"
echo ""
echo -e "${YELLOW}⚠️  X��Gگه نصب:"
echo -e "  • ADMIN_IDS را �.env با اید تلٯرام خودت ظماغ ظماغ"
echo -e "   • ادرس کیف پرداخت در �.env تنظیم کن"
echo -e "   • برای نصا: ${CYAN}cd ${INSTALL_DIR} && docker compose logs -f${NC}"
echo ""
