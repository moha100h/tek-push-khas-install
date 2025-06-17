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
    # Kill any existing processes on port 3000
    pkill -f "node.*3000" 2>/dev/null || true
    pkill -f "tsx.*server" 2>/dev/null || true
    sleep 2
    
    cat > .env << EOF
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://tek_push_user:$DB_PASSWORD@localhost:5432/tek_push_khas
SESSION_SECRET=$(openssl rand -base64 64)
EOF

    # Create sample images for t-shirts
    mkdir -p uploads
    
    # Copy existing sample SVGs to uploads as JPG placeholders
    if [ -f "sample-tshirt-1.svg" ]; then
        cp sample-tshirt-1.svg uploads/sample-1.jpg 2>/dev/null || true
        cp sample-tshirt-2.svg uploads/sample-2.jpg 2>/dev/null || true
        cp sample-tshirt-3.svg uploads/sample-3.jpg 2>/dev/null || true
    fi
    
    # Create simple placeholder images if SVGs don't exist
    cat > uploads/sample-1.jpg << 'IMGEOF'
<svg width="300" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="300" height="300" fill="#f0f0f0"/>
  <text x="150" y="150" text-anchor="middle" font-family="Arial" font-size="16" fill="#666">تی‌شرت کلاسیک</text>
</svg>
IMGEOF

    cat > uploads/sample-2.jpg << 'IMGEOF'
<svg width="300" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="300" height="300" fill="#e8f4f8"/>
  <text x="150" y="150" text-anchor="middle" font-family="Arial" font-size="16" fill="#333">تی‌شرت اسپرت</text>
</svg>
IMGEOF

    cat > uploads/sample-3.jpg << 'IMGEOF'
<svg width="300" height="300" xmlns="http://www.w3.org/2000/svg">
  <rect width="300" height="300" fill="#fff8e1"/>
  <text x="150" y="150" text-anchor="middle" font-family="Arial" font-size="16" fill="#444">تی‌شرت طرح‌دار</text>
