# تک پوش خاص - راهنمای نصب

سیستم مدیریت برند تی‌شرت فارسی با قابلیت‌های پیشرفته و طراحی حرفه‌ای

## نصب سریع

برای نصب خودکار سیستم روی سرور خود، دستور زیر را اجرا کنید:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/tek-push-khas/install/main/install.sh)
```

## پیش‌نیازها

### سیستم‌عامل‌های پشتیبانی شده
- Ubuntu 20.04+ LTS
- Debian 11+
- CentOS 8+
- Red Hat Enterprise Linux 8+

### مشخصات حداقل سرور
- RAM: حداقل 2GB (توصیه شده 4GB)
- CPU: حداقل 2 هسته
- فضای ذخیره‌سازی: حداقل 20GB
- اتصال اینترنت پایدار

### دسترسی‌های مورد نیاز
- دسترسی root یا sudo
- پورت‌های 80 و 443 باز
- دامنه (اختیاری برای SSL)

## فرآیند نصب گام به گام

### 1. تهیه سرور
```bash
# ورود به سرور
ssh root@your-server-ip

# یا با کاربر sudo
ssh username@your-server-ip
```

### 2. اجرای نصب
```bash
# دانلود و اجرای اسکریپت نصب
bash <(curl -Ls https://raw.githubusercontent.com/tek-push-khas/install/main/install.sh)
```

### 3. پیکربندی اولیه
اسکریپت نصب موارد زیر را از شما درخواست خواهد کرد:

- **دامنه سایت**: example.com (اختیاری)
- **ایمیل SSL**: admin@example.com (برای دامنه)
- **رمز پایگاه داده**: خودکار یا دستی

## قابلیت‌های سیستم

### ویژگی‌های اصلی
- ✅ پنل مدیریت جامع
- ✅ آپلود و مدیریت تصاویر
- ✅ سیستم احراز هویت
- ✅ طراحی ریسپانسیو
- ✅ بهینه‌سازی SEO
- ✅ پشتیبانی از فارسی

### امکانات فنی
- ✅ پایگاه داده PostgreSQL
- ✅ Node.js + Express
- ✅ React + TypeScript
- ✅ Tailwind CSS
- ✅ SSL خودکار (Let's Encrypt)
- ✅ پشتیبان‌گیری خودکار
- ✅ نظارت سیستم

## مدیریت سیستم

### دستورات کلیدی
```bash
# مشاهده وضعیت سرویس
sudo systemctl status tek-push-khas

# راه‌اندازی مجدد
sudo systemctl restart tek-push-khas

# مشاهده لاگ‌ها
sudo journalctl -u tek-push-khas -f

# پشتیبان‌گیری دستی
sudo /usr/local/bin/backup-tek-push-khas
```

### فایل‌های مهم
```
/opt/tek-push-khas/           # مسیر اصلی اپلیکیشن
├── .env                      # تنظیمات محیط
├── uploads/                  # تصاویر آپلود شده
├── logs/                     # فایل‌های لاگ
└── public/                   # فایل‌های عمومی

/var/log/tek-push-khas/       # لاگ‌های سیستم
/opt/backups/                 # فایل‌های پشتیبان
```

## پیکربندی

### متغیرهای محیط (.env)
```bash
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://user:pass@localhost:5432/tek_push_khas
SESSION_SECRET=your-secret-key
```

### تنظیمات Nginx
```bash
# ویرایش تنظیمات وب سرور
sudo nano /etc/nginx/sites-available/tek-push-khas
sudo systemctl reload nginx
```

### تنظیمات پایگاه داده
```bash
# اتصال به PostgreSQL
sudo -u postgres psql tek_push_khas

# مشاهده جداول
\dt

# خروج
\q
```

## امنیت

### تنظیمات فایروال
```bash
# مشاهده وضعیت فایروال
sudo ufw status

# باز کردن پورت خاص
sudo ufw allow 8080/tcp
```

### تغییر رمز ادمین
1. وارد پنل مدیریت شوید
2. بخش تنظیمات کاربری
3. تغییر رمز عبور

### پشتیبان‌گیری

#### پشتیبان‌گیری خودکار
سیستم هر شب ساعت 2 به طور خودکار پشتیبان‌گیری انجام می‌دهد.

#### پشتیبان‌گیری دستی
```bash
# ایجاد پشتیبان
sudo /usr/local/bin/backup-tek-push-khas

# مشاهده فایل‌های پشتیبان
ls -la /opt/backups/
```

#### بازیابی از پشتیبان
```bash
# متوقف کردن سرویس
sudo systemctl stop tek-push-khas

# بازیابی فایل‌ها
cd /opt/tek-push-khas
sudo tar -xzf /opt/backups/tek-push-khas_YYYYMMDD_HHMMSS.tar.gz

# بازیابی پایگاه داده
sudo -u postgres psql tek_push_khas < /opt/backups/tek-push-khas_db_YYYYMMDD_HHMMSS.sql

# راه‌اندازی مجدد
sudo systemctl start tek-push-khas
```

## عیب‌یابی

### مشکلات رایج

#### سرویس راه‌اندازی نمی‌شود
```bash
# بررسی لاگ‌ها
sudo journalctl -u tek-push-khas --since "1 hour ago"

# بررسی تنظیمات
sudo nano /opt/tek-push-khas/.env

# تست اتصال پایگاه داده
sudo -u postgres psql -c "\l"
```

#### خطای 502 Bad Gateway
```bash
# بررسی وضعیت Nginx
sudo systemctl status nginx

# تست تنظیمات Nginx
sudo nginx -t

# بررسی پورت اپلیکیشن
sudo netstat -tulpn | grep :3000
```

#### مشکل آپلود تصاویر
```bash
# بررسی مجوزها
ls -la /opt/tek-push-khas/uploads/

# تنظیم مجوزهای صحیح
sudo chown -R tek-push-khas:tek-push-khas /opt/tek-push-khas/uploads/
sudo chmod -R 755 /opt/tek-push-khas/uploads/
```

## به‌روزرسانی

### به‌روزرسانی خودکار
```bash
# دانلود و اجرای اسکریپت به‌روزرسانی
bash <(curl -Ls https://raw.githubusercontent.com/tek-push-khas/install/main/update.sh)
```

### به‌روزرسانی دستی
```bash
cd /opt/tek-push-khas
sudo -u tek-push-khas git pull origin main
sudo -u tek-push-khas npm install
sudo -u tek-push-khas npm run build
sudo systemctl restart tek-push-khas
```

## پشتیبانی

### اطلاعات تماس
- 📧 ایمیل: support@tek-push-khas.com
- 📱 تلگرام: @TekPushKhasSupport
- 🌐 وب‌سایت: https://tek-push-khas.com

### مستندات
- [راهنمای کاربری](https://docs.tek-push-khas.com/user-guide)
- [راهنمای توسعه‌دهندگان](https://docs.tek-push-khas.com/developer-guide)
- [API Reference](https://docs.tek-push-khas.com/api)

### گزارش باگ
مشکلات خود را در [گیت‌هاب](https://github.com/tek-push-khas/website/issues) گزارش دهید.

## مجوز

این پروژه تحت مجوز MIT منتشر شده است. برای اطلاعات بیشتر فایل LICENSE را مطالعه کنید.

---

**نکته**: این راهنما به طور مداوم به‌روزرسانی می‌شود. برای آخرین اطلاعات به مخزن گیت‌هاب مراجعه کنید.