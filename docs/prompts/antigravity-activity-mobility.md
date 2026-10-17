# Prompt cho Antigravity – Gửi Health Connect lên server + dùng bài giãn cơ

Hiện tại số bước và calo vận động từ Health Connect chỉ hiện trên thẻ ở Trang chủ, không gửi đi đâu.

Backend (Claude Code, nhánh feat/be-activity):
- `POST /activity/today` body `{"localDate":"YYYY-MM-DD","steps":5200,"activeKcal":180}` → 200
  `{"localDate","steps","activeKcal","stored"}`. localDate = ngày điện thoại đã đọc (0h tới lúc gửi); máy chủ chỉ lưu
  khi trùng hôm nay của máy chủ (`stored:false` thì bỏ qua, không báo lỗi). Số chỉ tăng (gửi số nhỏ hơn không giảm).
  steps 0–200000, activeKcal 0–10000, sai → 400.
- `GET /nutrition/today` thêm `steps`, `activeKcal` (0 khi chưa kết nối) và `totalBurnedKcal` = max(burnedKcal của
  buổi tập trong app, activeKcal) để không cộng trùng. Chỉ để xem: mục tiêu ăn KHÔNG tăng theo vận động.
- AI coach tự biết số bước / calo vận động hôm nay (không cần app làm gì).
- Bài giãn cơ: `GET /exercises` sẽ có thêm bài `primaryMuscle: "mobility"` (Codex nạp sau). Backend không xếp
  chúng vào kế hoạch.

```
Bạn đang ở nhánh feat/app-activity (worktree D:\levelup-worktrees\app-activity), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-activity-mobility.md.
Chỉ sửa app/lib, app/test. Không dart format cả thư mục. Màu theo app_colors.dart.

1. Health Connect → server: sau mỗi lần healthConnectControllerProvider đọc được số liệu (mở Trang chủ, kéo làm
   mới, quay lại app) và đã cấp quyền, gọi POST /activity/today với localDate = /me.localDate nếu trùng ngày trên
   điện thoại, ngược lại dùng ngày điện thoại (server tự bỏ qua nếu lệch). Tối đa 1 lần / 15 phút, chỉ gửi khi số
   liệu tăng so với lần gửi trước (lưu tạm trong bộ nhớ hoặc shared_preferences). Lỗi mạng: bỏ qua im lặng, không
   SnackBar. Không gửi gì khi chưa kết nối Health Connect / web / iOS.
2. Màn Dinh dưỡng (nutrition_screen): chỗ đang hiện burnedKcal, đổi thành dùng totalBurnedKcal, thêm dòng nhỏ
   "· <steps> bước" khi steps > 0. Chú thích nhỏ: "Calo vận động chỉ để tham khảo, mục tiêu ăn giữ nguyên".
   Model NutritionToday thêm steps, activeKcal, totalBurnedKcal (mặc định 0, đọc thiếu trường không lỗi).
3. Bài giãn cơ (primaryMuscle == "mobility"):
   - extra_workout_builder: các gợi ý thường (5 phút, Toàn thân, Chân & mông, Tay & vai...) và tab Tự chọn mặc
     định KHÔNG lấy bài mobility (tab Tự chọn có chip lọc "Giãn cơ" để xem riêng).
   - light10: nếu có ≥ 3 bài mobility an toàn (đã lọc vùng đau) thì đổi tên hiển thị thành "Giãn cơ 10 phút",
     dùng 5–6 bài mobility, mỗi bài 1 hiệp 30–45 giây, nghỉ 10 giây; không đủ thì giữ "Bản nhẹ 10 phút" như hiện tại.
   - Màn tập: bài mobility tracking duration chạy đồng hồ như bài duration khác, không mở camera.
4. Test (repository giả): gửi activity đúng body, không gửi lại khi số không tăng, lỗi mạng không hiện lỗi; màn
   Dinh dưỡng hiện totalBurnedKcal và số bước; gợi ý thường không chứa bài mobility; có ≥ 3 bài mobility thì hiện
   "Giãn cơ 10 phút". flutter analyze sạch, flutter test --concurrency=2 qua hết.
5. Commit "app: gửi Health Connect lên server, calo vận động ở Dinh dưỡng, giãn cơ 10 phút". Báo Claude Code review.
```
