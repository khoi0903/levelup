# Bàn giao LevelUp

Tài liệu vận hành bản demo Android kết nối Render. Claude Code review và merge vào `main`; từng agent commit tại worktree của mình. Source ở repo của team; APK/video và quyền truy cập giao qua kho nội bộ, mật khẩu/khóa ở kho bí mật.

## Kiến trúc tổng quan

**App Flutter → backend Java 21/Spring Boot trên Render → MongoDB Atlas (`fitness`)**. App đăng nhập **Firebase Auth**, gửi Firebase ID token trong `Authorization: Bearer`; backend xác minh, lấy người dùng từ token để lọc dữ liệu. API mô tả qua OpenAPI (`/swagger-ui.html`, `/v3/api-docs`).

Backend gọi **Gemini qua interface `coach/AiClient`** dùng chung cho coach, tổng kết tuần, nhận diện món ăn. AI đề xuất/gọi công cụ; backend kiểm tra trước khi ghi database. Khóa Gemini ở server; gói miễn phí chỉ dùng dữ liệu thử.

Thông báo qua một cổng gửi backend rồi tới **Firebase Cloud Messaging (FCM)** và điện thoại, có `dedupeKey`, `maxPerDay` và giờ yên lặng. **cron-job.org** gọi **`POST /jobs/tick` mỗi 10 phút** trên Render với header **`X-Job-Secret`** để chạy nhắc nhở, chốt ngày/tuần, tổng kết theo giờ địa phương. Header dùng `JOB_SECRET`, không dùng ID token người dùng.

Camera + ML Kit đếm số lần/xử lý tư thế trên điện thoại, video camera không rời máy. Buổi tập lưu offline bằng Drift rồi đồng bộ API; ảnh món ăn qua backend để nhận diện. `localDate` là `YYYY-MM-DD` theo `users.timezone` (mặc định `Asia/Ho_Chi_Minh`), tuần bắt đầu Thứ Hai; chỉ `durationSec >= 300` tính streak. Sàn mục tiêu calo 1200 kcal, nam 1500 kcal.

## Tài liệu và các phần cần giao

| Tài liệu | Nội dung |
|---|---|
| [01 · User flows](01-user-flows.html) | F1–F8: onboarding, vòng lặp ngày, bỏ buổi, streak, buddy, tổng kết, cột mốc, dinh dưỡng |
| [02 · Kế hoạch 10 tuần](02-ke-hoach-10-tuan.html) | Phạm vi/sprint; Tuần 9–10, công cụ và kịch bản demo |
| [03 · Database MongoDB](03-database-mongodb.html) | 22 collection, validator, index |
| [04 · Backend flow](04-backend-flow.html) | Module, endpoint, luồng xử lý và lỗi |
| [Deploy](deploy.md) | Atlas, biến môi trường, Render/Cloud Run, build APK |
| [Kịch bản demo](demo/kich-ban-demo.md) | Khoảng 10 phút, thao tác/lời dẫn, 6 nút, checklist và dự phòng |
| [Tài khoản demo](demo/tai-khoan-demo.md) | Firebase, UID, cấu hình demo và ghép buddy |
| [Đối chiếu 30 món](demo/doi-chieu-30-mon.md) | Nguồn, công thức khẩu phần, báo cáo Phở bò tái |
| [Màn giả lập/streak](prompts/antigravity-demo-streak.md) | Hợp đồng 6 action và yêu cầu giao diện |
| [Wireframe HTML](figma-export/wireframe-all.html) | Tham khảo luồng; màu cũ |

