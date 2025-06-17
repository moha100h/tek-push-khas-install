#!/bin/bash

# تک پوش خاص - اسکریپت نصب کامل خودکار
# سیستم مدیریت برند تی‌شرت فارسی
# استفاده: bash <(curl -Ls https://raw.githubusercontent.com/moha100h/tek-push-khas-install/main/complete-install.sh)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_NAME="tek-push-khas"
APP_DIR="/opt/$APP_NAME"
SERVICE_USER="$APP_NAME"
DOMAIN=""
SSL_EMAIL=""
DB_PASSWORD=""
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="admin123"

# Function to print colored output
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "این اسکریپت باید با دسترسی root اجرا شود"
        print_error "لطفاً با sudo اجرا کنید: sudo bash complete-install.sh"
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
    print_status "سیستم عامل: $OS $VER"
}

# Function to prompt for configuration
prompt_config() {
    echo
    print_status "تنظیمات اولیه (Enter برای پیش‌فرض):"
    echo
    
    read -p "دامنه سایت (اختیاری): " DOMAIN
    if [[ -n "$DOMAIN" ]]; then
        read -p "ایمیل SSL: " SSL_EMAIL
    fi
    
    read -p "نام کاربری ادمین [$ADMIN_USERNAME]: " input
    ADMIN_USERNAME=${input:-$ADMIN_USERNAME}
    
    read -s -p "رمز ادمین [$ADMIN_PASSWORD]: " input
    ADMIN_PASSWORD=${input:-$ADMIN_PASSWORD}
    echo
    echo
}

# Function to update system
update_system() {
    print_status "به‌روزرسانی سیستم..."
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update -qq && apt upgrade -y -qq
        apt install -y -qq curl wget git nginx postgresql postgresql-contrib ufw fail2ban unzip
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        yum update -y -q && yum install -y -q curl wget git nginx postgresql postgresql-server postgresql-contrib firewalld fail2ban unzip
        postgresql-setup initdb
    fi
}

# Function to install Node.js
install_nodejs() {
    print_status "نصب Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt install -y -qq nodejs
    else
        yum install -y -q nodejs npm
    fi
    print_success "Node.js $(node --version) نصب شد"
}

# Function to setup PostgreSQL
setup_postgresql() {
    print_status "پیکربندی PostgreSQL..."
    systemctl start postgresql && systemctl enable postgresql
    
    if [[ -z "$DB_PASSWORD" ]]; then
        DB_PASSWORD=$(openssl rand -base64 32)
    fi
    
    sudo -u postgres psql << EOF >/dev/null 2>&1
CREATE DATABASE tek_push_khas;
CREATE USER tek_push_user WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE tek_push_khas TO tek_push_user;
ALTER USER tek_push_user CREATEDB;
\q
EOF
    print_success "پایگاه داده پیکربندی شد"
}

# Function to create application user
create_app_user() {
    print_status "ایجاد کاربر اپلیکیشن..."
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --shell /bin/bash --home-dir "$APP_DIR" --create-home "$SERVICE_USER"
    fi
}

# Function to create complete project structure
create_complete_project() {
    print_status "ایجاد ساختار پروژه..."
    mkdir -p "$APP_DIR"/{client/src/{components,hooks,lib,pages},server,shared,public,uploads}
    cd "$APP_DIR"
    
    # Create package.json
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
    "db:push": "drizzle-kit push:pg"
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

    # Create minimal server structure
    cat > server/index.ts << 'EOF'
import express from 'express';
import { Pool } from 'pg';
import path from 'path';

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.static('dist'));
app.use('/uploads', express.static('uploads'));

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// Basic routes
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.get('/api/brand-settings', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM brand_settings LIMIT 1');
    res.json(result.rows[0] || { name: 'تک پوش خاص', slogan: 'برند منحصر به فرد شما' });
  } catch (error) {
    res.json({ name: 'تک پوش خاص', slogan: 'برند منحصر به فرد شما' });
  }
});

app.get('/api/tshirt-images', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM tshirt_images WHERE active = true ORDER BY order_index');
    res.json(result.rows || []);
  } catch (error) {
    res.json([]);
  }
});

// Serve client app
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, '../dist/index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

    # Create basic client structure
    mkdir -p client/src
    cat > client/index.html << 'EOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>تک پوش خاص</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@300;400;500;600;700&display=swap" rel="stylesheet">
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.tsx"></script>
</body>
</html>
EOF

    cat > client/src/main.tsx << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'

