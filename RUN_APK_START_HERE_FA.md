# اجرای مستقیم Workflow و دریافت APK

این نسخه برای اجرا به GitHub Secret اجباری نیاز ندارد.

1. فایل `UPDATE_TO_GITHUB.bat` را اجرا کنید.
2. Push که تمام شود، Workflow خودکار شروع می‌شود.
3. بعد از سبزشدن Run، Artifact با نام `Atlas-One-Installable-APK` را دانلود کنید.
4. ZIP مربوط به Artifact را Extract کنید.
5. فایل `Atlas-One-Secure-Release.apk` را روی گوشی نصب کنید.

اگر چهار Secret امضای دائمی موجود باشند، Workflow از کلید دائمی استفاده می‌کند. اگر Secret وجود نداشته باشد، خودش یک کلید موقت امن می‌سازد تا Build متوقف نشود و APK قابل نصب تولید شود.

محدودیت کلید موقت: APK ساخته‌شده در Run بعدی ممکن است کلید متفاوتی داشته باشد؛ بنابراین برای نصب نسخه بعدی ممکن است لازم باشد نسخه قبلی را Uninstall کنید. برای انتشار Google Play و Update بدون Uninstall، یک‌بار `SETUP_RELEASE_SIGNING.ps1` را اجرا و Secretهای دائمی را تنظیم کنید.