Bố cục theo [Figma team, trang Yes](https://www.figma.com/design/SPR387u9dcll7Ora7KH8b5/Untitled?node-id=68-263). Màu theo `app/lib/core/constants/app_colors.dart` và [prompt UI dịu mắt](prompts/antigravity-s2-ui-soft.md). Các bản trong `docs/archive-postgres/` và nhắc Supabase ở kế hoạch cũ là tài liệu lịch sử; bản bàn giao dùng MongoDB Atlas.

Team điền bảng này trong kho bàn giao nội bộ trước khi giao người vận hành:

| Hạng mục | Vị trí / người phụ trách |
|---|---|
| Repo, commit `main` đã review dùng để build | __________ |
| APK, commit tương ứng, ngày build | __________ |
| URL Render, người quản lý service | __________ |
| Atlas cluster và người quản lý | __________ |
| Firebase project, người quản lý Auth/FCM | __________ |
| cron-job.org, người quản lý, lần tick thành công gần nhất | __________ |
| Video offline và các đoạn dự phòng | __________ |
| Kho mật khẩu cho tài khoản demo/quyền hạ tầng | __________ |

## Build và cài APK

Lệnh theo **[deploy.md mục 4](deploy.md#4-kiểm-tra-và-build-app)**. Chạy tại checkout đã review; thay `<URL>` bằng URL Render. Không đổi nhánh trong worktree đang làm việc.

```powershell
curl https://<URL>/actuator/health
cd D:\fitness-app\app
flutter run -d <id điện thoại> --dart-define=API_BASE_URL=https://<URL>
flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://<URL>
```

Health trả `{"status":"UP"}`. APK: `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~50 MB, máy 64-bit;
máy rất cũ dùng `app-armeabi-v7a-release.apk`); sao chép cho team, cài cả hai máy (hoặc
`adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` khi đứng trong `app/`). Dùng Firebase mặc định, không truyền `AUTH_MODE=dev`. Nếu dùng Google login, thêm SHA-1 khóa ký release vào Firebase theo `deploy.md`; demo email/mật khẩu không cần bước Google này.

## Deploy backend trên Render

1. Claude Code review/merge vào `main`, rồi **push `main`** lên GitHub. Người vận hành kiểm tra Render theo dõi `main` và đúng commit cần deploy.
2. **levelup-backend → Manual Deploy → Deploy latest commit**. `render.yaml` đặt `autoDeploy: false`, chỉ push chưa cập nhật server.
3. Chờ Docker build/chạy xong; health `UP`, log `Started LevelupBackendApplication`. Gửi FCM thật cần Secret File service account và log `Push: gửi thật qua FCM`.
4. Kiểm tra đăng nhập, Trang chủ, chat mẫu và push trên máy demo. cron-job.org dùng POST, đúng `X-Job-Secret`, mỗi 10 phút; lần chạy gần nhất thành công.
5. Đổi biến môi trường/Secret File: lưu và Manual Deploy lại. Render free khởi động chậm sau ngủ; mở app/làm mới trước demo 5 phút. Log `OOMKilled`/status 137 thì giao Claude Code kiểm tra JVM theo `deploy.md`.

Cài lần đầu Atlas/Secret File/cron theo [deploy.md mục 1–3b](deploy.md). Nạp collection/kho bài/món trước lịch sử demo; không nạp lại dữ liệu chung mỗi buổi diễn.

## Biến môi trường và cấu hình

Chỉ ghi tên/mục đích; bí mật nằm ở Render Environment/Secret Files hoặc kho bí mật team. Đối chiếu `application.yaml`, `AiConfig`, `render.yaml` trong repo.

| Biến | Mục đích / nơi đặt |
|---|---|
| `MONGODB_URI` | URI Atlas chứa đăng nhập; bí mật, đặt Render |
| `MONGODB_DATABASE` | Tên database, demo dùng `fitness`; có mặc định backend |
| `LEVELUP_AI_PROVIDER` | Demo Render dùng `gemini`; có lựa chọn `claude`/`auto` |
| `GEMINI_API_KEY` | Khóa Gemini backend, bí mật |
| `LEVELUP_GEMINI_MODEL` | Model Gemini tùy chọn, mặc định theo `application.yaml` |
| `ANTHROPIC_API_KEY` | Khóa Claude tùy chọn, bí mật; không cần cho cấu hình Gemini |
| `LEVELUP_AI_MODEL` | Model Claude tùy chọn, mặc định theo `application.yaml` |
| `FIREBASE_PROJECT_ID` | Project Firebase xác minh token và gửi FCM |
| `FIREBASE_CREDENTIALS` | Đường dẫn Secret File trong container; Render dùng `/etc/secrets/firebase-sa.json` |
| `JOB_SECRET` | Bí mật `/jobs/tick`; cron-job.org gửi qua `X-Job-Secret` |
| `DEMO_MODE` | `true` khi demo, tắt khi hết chuỗi demo |
| `DEMO_UIDS` | Hai Firebase UID, phân cách dấu phẩy, lấy từ `users.authUid` |
| `PORT` | Cổng Render cấp, backend đọc tự động |
| `JAVA_TOOL_OPTIONS` | JVM định nghĩa trong Dockerfile; người phụ trách backend kiểm tra khi thiếu RAM |
| `SPRING_PROFILES_ACTIVE` | Nếu đặt trên server, dùng profile xác thực thật; không dùng `dev` |
| `API_BASE_URL` | **Dart define lúc build app**, không phải runtime Render; HTTPS của backend |

Secret File **`firebase-sa.json`** chứa JSON service account, quản lý ở Render → Environment → Secret Files. Không commit `.env`, service account, keystore hoặc mật khẩu. Khi đổi bí mật, cập nhật nơi sử dụng tương ứng và deploy lại.

## Việc còn để sau

- **iOS**: ký app, cấu hình Firebase/FCM/camera, thử máy thật và bàn giao TestFlight; APK Android là phạm vi hiện tại.
- **Buddy nhóm**: hiện ghép 1–1; nhóm/ngẫu nhiên với người lạ cần thiết kế quyền riêng tư, dữ liệu và luồng riêng.
- **Bật lại R8 và thu gọn resource** khi có quy tắc ProGuard phù hợp plugin, Firebase, camera/ML Kit. Hiện `isMinifyEnabled=false`, `isShrinkResources=false` để tránh lỗi reflection; người phụ trách app kiểm tra APK release đăng nhập/camera/push trước khi bật lại.
- **Test dinh dưỡng**: Claude Code cập nhật Phở bò tái theo [báo cáo](demo/doi-chieu-30-mon.md#đối-chiếu-phở-bò-tái-với-test-backend-2026-10-05): 550 g trả `kcal=536`, `kcalMin=455`, `kcalMax=616`. Tổng phụ thuộc món trong flow test cũng cần sửa; dữ liệu vẫn là mô hình khẩu phần, `verified=false`.

Trước bàn giao chính thức, hoàn tất checklist và ba lần tổng duyệt trên máy thật. Tài liệu này mô tả cách kiểm tra, không thay kết quả deploy/tổng duyệt thực tế của team.
