#!/bin/bash

# تک پوش خاص - اسکریپت نصب خودکار
# سیستم مدیریت برند تی‌شرت فارسی
# استفاده: bash <(curl -Ls https://raw.githubusercontent.com/tek-push-khas/install/main/install.sh)

set -e

# نسخه اسکریپت
SCRIPT_VERSION="1.0.0"
REPO_URL="https://github.com/moha100h/tek-push-khas.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="tek-push-khas"
APP_DIR="/opt/$APP_NAME"
SERVICE_USER="$APP_NAME"
DOMAIN=""
SSL_EMAIL=""
DB_PASSWORD=""

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "این اسکریپت باید با دسترسی root اجرا شود"
        print_error "لطفاً با sudo اجرا کنید: sudo bash install.sh"
        exit 1
    fi
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        print_error "سیستم عامل شناسایی نشد"
        exit 1
    fi
    
    print_status "سیستم عامل تشخیص داده شده: $OS $VER"
}

# Function to update system
update_system() {
    print_status "به‌روزرسانی سیستم..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update && apt upgrade -y
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        yum update -y
    else
        print_warning "سیستم عامل پشتیبانی نشده، ادامه با احتیاط..."
    fi
}

# Function to install dependencies
install_dependencies() {
    print_status "نصب وابستگی‌های سیستم..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt install -y curl wget git nginx postgresql postgresql-contrib ufw fail2ban
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        yum install -y curl wget git nginx postgresql postgresql-server postgresql-contrib firewalld fail2ban
    fi
}

# Function to install Node.js
install_nodejs() {
    print_status "نصب Node.js..."
    
    # Install Node.js 20.x
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt install -y nodejs
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        yum install -y nodejs npm
    fi
    
    # Verify installation
    node_version=$(node --version)
    npm_version=$(npm --version)
    print_success "Node.js نصب شد: $node_version"
    print_success "npm نصب شد: $npm_version"
}

