# Prompt cho Codex – Kịch bản demo, tài liệu bàn giao, kiểm tra số liệu món ăn

Bối cảnh: backend đã chạy thật trên Render (`https://levelup-backend-kjqn.onrender.com`), database MongoDB Atlas,
app cài bằng APK. Kế hoạch tuần 9–10 (`docs/02-ke-hoach-10-tuan.html`) cần: tài khoản demo có dữ liệu, màn giả lập
(Antigravity đang làm), kịch bản demo ~10 phút, tài liệu bàn giao. Backend demo: `POST /demo/{action}` với
`seed | skip-two | close-week | review | checkin | push-test` (xem `docs/prompts/antigravity-demo-streak.md`).

---

```
Bạn đang ở nhánh feat/codex-demo-docs (worktree D:\levelup-worktrees\codex-demo-docs), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md, docs/02-ke-hoach-10-tuan.html (mục Tuần 9–10, Công cụ demo, Kịch bản demo),
docs/01-user-flows.html, docs/deploy.md, docs/prompts/antigravity-demo-streak.md.
Chỉ sửa docs/ và mongo/seed/ (không sửa app/, backend/).

1. docs/demo/kich-ban-demo.md – kịch bản demo ~10 phút cho người chưa từng xem app, chạy được từ đầu đến cuối:
   - Chuẩn bị trước buổi demo: 2 điện thoại đã cài APK, 2 tài khoản demo (tài khoản chính + buddy), bấm
     "Nạp dữ liệu demo" ở màn giả lập (chạm 5 lần vào logo Trang chủ), mở app trước 5 phút để server Render thức,
     4G dự phòng, đĩa đồ ăn thật hoặc ảnh in, chỗ đủ sáng để quay squat, video quay sẵn dự phòng.
   - Từng bước theo "Kịch bản demo gợi ý" trong kế hoạch: bấm gì, nói gì (1–2 câu), màn hình phải thấy gì,
     nếu lỗi thì làm gì (ví dụ AI chậm → nói trước câu dẫn, chuyển video dự phòng).
   - Bảng "nút giả lập → điều người xem thấy" cho 6 action.
   - Checklist 10 mục kiểm tra 30 phút trước demo.

2. docs/demo/tai-khoan-demo.md – cách tạo tài khoản demo:
   - Tạo 2 tài khoản email/mật khẩu trong app (Firebase), làm onboarding.
   - Lấy uid: Atlas → Browse Collections → fitness → users → trường authUid.
   - Trên Render: DEMO_MODE=true, DEMO_UIDS=<uid1>,<uid2> → Manual Deploy.
   - Ghép buddy giữa 2 tài khoản bằng màn Buddy trong app.
   - KHÔNG ghi mật khẩu thật vào file; để chỗ trống cho team tự điền ở nơi an toàn.

3. docs/ban-giao.md – tài liệu bàn giao: kiến trúc tổng quan (app Flutter → backend Spring Boot trên Render →
   MongoDB Atlas, Firebase Auth + FCM, Gemini qua coach/AiClient, cron-job.org gọi /jobs/tick), link các tài liệu
   docs/0x, cách build APK (lệnh trong docs/deploy.md mục 4), cách deploy backend (push main → Render Manual Deploy),
   danh sách biến môi trường (không ghi giá trị bí mật), các việc còn để sau (iOS, buddy nhóm, bật lại R8 khi có
   quy tắc proguard).

4. Kiểm tra số liệu món "Phở bò tái" trong mongo/seed/foods.json: test backend
   (backend/src/test/java/vn/levelup/nutrition/NutritionFlowTest.java, dòng ~170) mong kcal = 430 (min 366, max 494),
   dữ liệu hiện tại là 536. Xác định số nào đúng theo nguồn bạn đã dùng, ghi lý do vào sourceNote của món đó.
   Nếu sửa foods.json thì giữ đúng cấu trúc; KHÔNG sửa file test backend – ghi số đúng (kcal, min, max) vào
   phần báo cáo để Claude Code sửa test.

5. Commit trên feat/codex-demo-docs, dạng "docs: kịch bản demo, tài khoản demo, bàn giao". Báo lại kết quả mục 4.
```
