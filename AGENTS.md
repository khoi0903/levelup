# Fitness App – quy ước chung cho mọi AI agent và thành viên

File này là nguồn quy ước duy nhất. Claude Code đọc qua `CLAUDE.md` (import file này),
Antigravity và các agent khác đọc trực tiếp file này. Sửa quy ước thì sửa ở đây.

## Sản phẩm
App fitness cho người Việt: tập theo bài có sẵn, AI coach, chụp món ăn tính calo,
đếm số lần bằng camera. Vấn đề cốt lõi: 60% người dùng bỏ app vì mất động lực,
nên hệ thống động lực (check-in, nhắc khi bỏ buổi, streak tuần, buddy, tổng kết tuần)
là trọng tâm và luôn miễn phí.

Tài liệu thiết kế trong `docs/`:
- `01-user-flows.html` – 8 flow F1–F8
- `02-ke-hoach-10-tuan.html` – kế hoạch tới bản demo
- `03-database-mongodb.html` – 22 collection, validator, index
- `04-backend-flow.html` – endpoint và luồng backend
- `figma-export/` – 27 màn hình wireframe dạng HTML

## Cấu trúc repo và ai phụ trách
| Thư mục | Nội dung | Phụ trách chính |
|---|---|---|
| `app/` | Flutter (Dart) | Antigravity |
| `backend/` | Java 21 + Spring Boot, Spring Data MongoDB | Claude Code |
| `mongo/` | docker-compose, `init.js` tạo collection | Claude Code |
| `docs/` | Tài liệu thiết kế | Ai cũng đọc, sửa qua PR |

Không sửa thư mục do agent khác phụ trách trong cùng lúc. Cần sửa chéo thì mở PR riêng.

## Git
- Nhánh: `main` luôn chạy được. Làm việc trên `feat/be-<tên>`, `feat/app-<tên>`, `fix/<tên>`.
- Commit nhỏ, mô tả bằng tiếng Việt hoặc tiếng Anh đều được, dạng `be: thêm POST /checkins`.
- Không commit `.env`, keystore, file service account Firebase.

## Quy tắc nghiệp vụ không được làm sai
- **Ngày của người dùng**: luôn lưu `localDate` dạng `"YYYY-MM-DD"` tính theo `users.timezone`
  (mặc định `Asia/Ho_Chi_Minh`). Tuần bắt đầu Thứ Hai (`weekStart`).
- Buổi tập **từ 5 phút** (`durationSec >= 300`) mới tính streak (`countsForStreak`).
- Thông báo: tối đa `maxPerDay` (mặc định 2) mỗi ngày, không gửi trong giờ yên lặng
  (22:00–07:00), mọi thông báo đi qua một cổng gửi duy nhất, có `dedupeKey`.
- Mục tiêu calo không dưới 1200 kcal (nam: 1500).
- AI không ghi thẳng vào database: AI gọi công cụ, backend kiểm tra rồi mới ghi.
- Mọi truy vấn dữ liệu người dùng phải lọc theo `userId` lấy từ token, không lấy từ body.
- Video camera không bao giờ rời khỏi điện thoại.

## Backend (Java)
- Java 21, Spring Boot, Maven wrapper (`./mvnw`). Package gốc `vn.fitnessapp`.
- Chia package theo module: `auth`, `users`, `onboarding`, `exercises`, `plans`, `workouts`,
  `checkins`, `coach`, `nutrition`, `motivation`, `notifications`, `jobs`, `demo`.
- Mỗi module: `*Controller`, `*Service`, `*Repository`, DTO dùng `record`.
- Xác thực: Firebase ID token ở header `Authorization: Bearer`.
- Gọi Claude API chỉ từ backend, key để trong biến môi trường `ANTHROPIC_API_KEY`.
- API mô tả bằng OpenAPI (springdoc), app Flutter sinh client từ đó.

## App (Flutter)
- `flutter_riverpod`, `go_router`, `drift` (lưu buổi tập offline), `camera` +
  `google_mlkit_pose_detection`, `firebase_auth`, `firebase_messaging`.
- Chia theo tính năng trong `lib/features/<tên>/{data,domain,presentation}`.
- Giao diện bám wireframe trong `docs/figma-export/`.

## MongoDB khi phát triển
- Chạy: `cd mongo && docker compose up -d`
- Kết nối: `mongodb://localhost:27018/fitness?replicaSet=rs0`
- Cổng 27017 trên máy là MongoDB khác, không dùng.
