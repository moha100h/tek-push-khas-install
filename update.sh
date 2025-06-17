#!/bin/bash

# تک پوش خاص - اسکریپت به‌روزرسانی
# سیستم مدیریت برند تی‌شرت فارسی
# استفاده: bash <(curl -Ls https://raw.githubusercontent.com/tek-push-khas/install/main/update.sh)

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
BACKUP_DIR="/opt/backups"

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
        print_error "لطفاً با sudo اجرا کنید: sudo bash update.sh"
        exit 1
    fi
}

# Function to check if system is installed
check_installation() {
    if [[ ! -d "$APP_DIR" ]]; then
        print_error "سیستم نصب نشده است"
        print_error "ابتدا اسکریپت نصب را اجرا کنید"
        exit 1
    fi
    
    if ! systemctl list-unit-files | grep -q "$APP_NAME.service"; then
        print_error "سرویس سیستم یافت نشد"
        exit 1
    fi
}

# Function to create backup before update
create_backup() {
    print_status "ایجاد پشتیبان قبل از به‌روزرسانی..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Generate timestamp
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    APP_BACKUP="$BACKUP_DIR/${APP_NAME}_pre_update_$TIMESTAMP.tar.gz"
    DB_BACKUP="$BACKUP_DIR/${APP_NAME}_db_pre_update_$TIMESTAMP.sql"
    
    # Backup application files
    tar -czf "$APP_BACKUP" -C "$APP_DIR" . --exclude=node_modules --exclude=dist --exclude=build
    
    # Backup database
    sudo -u postgres pg_dump tek_push_khas > "$DB_BACKUP"
    
    print_success "پشتیبان ایجاد شد: $APP_BACKUP"
    print_success "پشتیبان پایگاه داده: $DB_BACKUP"
}

# Function to stop services
stop_services() {
    print_status "متوقف کردن سرویس‌ها..."
    
    systemctl stop "$APP_NAME" || print_warning "خطا در متوقف کردن $APP_NAME"
    
    print_success "سرویس‌ها متوقف شدند"
}

# Function to update application
update_application() {
    print_status "به‌روزرسانی اپلیکیشن..."
    
    cd "$APP_DIR"
    
    # Save current .env file
    cp .env .env.backup 2>/dev/null || true
    
    # Update from git if available
    if [[ -d .git ]]; then
        print_status "به‌روزرسانی از مخزن Git..."
        sudo -u "$SERVICE_USER" git fetch origin
        sudo -u "$SERVICE_USER" git reset --hard origin/main
    else
        print_status "دانلود آخرین نسخه..."
        # Download latest version
        wget -q "https://github.com/tek-push-khas/website/archive/main.zip" -O update.zip
        unzip -q update.zip
        
        # Backup important files
        cp website-main/package.json package.json.new
        cp website-main/package-lock.json package-lock.json.new 2>/dev/null || true
        
        # Copy new files (exclude sensitive ones)
        rsync -av --exclude='.env*' --exclude='uploads/' --exclude='logs/' --exclude='node_modules/' website-main/ ./
        
        # Restore package files
        mv package.json.new package.json
        mv package-lock.json.new package-lock.json 2>/dev/null || true
        
        # Cleanup
        rm -rf website-main update.zip
    fi
    
    # Restore .env file
    cp .env.backup .env 2>/dev/null || true
    
    # Set proper ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
    
    print_success "کد منبع به‌روزرسانی شد"
}

# Function to update dependencies
update_dependencies() {
    print_status "به‌روزرسانی وابستگی‌ها..."
    
    cd "$APP_DIR"
    
    # Clear npm cache
    sudo -u "$SERVICE_USER" npm cache clean --force
    
    # Update dependencies
    sudo -u "$SERVICE_USER" npm ci --production
    
    print_success "وابستگی‌ها به‌روزرسانی شدند"
}

# Function to build application
build_application() {
    print_status "ساخت نسخه جدید..."
    
    cd "$APP_DIR"
    
    # Build application
    sudo -u "$SERVICE_USER" npm run build 2>/dev/null || {
        print_warning "خطا در ساخت، استفاده از نسخه فعلی"
        return 0
    }
    
    print_success "نسخه جدید ساخته شد"
}

# Function to update database
update_database() {
    print_status "به‌روزرسانی پایگاه داده..."
    
    cd "$APP_DIR"
    
    # Run migrations
    sudo -u "$SERVICE_USER" npm run db:push 2>/dev/null || {
        print_warning "خطا در اجرای مایگریشن"
        return 0
    }
    
    print_success "پایگاه داده به‌روزرسانی شد"
}

# Function to start services
start_services() {
    print_status "راه‌اندازی سرویس‌ها..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Start application
    systemctl start "$APP_NAME"
    
    # Wait for service to start
    sleep 5
    
    # Check if service is running
    if systemctl is-active --quiet "$APP_NAME"; then
        print_success "سرویس با موفقیت راه‌اندازی شد"
    else
        print_error "خطا در راه‌اندازی سرویس"
        print_status "بررسی لاگ‌ها: journalctl -u $APP_NAME -n 20"
        return 1
    fi
}

