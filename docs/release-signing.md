# Ký bản release Android của LevelUp

Application ID: `vn.levelup.app`. Cấu hình ở `app/android/app/build.gradle.kts` đọc
`app/android/key.properties` nếu file tồn tại và tạo `signingConfigs.release`.
Không có file này thì release dùng khóa debug để máy dev và CI vẫn build được.
**Bản ký debug chỉ dùng thử nghiệm; trước khi phát hành phải cấu hình khóa release.**
Nếu file đã tồn tại nhưng thiếu trường hoặc sai đường dẫn khóa, Gradle báo lỗi;
không tự lùi về debug để tránh phát hành nhầm khóa.

## Tạo khóa ngoài repo (thực hiện thủ công khi chuẩn bị phát hành)

Không tạo khóa thật trong công việc R8 này. Khi cần, chạy PowerShell:

```powershell
New-Item -ItemType Directory -Path D:\secrets -Force
keytool -genkeypair -v -keystore D:\secrets\levelup-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias levelup-release
```

Nhập mật khẩu và thông tin chứng thư khi được hỏi; không đưa mật khẩu vào lệnh hoặc
lịch sử terminal. Nếu `keytool` chưa có trong PATH, tìm Java bằng `flutter doctor -v`
và dùng `keytool.exe` cùng thư mục `bin` với `java.exe` (PowerShell cần `&` trước
đường dẫn được đặt trong dấu nháy).

Tạo **cục bộ** `app/android/key.properties` theo mẫu sau, thay mật khẩu placeholder:

```properties
storeFile=D:/secrets/levelup-release.jks
storePassword=THAY_BANG_MAT_KHAU_KHOA
keyAlias=levelup-release
keyPassword=THAY_BANG_MAT_KHAU_ALIAS
```

Nên dùng đường dẫn tuyệt đối với `/` trên Windows như mẫu. Nếu dùng `\` phải ghi
`D:\\secrets\\levelup-release.jks` vì Java Properties xử lý ký tự escape.
Đường dẫn tương đối được tính từ `app/android/`.

`.gitignore` Android đã chặn `key.properties`, `**/*.jks`, `**/*.keystore`;
`.gitignore` gốc chặn `*.jks`, `*.keystore`, `**/google-services.json`.
Không commit khóa, mật khẩu hoặc file Firebase. Có thể kiểm tra:

```powershell
git check-ignore app/android/key.properties app/android/release.jks app/android/release.keystore app/android/app/google-services.json
```

## Đăng ký SHA-1 và SHA-256 trong Firebase

```powershell
keytool -list -v -keystore D:\secrets\levelup-release.jks -alias levelup-release
```

Lấy cả `SHA1` và `SHA256` trong kết quả. Vào Firebase Console đúng project
(`levelup-pro`) → **Project settings → Android app `vn.levelup.app` → Add fingerprint**,
thêm từng fingerprint, lưu, rồi tải lại `google-services.json` và đặt ở
`app/android/app/google-services.json` trên máy build. Giữ fingerprint debug hiện có
để bản dev vẫn đăng nhập Google được. Khi CI ký release, cung cấp file Properties,
keystore và Firebase config qua secret storage của CI, không qua Git.

Nếu dùng Play App Signing, APK tải từ CH Play được ký bằng **app signing key** của
Google Play, có thể khác khóa upload ở trên. Lấy thêm SHA-1/SHA-256 của app signing
certificate trong Play Console → App integrity/App signing và đăng ký trong Firebase
để đăng nhập Google hoạt động trên bản từ CH Play.

## Build và kiểm tra

Đóng Docker và app nặng trước khi build trên máy 8 GB RAM. Từ repo:

```powershell
cd app
flutter build apk --release --dart-define=API_BASE_URL=https://levelup-backend-kjqn.onrender.com
```

APK: `app/build/app/outputs/flutter-apk/app-release.apk`. Có thể dùng `apksigner verify
--verbose --print-certs` từ Android SDK build-tools để kiểm tra chứng thư APK và đối
chiếu fingerprint trước khi gửi bản phát hành.

Cài thử trên điện thoại, mở app và kiểm tra đăng nhập Google, quyền camera, đếm rep
bằng ML Kit, chụp món ăn, lưu thiết lập và Firebase Messaging foreground/background.
Nếu crash, thu `adb logcat` lúc mở app; gửi stack trace cùng
`app/build/app/outputs/mapping/release/mapping.txt` để xác định class bị R8 tác động.
Build thành công chưa xác nhận được các luồng này chạy trên thiết bị.

## Sao lưu khóa

Sao lưu keystore và mật khẩu ở nơi riêng, an toàn, có bản dự phòng. **Mất app signing
key tự quản lý thì không cập nhật được app hiện có trên CH Play.** Với Play App
Signing, mất **upload key** có quy trình yêu cầu reset upload key; Google giữ app
signing key. Phải phân biệt hai loại khóa trước khi xử lý sự cố.

Nguồn: [Flutter Android release/signing](https://docs.flutter.dev/deployment/android),
[Android app signing và Play App Signing](https://developer.android.com/studio/publish/app-signing),
[Firebase Google sign-in cho Flutter](https://firebase.google.com/docs/auth/flutter/federated-auth).
