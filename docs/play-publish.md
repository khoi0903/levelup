# Đẩy AAB lên Google Play tự động

Dùng plugin Gradle Play Publisher (`com.github.triplet.play`, khai báo trong
`app/android/app/build.gradle.kts`) gọi Google Play Developer API. Không cần Ruby/fastlane.

## Chuẩn bị một lần

1. **Google Cloud** (dùng luôn project Firebase của LevelUp): https://console.cloud.google.com
   → chọn project → *APIs & Services → Library* → tìm **Google Play Android Developer API** → *Enable*.
2. *IAM & Admin → Service Accounts → Create service account*, tên ví dụ `play-publisher`.
   Bỏ qua bước gán vai trò trong Cloud (không cần) → *Done*.
3. Mở service account vừa tạo → tab *Keys → Add key → Create new key → JSON*. File tải về đổi tên
   và đặt tại `app/android/play-service-account.json` (đã nằm trong `.gitignore`, **không commit**).
4. **Play Console** → *Người dùng và quyền* (Users and permissions) → *Mời người dùng mới* → dán email
   service account (dạng `play-publisher@<project>.iam.gserviceaccount.com`).
   Tab *Quyền ứng dụng* → thêm LevelUp → tích *Phát hành lên kênh thử nghiệm*
   (và *Phát hành ứng dụng lên kênh chính thức* nếu sau này muốn đẩy production) → *Mời*.
   Quyền có thể mất vài phút (đôi khi tới 24 giờ) mới có hiệu lực.

Cần sẵn `app/android/key.properties` + `levelup-upload.jks` (khoá upload, xem `docs/release-signing.md`).
Script từ chối chạy nếu thiếu, để không đẩy nhầm bản ký khoá debug.

## Mỗi lần phát hành

Trong thư mục `app` (PowerShell):

```powershell
.\publish-play.ps1 -BumpBuild                  # tăng +N trong pubspec, build, đẩy lên test kín (alpha)
.\publish-play.ps1 -BumpBuild -Track internal  # thử nội bộ
```

- `versionCode` (số sau dấu `+` trong `pubspec.yaml`) phải lớn hơn mọi bản đã tải lên.
  `-BumpBuild` tự tăng 1; muốn đổi `1.0.8` → `1.0.9` thì sửa tay `pubspec.yaml`.
  Sau khi đẩy xong, commit `pubspec.yaml` theo nhánh `release/<phiên bản>` như trước.
- Track: `alpha` = test kín (mặc định), `internal` = thử nội bộ, `beta` = test mở, `production`.
- `-ReleaseStatus draft` để tạo bản nháp, vào Play Console tự bấm phát hành.
- `-SkipBuild` đẩy lại AAB đã build ở `app/build/app/outputs/bundle/release/`.
- Ghi chú phát hành (tuỳ chọn): `app/android/app/src/main/play/release-notes/vi-VN/default.txt`.