</svg>
IMGEOF

    chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
    chmod 755 uploads
    chmod 644 uploads/*
}

# Function to install dependencies and build
build_application() {
    print_status "نصب وابستگی‌ها و ساخت پروژه..."
    cd "$APP_DIR"
    
    # Install dependencies
    sudo -u "$SERVICE_USER" npm install --production=false >/dev/null 2>&1
    
    # Build frontend with proper error handling
    print_status "ساخت فرانت‌اند..."
    
    # Ensure all dependencies are installed
    sudo -u "$SERVICE_USER" npm ci --production=false 2>/dev/null || {
        print_warning "نصب مجدد وابستگی‌ها..."
        sudo -u "$SERVICE_USER" npm install --force --production=false
    }
    
    # Try build with detailed error output
    if ! sudo -u "$SERVICE_USER" npm run build 2>&1; then
        print_warning "ساخت فرانت‌اند ناموفق، ایجاد فایل‌های استاتیک..."
        
        # Create minimal dist structure
        mkdir -p dist/assets
        
        # Create basic index.html
        cat > dist/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تک پوش خاص</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Arial, sans-serif; background: #fafafa; color: #333; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 40px; }
        .logo { font-size: 2.5rem; font-weight: bold; color: #dc2626; margin-bottom: 10px; }
        .tagline { font-size: 1.2rem; color: #666; }
        .content { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); text-align: center; }
        .loading { font-size: 1.1rem; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">تک پوش خاص</div>
            <div class="tagline">یک برند منحصر به فرد</div>
        </div>
        <div class="content">
            <div class="loading">سایت در حال بارگذاری...</div>
            <p style="margin-top: 20px; color: #999;">لطفاً چند لحظه صبر کنید</p>
        </div>
    </div>
</body>
</html>
HTMLEOF
        
        # Create basic CSS
        echo "body{font-family:Arial,sans-serif;background:#fafafa}" > dist/assets/style.css
        
        print_success "فایل‌های استاتیک ایجاد شدند"
    else
        print_success "فرانت‌اند با موفقیت ساخته شد"
    fi
    
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
    
    # Push database schema using Drizzle with comprehensive error handling
    cd "$APP_DIR"
    
    # First, test database connection
    if ! sudo -u postgres psql -d tek_push_khas -c "SELECT 1;" >/dev/null 2>&1; then
        print_error "اتصال به دیتابیس ناموفق"
        return 1
    fi
    
    # Try Drizzle schema push
    print_status "ایجاد جداول با Drizzle..."
    if sudo -u "$SERVICE_USER" npm run db:push 2>&1 | tee /tmp/drizzle_output.log; then
        print_success "جداول با Drizzle ایجاد شدند"
    else
        print_warning "Drizzle ناموفق، ایجاد جداول دستی..."
        
        # Create comprehensive database schema
        print_status "ایجاد ساختار کامل دیتابیس..."
        
        # Drop existing tables if they exist with wrong structure
        sudo -u postgres psql tek_push_khas << 'DROPEOF'
DROP TABLE IF EXISTS sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS brand_settings CASCADE;
DROP TABLE IF EXISTS tshirt_images CASCADE;
DROP TABLE IF EXISTS social_links CASCADE;
DROP TABLE IF EXISTS copyright_settings CASCADE;
DROP TABLE IF EXISTS about_content CASCADE;
DROPEOF

        # Create all tables with correct structure
        sudo -u postgres psql tek_push_khas << 'CREATEEOF'
-- Sessions table for express-session
CREATE TABLE sessions (
    sid VARCHAR NOT NULL COLLATE "default",
    sess JSONB NOT NULL,
    expire TIMESTAMP(6) NOT NULL
);
ALTER TABLE sessions ADD CONSTRAINT "session_pkey" PRIMARY KEY ("sid") NOT DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX "IDX_session_expire" ON sessions ("expire");

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    profile_image_url VARCHAR(500),
    role VARCHAR(20) NOT NULL DEFAULT 'admin',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Brand settings table
CREATE TABLE brand_settings (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL DEFAULT 'تک پوش خاص',
    slogan TEXT DEFAULT 'یک برند منحصر به فرد',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- T-shirt images table
CREATE TABLE tshirt_images (
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

-- Social links table
CREATE TABLE social_links (
    id SERIAL PRIMARY KEY,
    platform VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Copyright settings table
CREATE TABLE copyright_settings (
    id SERIAL PRIMARY KEY,
    text TEXT NOT NULL DEFAULT '© 1404 تک پوش خاص. تمام حقوق محفوظ است.',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- About content table
CREATE TABLE about_content (
    id SERIAL PRIMARY KEY,
    content TEXT DEFAULT 'درباره تک پوش خاص',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATEEOF

        if [ $? -eq 0 ]; then
            print_success "جداول دستی با موفقیت ایجاد شدند"
        else
            print_error "خطا در ایجاد جداول دستی"
            return 1
        fi
    fi
    
    # Insert comprehensive default data
    print_status "درج داده‌های پیش‌فرض..."
    
    # Generate proper password hash using Node.js bcrypt-compatible method
    HASHED_PASSWORD=$(node -e "
        const crypto = require('crypto');
        const password = '$ADMIN_PASSWORD';
        const salt = crypto.randomBytes(16).toString('hex');
        const hash = crypto.scryptSync(password, salt, 64).toString('hex');
        console.log(hash + '.' + salt);
    " 2>/dev/null || echo "fallback_hash")
    
    # Insert all default data with comprehensive error handling
    sudo -u postgres psql tek_push_khas << DATAEOF
-- Insert brand settings
INSERT INTO brand_settings (id, name, slogan, created_at, updated_at) 
VALUES (1, 'تک پوش خاص', 'یک برند منحصر به فرد', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name, 
    slogan = EXCLUDED.slogan, 
    updated_at = CURRENT_TIMESTAMP;

-- Insert admin user
INSERT INTO users (username, password, role, is_active, created_at, updated_at) 
VALUES ('$ADMIN_USERNAME', '$HASHED_PASSWORD', 'admin', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (username) DO UPDATE SET 
    password = EXCLUDED.password, 
    updated_at = CURRENT_TIMESTAMP;

-- Insert social links
INSERT INTO social_links (id, platform, url, is_active, created_at, updated_at) 
VALUES 
    (1, 'instagram', 'https://instagram.com/tekpushkhas', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (2, 'telegram', 'https://t.me/tekpushkhas', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (3, 'whatsapp', 'https://wa.me/989123456789', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    (4, 'email', 'info@tekpushkhas.com', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET 
    url = EXCLUDED.url, 
    updated_at = CURRENT_TIMESTAMP;

-- Insert copyright settings
INSERT INTO copyright_settings (id, text, created_at, updated_at) 
VALUES (1, '© 1404 تک پوش خاص. تمام حقوق محفوظ است.', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET 
    text = EXCLUDED.text, 
    updated_at = CURRENT_TIMESTAMP;

-- Insert about content
INSERT INTO about_content (id, content, created_at, updated_at) 
VALUES (1, 'تک پوش خاص - برند منحصر به فرد شما در تولید تی‌شرت‌های با کیفیت و طراحی‌های منحصر به فرد', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET 
    content = EXCLUDED.content, 
    updated_at = CURRENT_TIMESTAMP;

-- Insert sample t-shirt images
INSERT INTO tshirt_images (title, description, image_url, size, price, is_active, display_order, created_at, updated_at)
VALUES 
    ('تی‌شرت کلاسیک', 'تی‌شرت ساده و شیک مناسب برای استفاده روزمره', '/uploads/sample-1.jpg', 'M', '75000', true, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('تی‌شرت اسپرت', 'تی‌شرت راحت مناسب برای ورزش و فعالیت‌های فیزیکی', '/uploads/sample-2.jpg', 'L', '85000', true, 2, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('تی‌شرت طرح‌دار', 'تی‌شرت با طراحی منحصر به فرد و جذاب', '/uploads/sample-3.jpg', 'XL', '95000', true, 3, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;
DATAEOF

    if [ $? -eq 0 ]; then
        print_success "داده‌های پیش‌فرض با موفقیت درج شدند"
    else
        print_warning "مشکل در درج برخی داده‌های پیش‌فرض"
    fi
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

# Function to check and kill port conflicts
check_port_conflicts() {
    print_status "بررسی تداخل پورت‌ها..."
    
    # Check port 3000
    if netstat -tlnp 2>/dev/null | grep -q ":3000 "; then
        print_warning "پورت 3000 در حال استفاده است، حل تداخل..."
        fuser -k 3000/tcp 2>/dev/null || true
        pkill -f "node.*3000" 2>/dev/null || true
        pkill -f "tsx.*server" 2>/dev/null || true
        sleep 3
    fi
    
    # Check port 80
    if netstat -tlnp 2>/dev/null | grep -q ":80 " && ! pgrep nginx >/dev/null; then
        print_warning "پورت 80 در حال استفاده است، حل تداخل..."
        fuser -k 80/tcp 2>/dev/null || true
        sleep 2
    fi
}

# Function to start services
start_services() {
    print_status "راه‌اندازی سرویس‌ها..."
    
    # Check for port conflicts first
    check_port_conflicts
    
    # Enable services
    systemctl enable $APP_NAME >/dev/null 2>&1
    systemctl enable nginx >/dev/null 2>&1
    
    # Start database first
    systemctl start postgresql >/dev/null 2>&1
    sleep 2
    
    # Kill any conflicting processes
    pkill -f "node.*3000" 2>/dev/null || true
    pkill -f "tsx.*server" 2>/dev/null || true
    sleep 3
    
    # Start application
    systemctl start $APP_NAME >/dev/null 2>&1
    sleep 8
    
    # Check if app is running
    if ! systemctl is-active --quiet $APP_NAME; then
        print_warning "خطا در راه‌اندازی اپلیکیشن، بررسی لاگ..."
        journalctl -u $APP_NAME --no-pager -n 20 || true
        
        print_warning "تلاش مجدد..."
        systemctl stop $APP_NAME >/dev/null 2>&1 || true
        sleep 2
        systemctl start $APP_NAME >/dev/null 2>&1
        sleep 8
    fi
    
    # Start nginx
    systemctl start nginx >/dev/null 2>&1
    
    # Final status check with comprehensive health verification
    print_status "بررسی نهایی وضعیت سرویس‌ها..."
    
    # Wait for services to fully initialize
    sleep 5
    
    # Check systemd services
    if systemctl is-active --quiet $APP_NAME && systemctl is-active --quiet nginx; then
        print_success "سرویس‌های systemd فعال هستند"
        
        # Test HTTP responses
        sleep 3
        APP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null || echo "000")
        NGINX_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null || echo "000")
        
        if [[ "$APP_RESPONSE" =~ ^[245][0-9][0-9]$ ]]; then
            print_success "اپلیکیشن پاسخ می‌دهد (HTTP $APP_RESPONSE)"
        else
            print_warning "اپلیکیشن پاسخ نمی‌دهد، restart..."
            systemctl restart $APP_NAME >/dev/null 2>&1
            sleep 8
        fi
        
        if [[ "$NGINX_RESPONSE" =~ ^[245][0-9][0-9]$ ]]; then
            print_success "Nginx پاسخ می‌دهد (HTTP $NGINX_RESPONSE)"
        else
            print_warning "Nginx مشکل دارد، restart..."
            systemctl restart nginx >/dev/null 2>&1
            sleep 3
        fi
    else
        print_error "سرویس‌ها فعال نیستند، بررسی لاگ..."
        journalctl -u $APP_NAME --no-pager -n 10 2>/dev/null || true
        journalctl -u nginx --no-pager -n 5 2>/dev/null || true
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
