# Prompt cho Codex – Bật lại R8 cho bản release, chuẩn bị khóa ký release

Bối cảnh: bản release đầu tiên (`flutter build apk --release`) **thoát ngay khi mở** vì R8 (rút gọn code) xóa mất
class mà camera / ML Kit pose detection / Firebase / Google Sign-In gọi qua reflection. Claude Code đã tạm tắt R8
trong `app/android/app/build.gradle.kts` (`isMinifyEnabled = false`, `isShrinkResources = false`) → APK ~106 MB.
Bản release hiện ký bằng khóa debug (SHA-1 khóa debug đã đăng ký trong Firebase project levelup-pro nên đăng nhập
Google chạy được).

---

```
Bạn đang ở nhánh feat/app-r8 (worktree D:\levelup-worktrees\app-r8), không chuyển nhánh, không merge vào main.
Đọc AGENTS.md và docs/prompts/codex-r8-release.md.
Chỉ sửa app/android/** và docs/ (KHÔNG sửa app/lib, app/pubspec.yaml – Antigravity đang sửa ở nhánh khác).
Không commit keystore, key.properties, google-services.json.

1. app/android/app/proguard-rules.pro: quy tắc keep đủ cho các plugin trong app/pubspec.yaml, tối thiểu:
   google_mlkit_pose_detection / google_mlkit_commons (com.google.mlkit.**, com.google.android.gms.internal.mlkit_vision_**),
   camera (io.flutter.plugins.camera.**), firebase_core / firebase_auth / firebase_messaging (com.google.firebase.**),
   google_sign_in (com.google.android.gms.auth.**), permission_handler, shared_preferences, plugin đăng ký qua
   GeneratedPluginRegistrant. Ghi chú nguồn của từng nhóm quy tắc (README plugin / issue). Thêm -dontwarn cho các
   class mà R8 báo thiếu (xem build/app/outputs/mapping/release/missing_rules.txt sau khi build).

2. build.gradle.kts, buildTypes.release: bật lại isMinifyEnabled = true, isShrinkResources = true,
   proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro").
   Giữ comment giải thích vì sao từng tắt.

3. Khóa ký release (không tạo khóa thật, không commit khóa):
   - build.gradle.kts đọc android/key.properties nếu có (storeFile, storePassword, keyAlias, keyPassword) để tạo
     signingConfigs.release; không có file thì dùng khóa debug như hiện tại (để máy dev và CI vẫn build được).
   - .gitignore: key.properties, *.jks, *.keystore (kiểm tra đã có chưa).
   - docs/release-signing.md: lệnh keytool tạo khóa (để ngoài repo, ví dụ D:\secrets\levelup-release.jks),
     mẫu key.properties, cách lấy SHA-1/SHA-256 của khóa release (keytool -list -v) và thêm vào Firebase
     (Project settings → Android app vn.levelup.app → Add fingerprint) rồi tải lại google-services.json,
     lưu ý mất khóa thì không cập nhật được app trên CH Play.

4. Kiểm tra: `cd app && flutter build apk --release --dart-define=API_BASE_URL=https://levelup-backend-kjqn.onrender.com`
   phải build được; ghi kích thước APK trước/sau vào báo cáo. Máy dev chỉ 8 GB RAM: đóng Docker và app nặng trước
   khi build. Không cài được lên điện thoại thì ghi rõ "chưa thử trên máy" – Claude Code sẽ cài thử và đọc
   `adb logcat` khi app mở; nếu crash thì bạn bổ sung quy tắc theo log.

5. Commit trên feat/app-r8, dạng "app: bật lại R8 với quy tắc proguard, khóa ký release tùy chọn". Báo lại
   kích thước APK và các quy tắc -dontwarn đã thêm.
```
