# نصب سریع تک پوش خاص

## نصب یک خطی

```bash
bash <(curl -Ls https://raw.githubusercontent.com/tek-push-khas/install/main/install.sh)
```

## پس از نصب

### ورود به پنل مدیریت
- آدرس: `http://IP-SERVER` یا `https://DOMAIN.com`
- نام کاربری: `admin`
- رمز عبور: `admin123`

### اولین کارها
1. تغییر رمز عبور ادمین
2. تنظیم اطلاعات برند
3. آپلود تصاویر تی‌شرت
4. پیکربندی شبکه‌های اجتماعی

## دستورات مهم

```bash
# وضعیت سیستم
sudo systemctl status tek-push-khas

# راه‌اندازی مجدد
sudo systemctl restart tek-push-khas

# مشاهده لاگ
sudo journalctl -u tek-push-khas -f

# پشتیبان‌گیری
sudo /usr/local/bin/backup-tek-push-khas

# به‌روزرسانی
bash <(curl -Ls https://raw.githubusercontent.com/tek-push-khas/install/main/update.sh)
```

## مسیرهای مهم

- اپلیکیشن: `/opt/tek-push-khas/`
- تصاویر: `/opt/tek-push-khas/uploads/`
- لاگ‌ها: `/var/log/tek-push-khas/`
- پشتیبان: `/opt/backups/`

## پورت‌ها

- HTTP: 80
- HTTPS: 443
- اپلیکیشن: 3000 (داخلی)

## پشتیبانی

تلگرام: @TekPushKhasSupport