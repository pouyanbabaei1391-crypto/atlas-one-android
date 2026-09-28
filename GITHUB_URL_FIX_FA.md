# اصلاح خطای آدرس GitHub

خطای مشاهده‌شده این بود:

`fatal: unable to access 'https://https://github.com/...': Could not resolve host: https`

در آدرس ذخیره‌شده، `https://` دو بار قرار گرفته بود. اسکریپت جدید موارد زیر را خودکار به آدرس استاندارد تبدیل می‌کند:

- `https://github.com/USER/REPO`
- `https://github.com/USER/REPO.git`
- `https://https://github.com/USER/REPO`
- `[https://github.com/USER/REPO](https://github.com/USER/REPO)`
- آدرس دارای فاصله مخفی، اسلش انتهایی یا کاراکترهای کپی‌شده اضافی

آدرس نهایی این پروژه باید در خروجی به شکل زیر نمایش داده شود:

`https://github.com/pouyanbabaei1391-crypto/atlas-one-android.git`

فایل خراب `.atlas_repo_url` لازم نیست دستی حذف شود؛ اجرای جدید آن را پاک‌سازی و دوباره ذخیره می‌کند. هشدارهای `LF will be replaced by CRLF` خطا نیستند و مانع Push نمی‌شوند.