# Function to verify update
verify_update() {
    print_status "بررسی به‌روزرسانی..."
    
    # Check service status
    if systemctl is-active --quiet "$APP_NAME"; then
        print_success "✅ سرویس در حال اجرا است"
    else
        print_error "❌ سرویس در حال اجرا نیست"
        return 1
    fi
    
    # Check if application responds
    sleep 3
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|302\|404"; then
        print_success "✅ اپلیکیشن پاسخ می‌دهد"
    else
        print_warning "⚠️ اپلیکیشن پاسخ نمی‌دهد"
    fi
    
    # Check nginx status
    if systemctl is-active --quiet nginx; then
        print_success "✅ وب سرور فعال است"
    else
        print_warning "⚠️ وب سرور غیرفعال است"
    fi
}

# Function to cleanup old backups
cleanup_backups() {
    print_status "پاکسازی پشتیبان‌های قدیمی..."
    
    # Keep only last 5 update backups
    find "$BACKUP_DIR" -name "${APP_NAME}_pre_update_*" -type f | sort -r | tail -n +6 | xargs rm -f 2>/dev/null || true
    
    print_success "پشتیبان‌های قدیمی پاک شدند"
}

# Function to display update summary
display_summary() {
    clear
    echo
    print_success "🎉 =========================================="
    print_success "     به‌روزرسانی با موفقیت تکمیل شد!"
    print_success "=========================================="
    echo
    
    # Get application info
    cd "$APP_DIR"
    APP_VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "نامشخص")
    
    print_status "📋 اطلاعات سیستم:"
    echo "  📂 مسیر اپلیکیشن: $APP_DIR"
    echo "  🔖 نسخه: $APP_VERSION"
    echo "  📅 تاریخ به‌روزرسانی: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Get service status
    if systemctl is-active --quiet "$APP_NAME"; then
        echo "  🟢 وضعیت سرویس: فعال"
    else
        echo "  🔴 وضعیت سرویس: غیرفعال"
    fi
    
    echo
    print_status "⚡ دستورات مفید:"
    echo "  📊 بررسی وضعیت: sudo systemctl status $APP_NAME"
    echo "  📝 مشاهده لاگ: sudo journalctl -u $APP_NAME -f"
    echo "  🔄 راه‌اندازی مجدد: sudo systemctl restart $APP_NAME"
    echo "  📄 مشاهده تغییرات: cd $APP_DIR && git log --oneline -10"
    echo
    
    if [[ -f "$BACKUP_DIR/${APP_NAME}_pre_update_$(date +%Y%m%d)_"*.tar.gz ]]; then
        echo "  💾 پشتیبان امروز: $BACKUP_DIR/${APP_NAME}_pre_update_$(date +%Y%m%d)_*.tar.gz"
        echo
    fi
    
    print_success "✅ سیستم آماده استفاده است!"
    echo
}

# Function to rollback if needed
rollback() {
    print_error "⚠️ خطا در به‌روزرسانی - آیا می‌خواهید به نسخه قبل بازگردید؟"
    read -p "برای بازگشت 'y' وارد کنید: " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "بازگشت به نسخه قبل..."
        
        # Find latest backup
        LATEST_BACKUP=$(find "$BACKUP_DIR" -name "${APP_NAME}_pre_update_*" -type f | sort -r | head -1)
        
        if [[ -n "$LATEST_BACKUP" ]]; then
            # Stop service
            systemctl stop "$APP_NAME"
            
            # Restore backup
            cd "$APP_DIR"
            rm -rf ./* 2>/dev/null || true
            tar -xzf "$LATEST_BACKUP"
            chown -R "$SERVICE_USER:$SERVICE_USER" "$APP_DIR"
            
            # Start service
            systemctl start "$APP_NAME"
            
            print_success "بازگشت به نسخه قبل انجام شد"
        else
            print_error "هیچ پشتیبانی یافت نشد"
        fi
    fi
}

# Main update function
main() {
    clear
    echo
    print_status "=========================================="
    print_status "    تک پوش خاص - به‌روزرسانی سیستم"
    print_status "=========================================="
    echo
    
    check_root
    check_installation
    
    print_status "شروع فرآیند به‌روزرسانی..."
    echo
    
    # Set error handling
    set +e
    
    create_backup || { print_error "خطا در ایجاد پشتیبان"; exit 1; }
    stop_services || { print_error "خطا در متوقف کردن سرویس‌ها"; rollback; exit 1; }
    update_application || { print_error "خطا در به‌روزرسانی اپلیکیشن"; rollback; exit 1; }
    update_dependencies || { print_error "خطا در به‌روزرسانی وابستگی‌ها"; rollback; exit 1; }
    build_application || print_warning "خطا در ساخت - ادامه با نسخه فعلی"
    update_database || print_warning "خطا در به‌روزرسانی پایگاه داده"
    start_services || { print_error "خطا در راه‌اندازی سرویس‌ها"; rollback; exit 1; }
    
    set -e
    
    verify_update
    cleanup_backups
    display_summary
}

# Handle script termination
trap 'print_error "به‌روزرسانی متوقف شد!"; exit 1' INT TERM

# Run main function
main "$@"