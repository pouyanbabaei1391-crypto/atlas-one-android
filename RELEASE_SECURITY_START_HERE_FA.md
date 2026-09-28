# انتشار امن و قانونی Atlas One

## مشکل دو تصویر چه بود؟

تصویر اول هشدار Google Play Protect برای APK نصب‌شده خارج از Google Play و با ناشر ناشناخته است. این هشدار با دست‌کاری Manifest یا مخفی‌کردن رفتار برنامه به‌شکل قانونی حذف نمی‌شود. مسیر درست، امضای ثابت Release و انتشار از Google Play با Play App Signing است.

تصویر دوم Crash هنگام شروع برنامه است. Build امن، بازیابی Safe Startup را اضافه می‌کند و از بازگرداندن Database/کلیدهای رمزنگاری‌شده ناسازگار توسط Android Backup جلوگیری می‌کند. برای تشخیص قطعی هر Crash باقی‌مانده باید Logcat همان گوشی بررسی شود.

## راه‌اندازی یک‌باره امضای Release

1. فایل `SETUP_RELEASE_SIGNING.ps1` را در PowerShell اجرا کنید.
2. فایل JKS و رمزها را در محل امن و آفلاین پشتیبان بگیرید.
3. در GitHub به `Settings → Secrets and variables → Actions` بروید.
4. چهار Secret نمایش‌داده‌شده توسط اسکریپت را اضافه کنید.
5. `UPDATE_TO_GITHUB.bat` را اجرا کنید.
6. Workflow با نام `Build Signed Atlas Android Release` خودکار اجرا می‌شود.

Artifact نهایی شامل این فایل‌هاست:

- `Atlas-One-Secure-Release.apk`: برای تست مستقیم و دستگاه‌های سازمانی.
- `Atlas-One-Google-Play.aab`: برای بارگذاری در Google Play Console.
- `SHA256SUMS.txt`: برای کنترل تمامیت فایل‌ها.

## حذف قانونی هشدار Play Protect

برای کاربران عمومی، فایل AAB را در Google Play Console بارگذاری کنید، Play App Signing را فعال کنید، Privacy Policy و Data Safety را تکمیل کنید و برنامه را ابتدا از Internal testing منتشر کنید. نصب APK از فایل‌منیجر همچنان ممکن است هشدار «ناشر ناشناخته» نشان دهد؛ حتی اگر APK سالم و امضاشده باشد.

## کنترل‌های افزوده‌شده

- امضای Release ثابت با RSA-4096 و نگهداری کلید فقط در GitHub Secrets.
- شکست امن Workflow در نبود کلید؛ هیچ APK با امضای Debug منتشر نمی‌شود.
- بررسی امضای APK و جلوگیری از انتشار APK قابل Debug.
- غیرفعال‌سازی Cleartext HTTP و اعتماد فقط به گواهی‌های سیستمی HTTPS.
- جلوگیری از Cloud Backup/Device Transfer برای حافظه، کلیدها و Database خصوصی.
- Safe Startup برای جلوگیری از بسته‌شدن کامل برنامه در خطای سرویس اختیاری یا داده قدیمی.
- SHA-256 برای APK و AAB.
- حفظ همه فایل‌ها و قابلیت‌های قبلی؛ سخت‌سازی فقط روی Build stage موقت اعمال می‌شود.

## نکات الزامی Google Play

- آدرس عمومی Privacy Policy را در Play Console ثبت کنید.
- فرم Data Safety را مطابق `GOOGLE_PLAY_DATA_SAFETY_FA.md` تکمیل کنید.
- برای Microphone، Camera، Foreground Service و Screen Capture توضیح صادقانه و ویدئوی Review ارائه کنید.
- قبل از انتشار، نام تجاری، آیکن، اسکرین‌شات‌ها، ایمیل پشتیبانی و مالکیت مجوز مدل‌ها را تأیید کنید.
- برای مدل دانلودی 1.11 GB، رضایت کاربر، اندازه دانلود، Wi‑Fi و فضای موردنیاز را شفاف نمایش دهید.

هیچ نرم‌افزاری را نمی‌توان روی تمام مدل‌های گوشی «بدون حتی یک خطای احتمالی» تضمین کرد. این Build خطاهای شناخته‌شده را Fail-closed می‌کند؛ تست واقعی روی Android 9 تا نسخه جاری و Logcat همچنان ضروری است.

