# Prompt cho Antigravity – Nhận thông báo đẩy (FCM)

Backend đã xong phần gửi: mọi thông báo đi qua một cổng duy nhất (giờ yên lặng, tối đa mỗi ngày, chống trùng),
gửi thật qua Firebase Cloud Messaging khi chạy với `FIREBASE_CREDENTIALS`. Thiếu một bước: **app chưa gửi FCM token
lên backend**, nên `users.devices` trống và không thông báo nào tới điện thoại.

API backend (đã có, đừng sửa backend):
- `POST /devices` body `{"token": "<FCM token>", "platform": "android" | "ios" | "web"}` → 200.
  Gửi lại cùng token chỉ cập nhật `lastSeenAt`; token đang gắn với tài khoản khác thì backend tự gỡ khỏi tài khoản đó.
- Mỗi push có `notification` (title, body) và `data` với khóa `route` (vài loại kèm id):

| `data.route` | Mở màn hình trong app |
|---|---|
| `/checkin` | `/checkin` |
| `/workout/<sessionId>` | `/workout/<sessionId>` |
| `/nutrition` | tab Dinh dưỡng `/nutrition` (nhắc uống nước) |
| `/coach` (+ `coachMessageId`) | tab Coach `/coach` |
| `/buddy` (+ `pairId`) | `/buddy` |
| `/review` (+ `reviewId`) | `/reviews/latest` (router chưa có `/review`) |
| `/plan` | tab Tập `/workout` (router chưa có `/plan`) |
| route lạ / thiếu | `/home` |

`app/android/app/google-services.json` đã có trên máy dev (bị .gitignore, không commit).

---

```
Bạn đang ở nhánh feat/app-push (worktree D:\levelup-worktrees\app-push), không chuyển nhánh, không merge vào main.
Đọc AGENTS.md và docs/prompts/antigravity-fcm-push.md. Chỉ sửa app/ (không camera_counter/, backend/, mongo/).
Không commit google-services.json.

1. Thêm firebase_messaging (bản tương thích firebase_core đang dùng). Android: quyền
   android.permission.POST_NOTIFICATIONS trong AndroidManifest (Android 13+), kênh thông báo mặc định
   "levelup_reminders" (tên hiển thị "Nhắc tập & thói quen") khai báo qua meta-data
   com.google.firebase.messaging.default_notification_channel_id. Icon thông báo dùng icon app.

2. Tạo app/lib/features/notifications/ (data/domain/presentation như các feature khác):
   - PushService (interface) + FirebasePushService + FakePushService cho test, cung cấp bằng Riverpod provider.
   - requestPermission(), getToken(), onTokenRefresh, deleteToken().
   - DeviceRepository gọi POST /devices qua ApiClient (Dio) hiện có.

3. Khi nào đăng ký token:
   - Màn onboarding "Bật thông báo" (ob_notify_screen.dart): nút bật → xin quyền hệ thống. Người dùng từ chối
     thì vẫn đi tiếp onboarding bình thường, setPushEnabled(false).
   - Sau khi đăng nhập và GET /me thành công (người dùng đã onboarding, settings.notifications.pushEnabled = true):
     nếu đã có quyền thì lấy token và POST /devices. Gọi mỗi lần mở app là được (backend chống trùng).
   - onTokenRefresh → POST /devices lại.
   - Lỗi mạng/401 khi gửi token: chỉ debugPrint, không hiện lỗi cho người dùng, không chặn luồng.
   - Chế độ AUTH_MODE=dev và web: không gọi Firebase Messaging (dùng FakePushService), để test và chạy Chrome không lỗi.

4. Bấm vào thông báo → mở đúng màn theo bảng route ở trên (dùng go_router). Xử lý cả 3 trường hợp:
   app đang mở (onMessageOpenedApp), app chạy nền, app đã tắt (getInitialMessage, điều hướng sau khi router sẵn sàng
   và người dùng đã đăng nhập).

5. Thông báo tới khi app đang mở (onMessage): Android không tự hiện, nên hiện một SnackBar/banner nhỏ trong app
   với title + body, bấm vào thì điều hướng như mục 4. Không thêm thư viện local notification nếu không cần.

6. Cài đặt (profile_screen.dart): công tắc "Bật thông báo nhắc tập" đang lưu pushEnabled. Khi người dùng bật lại
   mà hệ thống chưa cho quyền → xin quyền; vẫn bị từ chối → hiện câu hướng dẫn mở Cài đặt điện thoại để bật.

7. Đăng xuất: gọi deleteToken() trước khi signOut, để tài khoản cũ không còn nhận thông báo trên máy này.

8. Test (flutter test, không cần Firebase thật):
   - map route → đường dẫn go_router (bảng ở trên, gồm route lạ → /home).
   - Sau GET /me thành công với FakePushService có token → DeviceRepository nhận đúng {token, platform}.
   - pushEnabled = false hoặc từ chối quyền → không gọi POST /devices.
   - Đăng xuất gọi deleteToken.
   flutter analyze sạch, flutter test qua hết. Không chạy dart format cho cả thư mục, chỉ file bạn sửa.

9. Commit trên feat/app-push, dạng "app: đăng ký FCM token và mở đúng màn khi bấm thông báo". Báo lại để Claude Code review.
```

## Cách thử trên máy thật (sau khi merge)

1. Chạy backend với `FIREBASE_CREDENTIALS=D:\secrets\levelup-pro-firebase.json` (gửi thật qua FCM).
2. Cài app lên điện thoại, đăng nhập, cho phép thông báo → trong MongoDB, `users.devices` có token.
3. Bật "Nhắc uống nước" trong Cài đặt, gọi `POST /jobs/tick` trong khung 11–13h hoặc 16–18h khi chưa uống đủ
   → điện thoại nhận thông báo, bấm vào mở tab Dinh dưỡng.
