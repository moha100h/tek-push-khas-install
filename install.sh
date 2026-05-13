#!/bin/bash
set -e

echo ""
echo "================================================"
echo "   نصب سیستم Session Manager"
echo "================================================"
echo ""

# ── ۱. آپدیت سیستم ──────────────────────────────
echo "[1/9] آپدیت سیستم..."
apt update -y && apt upgrade -y
apt install -y git curl nginx python3 python3-pip postgresql postgresql-contrib redis-server ufw
echo "✅ سیستم آپدیت شد"

# ── ۲. Node.js 20 ────────────────────────────────
echo "[2/9] نصب Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g pm2
echo "✅ Node.js $(node -v) نصب شد"

# ── ۳. PostgreSQL ────────────────────────────────
echo "[3/9] تنظیم دیتابیس..."
systemctl start postgresql
systemctl enable postgresql
sudo -u postgres psql -c "CREATE USER tisadmin WITH PASSWORD 'SN662499\$rr';" 2>/dev/null || echo "یوزر قبلاً وجود داشت"
sudo -u postgres psql -c "CREATE DATABASE tisdata OWNER tisadmin;" 2>/dev/null || echo "دیتابیس قبلاً وجود داشت"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE tisdata TO tisadmin;"
echo "✅ دیتابیس آماده شد"

# ── ۴. Redis ─────────────────────────────────────
echo "[4/9] راه‌اندازی Redis..."
systemctl start redis-server
systemctl enable redis-server
echo "✅ Redis آماده شد"

# ── ۵. کلون پروژه ────────────────────────────────
echo "[5/9] دانلود پروژه..."
mkdir -p /var/www
cd /var/www
rm -rf session-manager
git clone https://github.com/moha100h/session-manager.git 2>/dev/null || {
  echo "⚠️  ریپو session-manager پیدا نشد — پوشه خالی می‌سازم"
  mkdir -p session-manager
}
cd session-manager
echo "✅ پروژه دانلود شد"

# ── ۶. فایل .env ─────────────────────────────────
echo "[6/9] ساخت فایل .env..."
cat > /var/www/session-manager/.env << 'ENVEOF'
BOT_TOKEN=8857350914:AAEovAJjOjLIKVQW7ocSDaX5zEE0sTu_F4Q
API_ID=32351310
API_HASH=9b4e6a3d9fa116dccef9a20c3c961840
DATABASE_URL=postgresql://tisadmin:SN662499$rr@localhost/tisdata
REDIS_URL=redis://localhost:6379
HOST=0.0.0.0
PORT=8000
ENVEOF
echo "✅ فایل .env ساخته شد"

# ── ۷. نصب وابستگی‌ها ────────────────────────────
echo "[7/9] نصب وابستگی‌ها..."
cd /var/www/session-manager

if [ -f package.json ]; then
  npm install
  echo "✅ Node packages نصب شد"
fi

if [ -f requirements.txt ]; then
  pip3 install -r requirements.txt
  echo "✅ Python packages نصب شد"
fi

if [ -d frontend ]; then
  cd frontend
  npm install
  npm run build
  cd ..
  echo "✅ Frontend build شد"
fi

# ── ۸. PM2 ───────────────────────────────────────
echo "[8/9] راه‌اندازی سرویس‌ها..."
pm2 delete all 2>/dev/null || true

if [ -f bot/index.js ]; then
  pm2 start bot/index.js --name session-bot
fi

if [ -f main.py ]; then
  pm2 start "uvicorn main:app --host 127.0.0.1 --port 8000" --name session-api --interpreter none
fi

pm2 save
env PATH=$PATH:/usr/bin pm2 startup systemd -u root --hp /root | tail -1 | bash || true
echo "✅ PM2 راه‌اندازی شد"

# ── ۹. Nginx ─────────────────────────────────────
echo "[9/9] تنظیم Nginx..."
cat > /etc/nginx/sites-available/session-manager << 'NGINXEOF'
server {
    listen 80;
    server_name 2.58.172.164;

    location / {
        root /var/www/session-manager/frontend/dist;
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache";
    }

    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /ws/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    access_log /var/log/nginx/session-manager.access.log;
    error_log  /var/log/nginx/session-manager.error.log;
}
NGINXEOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/session-manager /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
echo "✅ Nginx تنظیم شد"

# ── فایروال ──────────────────────────────────────
ufw allow 9011/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# ── نتیجه نهایی ──────────────────────────────────
echo ""
echo "================================================"
echo "   ✅ نصب کامل شد!"
echo "================================================"
echo ""
echo "🌐 آدرس سایت: http://2.58.172.164"
echo ""
echo "📊 وضعیت سرویس‌ها:"
pm2 status
echo ""
echo "🔍 تست سریع:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost || echo "Nginx در حال اجرا"
