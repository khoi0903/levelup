# Báo cáo Android release R8 — 2026-10-05

Worktree `D:\levelup-worktrees\app-r8`, nhánh `feat/app-r8`, mã nguồn ban đầu
`019a548`. Chỉ sửa `app/android/**` và `docs/`; không sửa `app/lib`, `pubspec.yaml`
hoặc dependency lockfile. Không tạo khóa release thật.

## Thay đổi

- Bật `isMinifyEnabled`, `isShrinkResources`, dùng `proguard-android-optimize.txt`
  và `app/android/app/proguard-rules.pro`; giữ chú thích sự cố crash trước đây.
- Giữ GeneratedPluginRegistrant và các lớp triển khai FlutterPlugin; giữ các package
  camera/CameraX, ML Kit và internals vision, Firebase, Google auth/Google Identity,
  permission_handler, shared_preferences, image_picker, path_provider và JNI.
  Mỗi nhóm có nguồn trong file rules. Đây là keep bảo toàn cho LevelUp sau sự cố;
  các README xác định plugin, không được diễn giải là yêu cầu phải keep cả package.
- Consumer rules của các thư viện vẫn được áp dụng. JNI hiện được
  `path_provider_android 2.3.1` sử dụng; có consumer keep và keep tường minh của app.
- Ký release tùy chọn từ `android/key.properties`; thiếu file dùng debug. Có file
  nhưng thiếu trường/sai đường dẫn thì fail rõ ràng, không fallback âm thầm.
- Giới hạn hai Gradle worker, giữ heap Gradle 2560 MiB/Kotlin 1024 MiB hiện có cho
  máy 8 GB RAM. Quy tắc ignore khóa đã có, không cần sửa `.gitignore` ngoài phạm vi.
- Hướng dẫn tạo khóa ngoài repo, fingerprint Firebase và sao lưu ở
  [release-signing.md](release-signing.md).

## Môi trường và lệnh build

Flutter 3.47.3 stable, Dart 3.13.3, AGP 9.1.0, Gradle 9.3.1. Flutter dùng JBR
25 của Android Studio; Android compile SDK 37 và min SDK 24 theo cấu hình hiện có.
Người dùng đã xác nhận đóng Docker và app nặng trước khi build.

Đã dùng cấu hình SDK và `google-services.json` cục bộ của checkout chính, nằm trong
Git ignore; không đưa vào commit. Không có `android/key.properties` trong build APK,
nên APK được ký bằng debug.

Lần đầu gặp lỗi môi trường Java `Unable to establish loopback connection`, nguyên
nhân bên dưới là `UnixDomainSockets.connect` / `Invalid argument: connect`, trước
khi biên dịch Android. Khắc phục cho phiên terminal bằng đường dẫn socket ngắn:

```powershell
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=D:/levelup-worktrees/app-r8/app/android/.gradle'
cd app
flutter build apk --release --dart-define=API_BASE_URL=https://levelup-backend-kjqn.onrender.com
```

Biến môi trường này chỉ phục vụ máy hiện tại, không đưa đường dẫn worktree vào cấu
hình Gradle được commit. Baseline và bản R8 dùng cùng lệnh, cùng mã Dart/dependencies,
cùng APK đa ABI và khóa debug. Baseline cấu hình R8 tắt đã được Gradle đọc trước khi
cấu hình mới được ghi; file rules chưa được baseline sử dụng.

## Kích thước APK

APK ở `app/build/app/outputs/flutter-apk/app-release.apk`.
SHA-256 của APK sau R8:
`7c227a9d8fd58075c550540068c02edef3fa55258a8a8ef613f8311fbee827ad`.

| Bản | Byte | MiB (1.048.576 byte) |
|---|---:|---:|
| Trước: R8/resource shrink tắt, build trong worktree | 111.434.105 | 106,27 |
| Sau: R8/resource shrink bật với keep rules | 105.058.001 | 100,19 |

Giảm **6.376.104 byte (~6,08 MiB), tương đương 5,72%**. Flutter in `106.3MB`
và `100.2MB` tương ứng (đơn vị hiển thị này dùng cơ số 1024).
Baseline Gradle chạy 533,6 giây; lượt R8 chạy 679,1 giây trên máy này.
Keep rộng bảo toàn các SDK nên mức giảm có giới hạn; đây vẫn là APK đa ABI gồm
Flutter và model/thư viện native ML Kit, không phải APK split theo ABI.

## Xác minh R8 và chữ ký

- Lệnh build yêu cầu đã hoàn tất với exit code 0 cho cả baseline và R8.
- Có `configuration.txt`, `mapping.txt`, `seeds.txt`, `usage.txt`, `resources.txt`
  trong `app/build/app/outputs/mapping/release/`, xác nhận R8/resource shrinker đã chạy.
- Cấu hình hợp nhất chứa keep của app và consumer rules của các thư viện,
  bao gồm hai package JNI. Mapping giữ nguyên tên GeneratedPluginRegistrant,
  CameraAndroidCameraxPlugin, GoogleMlKitPoseDetectionPlugin,
  FlutterFirebaseMessagingPlugin và JniPlugin.
- **Các quy tắc `-dontwarn` thêm mới: không có.** Lượt R8 không báo missing class
  và không sinh `missing_rules.txt`. Các `-dontwarn` đã có sẵn từ Flutter/default
  ProGuard/consumer rules vẫn được áp dụng; không chép chúng thành quy tắc mới.
- `apksigner verify --verbose --print-certs` thành công, chứng thư Android Debug,
  APK Signature Scheme v2. Không có file khóa release khi build, xác nhận fallback
  debug hoạt động. Chưa ký bằng khóa production.
- Kiểm tra có `key.properties`: tạo file tạm tham chiếu debug keystore **đã có**
  (không tạo keystore mới), chạy `:app:signingReport`. Kết quả `Variant: release`,
  `Config: release`, đúng alias/fingerprint debug được cung cấp và `BUILD SUCCESSFUL`.
  Đã xóa file Properties tạm sau kiểm tra. Lượt này dùng Java 21 từ môi trường
  `gradlew` trực tiếp; không thay đổi APK đã build bằng Flutter/JBR 25.

Build vẫn có cảnh báo tương thích KGP từ firebase_auth/firebase_core, SDK XML
và Java native-access; các cảnh báo này không ngăn APK được tạo. Không đổi version
plugin hay mã Dart trong việc này.

## Kiểm tra trên thiết bị

**chưa thử trên máy**. `adb devices` không có thiết bị kết nối. Build thành công
không xác nhận đã sửa được crash lúc mở app trước đây.

Claude Code cần cài APK, mở app và thu `adb logcat`, kiểm tra Google Sign-In,
Firebase Messaging/background handler, quyền camera, ML Kit đếm rep, image_picker,
shared_preferences và các đường dẫn JNI. Nếu crash, gửi stack trace và dùng
`app/build/app/outputs/mapping/release/mapping.txt` để bổ sung keep theo class cụ thể.
