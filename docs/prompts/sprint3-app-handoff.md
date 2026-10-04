# Bàn giao app: các màn còn thiếu (Antigravity + Codex)

Backend đã có API cho F1–F8 (xem `backend/src/main/java/vn/levelup/**/*Controller.java`, OpenAPI tại
`http://localhost:8091/v3/api-docs` khi chạy backend dev). App mới có onboarding, trang chủ, luồng tập.
Hai bên chạy song song, mỗi bên một thư mục:

| Ai | Thư mục | Nhánh | Phạm vi |
|---|---|---|---|
| Antigravity | `D:\levelup-worktrees\app-shell` | `feat/app-shell` | khung app, cài đặt, lỗi/trống, động lực, coach |
| Codex | `D:\levelup-worktrees\codex-nutrition-ui` | `feat/app-nutrition` | dinh dưỡng, tiến độ |

Quy ước chung (cả hai): đọc `AGENTS.md`. Màu chỉ từ `app/lib/core/constants/app_colors.dart` (bảng dịu mắt),
widget dùng chung trong `app/lib/core/widgets/`, gọi API qua `app/lib/core/api/api_client.dart`,
Riverpod + repository + bản Fake cho test (xem `app/lib/features/workout/` làm mẫu). Bố cục theo Figma
trang "Yes" (fileKey `SPR387u9dcll7Ora7KH8b5`, node trang `68-263`), màu theo app. Tên trường JSON phải
khớp record Java của backend, không đoán. API nào chưa có thì làm UI với Fake repository, để TODO và ghi
vào báo cáo, không tự sửa backend. `flutter analyze` sạch, `flutter test` đạt. Không build Android trên
máy 8 GB khi Docker đang chạy. Commit nhỏ, không merge vào main.

---

## Prompt cho Antigravity

```
Bạn đang ở nhánh feat/app-shell, không chuyển nhánh. Đọc AGENTS.md và docs/prompts/sprint3-app-handoff.md.
Không sửa app/lib/features/camera_counter/, app/lib/features/nutrition/, app/lib/features/progress/
(Codex đang làm), backend/, mongo/.

1. Khung app: thanh điều hướng dưới (Trang chủ, Tập, Coach, Dinh dưỡng, Tôi) bằng go_router
   StatefulShellRoute. Tab Dinh dưỡng tạm trỏ tới route /nutrition (Codex làm màn), Tôi = hồ sơ + cài đặt.
2. Màn lỗi và màn trống dùng chung: widget ErrorView(code/message, Thử lại), EmptyView, OfflineBanner;
   route lỗi 404 của go_router (errorBuilder); thay mọi chỗ đang hiện text lỗi thô.
   Map mã lỗi backend sang câu tiếng Việt dễ hiểu (ONBOARDING_REQUIRED, COACH_LIMIT, PHOTO_LIMIT_REACHED,
   NETWORK_ERROR, 401, 500...).
3. Trang chủ: bỏ hết số liệu giả ('Minh', streak 5, 2/3 buổi) — lấy từ GET /me, GET /streak, GET /plans/current;
   đang tải thì skeleton.
4. Cài đặt (tab Tôi): tên hiển thị, phong cách coach (strict|supportive|funny), lịch rảnh, thông báo
   (bật/tắt, giờ yên lặng), chia sẻ với buddy, đăng xuất (xóa token dev). Backend CHƯA có API sửa cài đặt —
   Claude Code đang làm PATCH /me; tạm dùng repository Fake + TODO, đọc dữ liệu từ GET /me.
5. Check-in sáng (F2): POST /checkins (energy, sleep), hiện buổi đã điều chỉnh (adjustedReason).
6. Streak tuần (F4): GET /streak — 8 tuần, thẻ đóng băng, tuần này.
7. Bỏ buổi (F3): trên buổi tập có "Không tập được hôm nay" → POST /skip-reports (5 lý do, đau thì chọn vùng),
   hiện message + kế hoạch mới; PATCH /plans/sessions/{id} cho Dời lịch / Nghỉ.
8. Coach (tab Coach): GET /coach/messages (phân trang before), POST /coach/messages, thẻ hành động
   (card.status proposed → nút "Dùng buổi này" → POST /coach/messages/{id}/actions/apply), hết lượt 429.
9. Buddy (F5): tạo mã mời (POST /buddies/invites, chia sẻ shareText), nhập mã (POST /buddies/join),
   trạng thái hôm nay (GET /buddies/today), nhắc/cổ vũ (POST /buddies/{pairId}/actions), rời cặp.
10. Tổng kết tuần (F6): GET /reviews/latest, đồng ý/chỉnh (POST /reviews/{id}/decision).
11. Huy hiệu (F7): danh sách từ users.achievements trong GET /me (nếu /me chưa trả thì TODO), màn ăn mừng
    khi POST /workouts trả newAchievements (luồng tập đã có màn kết quả, chỉ thêm hiệu ứng).
Test cho mỗi màn với Fake repository. Báo cáo: màn + route, API còn thiếu, số test.
```

---

## Prompt cho Codex

```
Bạn đang ở nhánh feat/app-nutrition, không chuyển nhánh. Đọc AGENTS.md và docs/prompts/sprint3-app-handoff.md.
Chỉ sửa app/lib/features/nutrition/**, app/lib/features/progress/**, app/test/features/nutrition/**,
app/test/features/progress/**, và thêm route vào app/lib/app/router.dart (chỉ thêm, không sửa route khác —
Antigravity đang dựng thanh điều hướng, xung đột nhỏ Claude Code sẽ gộp). pubspec.yaml chỉ khi bắt buộc
(image_picker cho chụp ảnh, fl_chart cho biểu đồ là chấp nhận được).

Backend (đọc record Java trong backend/src/main/java/vn/levelup/nutrition/ và progress/):
- POST /meals/recognize JSON {imageBase64, mediaType, sha256} (ảnh nén ≤ 2 MB, tính sha256 trên máy),
  lỗi 413/415/429 PHOTO_LIMIT_REACHED/503 AI_UNAVAILABLE/502.
- GET /foods/search?q= (không dấu vẫn tìm được), POST /meals, GET /nutrition/today, POST /water,
  POST /measurements, GET /measurements?days=90.
Làm (F8 + Tiến độ):
1. /nutrition: hôm nay (mục tiêu, đã ăn, còn lại, macro, nước +250 ml, các bữa, gợi ý bữa tối nếu có).
2. Chụp món: chụp/chọn ảnh → nhận diện → sửa khẩu phần từng món (gram), món không khớp thì tìm thủ công
   → chọn bữa → lưu. AI chưa sẵn sàng (503) thì chuyển sang tìm thủ công, không chặn người dùng.
3. Thêm món thủ công qua tìm kiếm.
4. /progress: nhập cân/đo (cân nặng, eo, hông, ngực, tay), biểu đồ cân nặng và vòng eo 90 ngày, huy hiệu mới.
Ảnh chỉ gửi base64 trong request, không lưu file ra máy ngoài thư mục tạm. Test với Fake repository.
Báo cáo: màn + route, package thêm, số test.
```