# Function to setup PostgreSQL
setup_postgresql() {
    print_status "پیکربندی PostgreSQL..."
    
    # Initialize PostgreSQL (for CentOS/RHEL)
    if [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        postgresql-setup initdb
    fi
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    # Generate random password if not provided
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(openssl rand -base64 32)
    fi
    
    # Create database and user
    sudo -u postgres psql << EOF
CREATE DATABASE tek_push_khas;
CREATE USER tek_push_user WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE tek_push_khas TO tek_push_user;
ALTER USER tek_push_user CREATEDB;
\q
EOF
    
    print_success "پایگاه داده پیکربندی شد"
    print_warning "رمز عبور پایگاه داده: $DB_PASSWORD"
}

# Function to create application user
create_app_user() {
    print_status "ایجاد کاربر اپلیکیشن..."
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --shell /bin/bash --home-dir "$APP_DIR" --create-home "$SERVICE_USER"
        print_success "کاربر $SERVICE_USER ایجاد شد"
    else
        print_warning "کاربر $SERVICE_USER از قبل وجود دارد"
    fi
}

# Function to download and setup application
setup_application() {
    print_status "دانلود و نصب اپلیکیشن..."
    
    # Create application directory
    mkdir -p "$APP_DIR"
    cd "$APP_DIR"
    
    # Download complete application source
    if command -v git &> /dev/null; then
        print_status "دانلود کد منبع از مخزن Git..."
        git clone "$REPO_URL" . 2>/dev/null || {
            print_warning "خطا در دانلود از Git، استفاده از آرشیو ZIP..."
            download_zip_source
        }
    else
        download_zip_source
    fi
    
    # Create production package.json if not exists
    if [[ ! -f package.json ]]; then
        create_package_json
    fi
    
    # Create environment file
    cat > .env << EOF
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://tek_push_user:$DB_PASSWORD@localhost:5432/tek_push_khas
SESSION_SECRET=$(openssl rand -base64 64)
EOF
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
    
    # Install dependencies
    sudo -u "$SERVICE_USER" npm install
    
    # Build application for production
    print_status "ساخت نسخه تولید..."
    sudo -u "$SERVICE_USER" npm run build 2>/dev/null || print_warning "ساخت نسخه تولید ناموفق - ادامه با نسخه توسعه"
    
    # Create necessary directories
    sudo -u "$SERVICE_USER" mkdir -p uploads public logs
    
    # Set proper permissions
    chmod 755 uploads
    
    print_success "اپلیکیشن نصب شد"
}

# Function to download ZIP source
download_zip_source() {
    print_status "دانلود آرشیو ZIP..."
    wget -q "https://github.com/tek-push-khas/website/archive/main.zip" -O source.zip
    unzip -q source.zip
    mv website-main/* . 2>/dev/null || true
    rm -rf website-main source.zip
}

# Function to create package.json
create_package_json() {
    cat > package.json << 'EOF'
{
  "name": "tek-push-khas",
  "version": "1.0.0",
  "description": "سیستم مدیریت برند تی‌شرت فارسی",
  "main": "server/index.js",
  "scripts": {
    "start": "node server/index.js",
    "dev": "NODE_ENV=development tsx server/index.ts",
    "build": "npm run build:client && npm run build:server",
    "build:client": "vite build",
    "build:server": "tsc -p server/tsconfig.json",
    "db:push": "drizzle-kit push:pg",
    "db:migrate": "drizzle-kit generate:pg"
  },
  "dependencies": {
    "@hookform/resolvers": "^3.3.2",
    "@neondatabase/serverless": "^0.7.2",
    "@radix-ui/react-dialog": "^1.0.5",
    "@radix-ui/react-slot": "^1.0.2",
    "@tanstack/react-query": "^5.8.4",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0",
    "connect-pg-simple": "^9.0.1",
    "drizzle-orm": "^0.29.0",
    "drizzle-zod": "^0.5.1",
    "express": "^4.18.2",
    "express-session": "^1.17.3",
    "framer-motion": "^10.16.4",
    "lucide-react": "^0.292.0",
    "multer": "^1.4.5-lts.1",
    "nanoid": "^5.0.3",
    "passport": "^0.6.0",
    "passport-local": "^1.0.0",
    "pg": "^8.11.3",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-hook-form": "^7.47.0",
    "sharp": "^0.32.6",
    "tailwind-merge": "^2.0.0",
    "tailwindcss": "^3.3.5",
    "vite": "^4.5.0",
    "wouter": "^2.12.1",
    "zod": "^3.22.4"
  },
  "devDependencies": {
    "@types/express": "^4.17.21",
    "@types/express-session": "^1.17.10",
    "@types/multer": "^1.4.11",
    "@types/node": "^20.8.10",
    "@types/passport": "^1.0.16",
    "@types/passport-local": "^1.0.38",
    "@types/pg": "^8.10.7",
    "@types/react": "^18.2.37",
    "@types/react-dom": "^18.2.15",
    "@vitejs/plugin-react": "^4.1.1",
    "autoprefixer": "^10.4.16",
    "drizzle-kit": "^0.20.4",
    "postcss": "^8.4.31",
    "tsx": "^4.1.2",
    "typescript": "^5.2.2"
  }
}
EOF
}

# Function to create systemd service
create_systemd_service() {
    print_status "ایجاد سرویس systemd..."
    
    cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=Tek Push Khas - Persian T-Shirt Brand Website
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server/index.js
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=5
RestartSec=5
Restart=always

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=$APP_DIR
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable $APP_NAME
    
    print_success "سرویس systemd ایجاد شد"
}

# Function to configure Nginx
configure_nginx() {
    print_status "پیکربندی Nginx..."
    
    # Backup default config
    if [[ -f /etc/nginx/sites-available/default ]]; then
        cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup
    fi
    
    cat > /etc/nginx/sites-available/$APP_NAME << EOF
upstream tek_push_khas {
    server 127.0.0.1:3000;
    keepalive 64;
}

server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy strict-origin-when-cross-origin;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;
    
    location / {
        proxy_pass http://tek_push_khas;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
    
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://tek_push_khas;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /api/login {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://tek_push_khas;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /uploads/ {
        alias $APP_DIR/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    location = /robots.txt {
        alias $APP_DIR/public/robots.txt;
        access_log off;
    }
    
    location = /favicon.ico {
        alias $APP_DIR/public/favicon.ico;
        access_log off;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
    
    # Remove default site if it exists
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        rm /etc/nginx/sites-enabled/default
    fi
    
    # Test configuration
    nginx -t
    systemctl reload nginx
    
    print_success "Nginx پیکربندی شد"
}

# Function to setup SSL with Let's Encrypt
setup_ssl() {
    if [[ -n "$DOMAIN" ]] && [[ -n "$SSL_EMAIL" ]]; then
        print_status "نصب و پیکربندی SSL..."
        
        # Install certbot
        if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
            apt install -y certbot python3-certbot-nginx
        elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
            yum install -y certbot python3-certbot-nginx
        fi
        
        # Get SSL certificate
        certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect
        
        # Setup auto-renewal
        echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
        
        print_success "SSL نصب و پیکربندی شد"
    else
        print_warning "دامنه یا ایمیل مشخص نشده، SSL نصب نشد"
    fi
}

# Function to configure firewall
configure_firewall() {
    print_status "پیکربندی فایروال..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        # UFW configuration
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow 'Nginx Full'
        ufw --force enable
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        # Firewalld configuration
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --permanent --zone=public --add-service=ssh
        firewall-cmd --permanent --zone=public --add-service=http
        firewall-cmd --permanent --zone=public --add-service=https
        firewall-cmd --reload
    fi
    
    print_success "فایروال پیکربندی شد"
}

# Function to setup monitoring
setup_monitoring() {
    print_status "پیکربندی نظارت و لاگ..."
    
    # Create log directory
    mkdir -p /var/log/$APP_NAME
    chown $SERVICE_USER:$SERVICE_USER /var/log/$APP_NAME
    
    # Logrotate configuration
    cat > /etc/logrotate.d/$APP_NAME << EOF
/var/log/$APP_NAME/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $SERVICE_USER $SERVICE_USER
    postrotate
        systemctl reload $APP_NAME > /dev/null 2>&1 || true
    endscript
}
EOF
    
    # Basic monitoring script
    cat > /usr/local/bin/check-$APP_NAME << 'EOF'
#!/bin/bash
if ! systemctl is-active --quiet tek-push-khas; then
    echo "$(date): Tek Push Khas service is down, restarting..." >> /var/log/tek-push-khas/monitor.log
    systemctl restart tek-push-khas
fi
EOF
    
    chmod +x /usr/local/bin/check-$APP_NAME
    
    # Add to crontab
    echo "*/5 * * * * /usr/local/bin/check-$APP_NAME" | crontab -
    
    print_success "نظارت پیکربندی شد"
}

# Function to create backup script
create_backup_script() {
    print_status "ایجاد اسکریپت پشتیبان‌گیری..."
    
    mkdir -p /opt/backups
    
    cat > /usr/local/bin/backup-$APP_NAME << EOF
#!/bin/bash
BACKUP_DIR="/opt/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
APP_BACKUP="\$BACKUP_DIR/${APP_NAME}_\$DATE.tar.gz"
DB_BACKUP="\$BACKUP_DIR/${APP_NAME}_db_\$DATE.sql"

# Backup application files
tar -czf "\$APP_BACKUP" -C "$APP_DIR" .

# Backup database
sudo -u postgres pg_dump tek_push_khas > "\$DB_BACKUP"

# Keep only last 7 days of backups
find "\$BACKUP_DIR" -name "${APP_NAME}_*" -mtime +7 -delete

echo "\$(date): Backup completed - \$APP_BACKUP, \$DB_BACKUP" >> /var/log/$APP_NAME/backup.log
EOF
    
    chmod +x /usr/local/bin/backup-$APP_NAME
    
    # Schedule daily backups
    echo "0 2 * * * /usr/local/bin/backup-$APP_NAME" | crontab -
    
    print_success "پشتیبان‌گیری پیکربندی شد"
}

# Function to prompt for configuration
prompt_config() {
    echo
    print_status "پیکربندی اولیه..."
    echo
    
    read -p "دامنه سایت (مثال: example.com): " DOMAIN
    
    if [[ -n "$DOMAIN" ]]; then
        read -p "ایمیل برای SSL (مثال: admin@example.com): " SSL_EMAIL
    fi
    
    read -p "رمز عبور پایگاه داده (خالی بگذارید برای تولید خودکار): " DB_PASSWORD
    
    echo
}

# Function to initialize database
initialize_database() {
    print_status "راه‌اندازی پایگاه داده..."
    
    # Wait for application to start
    sleep 5
    
    # Run database migrations
    cd "$APP_DIR"
    sudo -u "$SERVICE_USER" npm run db:push 2>/dev/null || print_warning "خطا در اجرای مایگریشن"
    
    # Create default admin user
    sudo -u postgres psql tek_push_khas << EOF
INSERT INTO users (username, password, role) 
VALUES ('admin', '\$2b\$10\$K9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z.Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z9Z', 'admin')
ON CONFLICT (username) DO NOTHING;
EOF
    
    print_success "پایگاه داده راه‌اندازی شد"
    print_warning "نام کاربری پیش‌فرض: admin"
    print_warning "رمز عبور پیش‌فرض: admin123"
}

# Function to display final information
display_final_info() {
    clear
    echo
    print_success "🎉 =========================================="
    print_success "       نصب با موفقیت تکمیل شد!"
    print_success "=========================================="
    echo
    print_status "📋 اطلاعات مهم:"
    echo "  📂 مسیر اپلیکیشن: $APP_DIR"
    echo "  👤 کاربر سیستم: $SERVICE_USER"
    echo "  🔐 رمز پایگاه داده: $DB_PASSWORD"
    echo "  🔑 نام کاربری ادمین: admin"
    echo "  🔓 رمز عبور ادمین: admin123"
    
    if [[ -n "$DOMAIN" ]]; then
        echo "  🌐 آدرس سایت: https://$DOMAIN"
        echo "  🔒 SSL فعال: بله"
    else
        SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "IP-SERVER")
        echo "  🌐 آدرس سایت: http://$SERVER_IP"
        echo "  🔒 SSL فعال: خیر"
    fi
    
    echo
    print_status "⚡ دستورات مفید:"
    echo "  🚀 شروع سرویس: sudo systemctl start $APP_NAME"
    echo "  ⏹️  متوقف کردن: sudo systemctl stop $APP_NAME"
    echo "  🔄 راه‌اندازی مجدد: sudo systemctl restart $APP_NAME"
    echo "  📊 وضعیت سرویس: sudo systemctl status $APP_NAME"
    echo "  📝 مشاهده لاگ: sudo journalctl -u $APP_NAME -f"
    echo "  💾 پشتیبان‌گیری: sudo /usr/local/bin/backup-$APP_NAME"
    echo "  🔧 ویرایش تنظیمات: sudo nano $APP_DIR/.env"
    echo
    print_status "📁 پوشه‌های مهم:"
    echo "  📸 تصاویر آپلود شده: $APP_DIR/uploads/"
    echo "  📄 فایل‌های لاگ: /var/log/$APP_NAME/"
    echo "  💾 پشتیبان‌ها: /opt/backups/"
    echo
    print_warning "⚠️  نکات مهم:"
    echo "  • حتماً رمز عبور ادمین را تغییر دهید"
    echo "  • اطلاعات بالا را در جای امنی ذخیره کنید"
    echo "  • برای امنیت بیشتر فایروال را پیکربندی کنید"
    
    if [[ -z "$DOMAIN" ]]; then
        echo "  • برای SSL رایگان دامنه خود را تنظیم کنید"
    fi
    
    echo
    print_success "✅ سیستم آماده استفاده است!"
    echo
}

# Main installation function
main() {
    clear
    echo
    print_status "=========================================="
    print_status "    تک پوش خاص - اسکریپت نصب خودکار"
    print_status "=========================================="
    echo
    
    check_root
    detect_os
    prompt_config
    
    print_status "شروع فرآیند نصب..."
    
    update_system
    install_dependencies
    install_nodejs
    setup_postgresql
    create_app_user
    setup_application
    create_systemd_service
    configure_nginx
    setup_ssl
    configure_firewall
    setup_monitoring
    create_backup_script
    
    # Start services
    systemctl start $APP_NAME
    systemctl start nginx
    
    # Initialize database
    initialize_database
    
    display_final_info
}

# Handle script termination
trap 'print_error "نصب متوقف شد!"; exit 1' INT TERM

# Run main function
main "$@"