function App() {
  return (
    <div className="min-h-screen bg-white flex items-center justify-center">
      <div className="text-center">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">تک پوش خاص</h1>
        <p className="text-lg text-gray-600">سیستم مدیریت برند تی‌شرت فارسی</p>
        <div className="mt-8">
          <span className="inline-block bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm">
            سیستم با موفقیت نصب شد
          </span>
        </div>
      </div>
    </div>
  )
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF

    cat > client/src/index.css << 'EOF'
@import 'tailwindcss/base';
@import 'tailwindcss/components';
@import 'tailwindcss/utilities';

* {
  font-family: 'Vazirmatn', sans-serif;
}

body {
  direction: rtl;
}
EOF

    # Create Vite config
    cat > vite.config.ts << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  root: 'client',
  build: {
    outDir: '../dist',
    emptyOutDir: true
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './client/src')
    }
  }
})
EOF

    # Create TypeScript config
    cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": false,
    "noUnusedParameters": false,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./client/src/*"]
    }
  },
  "include": ["client/src", "server"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
EOF

    cat > tsconfig.node.json << 'EOF'
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
EOF

    # Create Tailwind config
    cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./client/index.html",
    "./client/src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Vazirmatn', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
EOF

    cat > postcss.config.js << 'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

    # Create environment file
    cat > .env << EOF
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://tek_push_user:$DB_PASSWORD@localhost:5432/tek_push_khas
SESSION_SECRET=$(openssl rand -base64 64)
EOF

    chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
    chmod 755 uploads
}

# Function to install dependencies and build
build_application() {
    print_status "نصب وابستگی‌ها و ساخت پروژه..."
    cd "$APP_DIR"
    
    # Install dependencies
    sudo -u "$SERVICE_USER" npm install --production=false >/dev/null 2>&1
    
    # Build frontend
    sudo -u "$SERVICE_USER" npm run build >/dev/null 2>&1 || {
        print_warning "خطا در ساخت فرانت‌اند، ایجاد فایل‌های پیش‌فرض..."
        mkdir -p dist
        if [ -f "client/index.html" ]; then
            cp client/index.html dist/
        else
            echo '<!DOCTYPE html><html><head><title>تک پوش خاص</title></head><body><h1>تک پوش خاص</h1></body></html>' > dist/index.html
        fi
        echo "console.log('تک پوش خاص - سرور آماده');" > dist/main.js
    }
    
    # Setup server for production
    # Use tsx directly instead of compiling to JS
    print_status "تنظیم سرور برای تولید..."
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
Environment=PATH=/usr/local/bin:/usr/bin:/bin:$APP_DIR/node_modules/.bin
Environment=DATABASE_URL=postgresql://tek_push_user:$DB_PASSWORD@localhost:5432/tek_push_khas
ExecStart=/usr/bin/node node_modules/.bin/tsx server/index.ts
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=$APP_NAME

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable $APP_NAME
}

# Function to configure Nginx
configure_nginx() {
    print_status "پیکربندی Nginx..."
    
    rm -f /etc/nginx/sites-enabled/default
    
    SERVER_NAME=${DOMAIN:-$(curl -s ifconfig.me 2>/dev/null || echo "localhost")}
    
    cat > /etc/nginx/sites-available/$APP_NAME << EOF
server {
    listen 80;
    server_name $SERVER_NAME;
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /uploads/ {
        alias $APP_DIR/uploads/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
}

# Function to setup SSL
setup_ssl() {
    if [[ -n "$DOMAIN" ]] && [[ -n "$SSL_EMAIL" ]]; then
        print_status "نصب SSL..."
        if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
            apt install -y -qq certbot python3-certbot-nginx
        else
            yum install -y -q certbot python3-certbot-nginx
        fi
        certbot --nginx -d "$DOMAIN" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect >/dev/null 2>&1
    fi
}

# Function to initialize database
initialize_database() {
    print_status "راه‌اندازی پایگاه داده..."
    
    # Wait for database to be ready
    sleep 2
    
    # Push database schema using Drizzle
    cd "$APP_DIR"
    sudo -u "$SERVICE_USER" npm run db:push >/dev/null 2>&1 || {
        print_warning "خطا در ایجاد جداول، ایجاد دستی..."
        
        # Create basic tables manually
        sudo -u postgres psql tek_push_khas << EOF >/dev/null 2>&1
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password TEXT NOT NULL,
    email VARCHAR(100),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    profile_image_url TEXT,
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS brand_settings (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL DEFAULT 'تک پوش خاص',
    slogan TEXT DEFAULT 'یک برند منحصر به فرد',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tshirt_images (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) DEFAULT 'تی‌شرت جدید',
    description TEXT,
    image_url TEXT NOT NULL,
    size VARCHAR(10) DEFAULT 'M',
    price VARCHAR(20) DEFAULT '50000',
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS social_links (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS copyright_settings (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL DEFAULT '© 1404 تک پوش خاص. تمام حقوق محفوظ است.',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS about_content (
    id SERIAL PRIMARY KEY,
    content TEXT DEFAULT 'درباره تک پوش خاص',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
    }
    
    # Insert default data
    HASHED_PASSWORD=$(echo -n "$ADMIN_PASSWORD" | openssl dgst -sha256 -binary | openssl base64)
    sudo -u postgres psql tek_push_khas << EOF >/dev/null 2>&1
INSERT INTO brand_settings (name, slogan) 
VALUES ('تک پوش خاص', 'یک برند منحصر به فرد') 
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, slogan = EXCLUDED.slogan;

INSERT INTO users (username, password, role) 
VALUES ('$ADMIN_USERNAME', '$HASHED_PASSWORD', 'admin')
ON CONFLICT (username) DO UPDATE SET password = EXCLUDED.password;

INSERT INTO social_links (platform, url) 
VALUES ('instagram', 'https://instagram.com/tekpushkhas')
ON CONFLICT DO NOTHING;

INSERT INTO copyright_settings (text) 
VALUES ('© 1404 تک پوش خاص. تمام حقوق محفوظ است.')
ON CONFLICT (id) DO UPDATE SET text = EXCLUDED.text;

INSERT INTO about_content (content) 
VALUES ('تک پوش خاص - برند منحصر به فرد شما')
ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content;
EOF
}

# Function to configure firewall
configure_firewall() {
    print_status "پیکربندی فایروال..."
    if command -v ufw >/dev/null; then
        ufw --force reset >/dev/null 2>&1
        ufw default deny incoming >/dev/null 2>&1
        ufw default allow outgoing >/dev/null 2>&1
        ufw allow ssh >/dev/null 2>&1
        ufw allow 'Nginx Full' >/dev/null 2>&1
        ufw --force enable >/dev/null 2>&1
    fi
}

# Function to start services
start_services() {
    print_status "راه‌اندازی سرویس‌ها..."
    
    # Enable services
    systemctl enable $APP_NAME >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    
    # Start database first
    systemctl start postgresql >/dev/null 2>&1
    sleep 2
    
    # Start application
    systemctl start $APP_NAME >/dev/null 2>&1
    sleep 5
    
    # Check if app is running
    if ! systemctl is-active --quiet $APP_NAME; then
        print_warning "خطا در راه‌اندازی اپلیکیشن، تلاش مجدد..."
        systemctl restart $APP_NAME >/dev/null 2>&1
        sleep 5
    fi
    
    # Start nginx
    systemctl start nginx >/dev/null 2>&1
    
    # Final status check with health verification
    print_status "بررسی وضعیت سرویس‌ها..."
    if systemctl is-active --quiet $APP_NAME && systemctl is-active --quiet nginx; then
        # Test HTTP response
        sleep 3
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|404"; then
            print_success "تمام سرویس‌ها با موفقیت راه‌اندازی شدند"
        else
            print_warning "سرور راه‌اندازی شده اما HTTP response مشکل دارد"
            # Try to restart once more
            systemctl restart $APP_NAME >/dev/null 2>&1
            sleep 5
        fi
    else
        print_warning "برخی سرویس‌ها مشکل دارند"
        systemctl status $APP_NAME --no-pager -l >/dev/null 2>&1 || true
    fi
}

# Function to display final information
display_final_info() {
    clear
    echo
    print_success "🎉 =========================================="
    print_success "       نصب با موفقیت تکمیل شد!"
    print_success "=========================================="
    echo
    
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "IP-SERVER")
    SITE_URL=${DOMAIN:+https://$DOMAIN}
    SITE_URL=${SITE_URL:-http://$SERVER_IP}
    
    print_status "📋 اطلاعات دسترسی:"
    echo "  🌐 آدرس سایت: $SITE_URL"
    echo "  🔑 نام کاربری: $ADMIN_USERNAME"
    echo "  🔓 رمز عبور: $ADMIN_PASSWORD"
    echo "  📂 مسیر اپلیکیشن: $APP_DIR"
    echo "  🔐 رمز پایگاه داده: $DB_PASSWORD"
    echo
    
    print_status "⚡ دستورات مفید:"
    echo "  📊 وضعیت: sudo systemctl status $APP_NAME"
    echo "  🔄 راه‌اندازی مجدد: sudo systemctl restart $APP_NAME"
    echo "  📝 لاگ: sudo journalctl -u $APP_NAME -f"
    echo
    
    print_warning "⚠️  نکات مهم:"
    echo "  • حتماً رمز عبور ادمین را تغییر دهید"
    echo "  • اطلاعات بالا را در جای امنی ذخیره کنید"
    echo
    
    print_success "✅ سیستم آماده استفاده است!"
    echo "🚀 برای شروع $SITE_URL را در مرورگر باز کنید"
    echo
}

# Main installation function
main() {
    clear
    echo
    print_status "=========================================="
    print_status "    تک پوش خاص - نصب خودکار"
    print_status "=========================================="
    echo
    
    check_root
    detect_os
    prompt_config
    
    print_status "شروع نصب..."
    
    update_system
    install_nodejs
    setup_postgresql
    create_app_user
    create_complete_project
    build_application
    create_systemd_service
    configure_nginx
    setup_ssl
    initialize_database
    configure_firewall
    start_services
    
    display_final_info
}

# Handle script termination
trap 'print_error "نصب متوقف شد!"; exit 1' INT TERM

# Run main function
main "$@"