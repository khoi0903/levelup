# Prompt cho Antigravity – Đăng nhập Firebase (làm SAU khi xong feat/app-shell)

Firebase project: `levelup-pro` (gói Spark miễn phí). Authentication đã bật **Google** và **Email/Password**.
`app/android/app/google-services.json` đã có trên máy dev (bị .gitignore, không commit). Mỗi máy dev phải
tự thêm SHA-1 khóa debug của mình vào Firebase rồi tải file về đúng chỗ đó.
Web client ID (công khai, dùng làm serverClientId cho Google Sign-In):
`736710213113-phmlbn7bq8197euanht9ku912ckmrsos.apps.googleusercontent.com`

Backend đã sẵn: ngoài profile `dev`, mọi request phải có `Authorization: Bearer <Firebase ID token>`,
kiểm tra issuer/audience theo project `levelup-pro` (backend/src/main/java/vn/levelup/auth/FirebaseJwtConfig.java).
Profile `dev` vẫn nhận `Bearer dev-<uid>`.

---

```
Bạn đang ở nhánh feat/app-auth (Claude Code tạo worktree D:\levelup-worktrees\app-auth), không chuyển nhánh.
Đọc AGENTS.md và docs/prompts/antigravity-firebase-auth.md. Chỉ sửa app/ (không camera_counter/, backend/, mongo/).
Không commit google-services.json.

1. Thêm firebase_core, firebase_auth, google_sign_in (bản mới nhất tương thích). Android: plugin
   com.google.gms.google-services trong settings.gradle(.kts) và app/build.gradle.kts. Khởi tạo Firebase
   trong main(). Google Sign-In dùng serverClientId = Web client ID ở trên (đặt trong một hằng số cấu hình).
2. Màn đăng nhập (trước onboarding): "Tiếp tục với Google", email + mật khẩu (đăng ký / đăng nhập / quên mật khẩu),
   lỗi hiển thị bằng câu tiếng Việt (sai mật khẩu, email đã dùng, mạng...). Màu từ app_colors.dart, bố cục theo Figma.
3. Token: authTokenProvider trong app/lib/core/api/api_client.dart lấy FirebaseAuth.instance.currentUser.getIdToken()
   (tự làm mới). Giữ chế độ dev: nếu chạy với --dart-define=AUTH_MODE=dev thì vẫn dùng "dev-<DEV_UID>" như cũ,
   để test trên web/Chrome và test tự động không cần Firebase. Mặc định khi build Android = firebase.
   Nhận 401 từ backend → đăng xuất và quay về màn đăng nhập.
4. Luồng mở app: chưa đăng nhập → màn đăng nhập; đã đăng nhập → GET /me như hiện tại (404 ONBOARDING_REQUIRED → onboarding).
5. Đăng xuất trong tab Tôi/Cài đặt: FirebaseAuth.signOut + GoogleSignIn.signOut, xóa state Riverpod, về màn đăng nhập.
6. Test: dùng AUTH_MODE dev / Fake auth repository; test luồng điều hướng (chưa đăng nhập, đã đăng nhập + 404, 401 → đăng xuất).
flutter analyze sạch, flutter test đạt. Không build Android khi Docker đang chạy (máy 8 GB).
Commit nhỏ, không merge vào main. Báo cáo: package thêm, file Gradle đã sửa, cách chạy dev vs firebase.
```

Ghi chú cho người chạy: backend thật (không profile dev) cần `FIREBASE_PROJECT_ID=levelup-pro` (đã là mặc định).
