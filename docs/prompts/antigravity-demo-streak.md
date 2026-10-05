# Prompt cho Antigravity – Màn giả lập demo, chi tiết tuần streak, sửa lịch sử streak

Backend đã có sẵn (đừng sửa backend):

**1. `GET /streak`** – `weeks` giờ chỉ bắt đầu từ tuần đầu tiên người dùng có dữ liệu (người mới chỉ có tuần này).
Trạng thái tuần `status`: `achieved` | `missed` | `frozen` | `in_progress` | `none` (tuần không có dữ liệu, ví dụ
bỏ app một tuần). **Lỗi hiện tại:** app hiển thị `none` thành "Đang diễn ra · 0/0 buổi".

**2. `GET /streak/weeks/{date}`** – chi tiết một tuần (date bất kỳ trong tuần, tự đưa về Thứ Hai):
```json
{ "weekStart": "2026-10-05", "status": "in_progress", "targetSessions": 2, "completedSessions": 1,
  "days": [
    { "date": "2026-10-05", "weekday": 1,
      "sessions": [ { "id": "…", "title": "Toàn thân cơ bản", "scheduledTime": "18:30", "durationMin": 15,
                      "status": "planned|completed|skipped|rescheduled|rest" } ],
      "workouts": [ { "id": "…", "startedAt": "2026-10-05T11:20:00Z", "durationMin": 12,
                      "countsForStreak": true, "plannedSessionId": "…|null (tập thêm)" } ] },
    … 7 ngày, weekday 1 = Thứ Hai … 7 = Chủ nhật ] }
```
400 `INVALID_DATE` nếu date sai định dạng.

**3. `POST /demo/{action}`** – nút giả lập, chỉ chạy với tài khoản demo (server bật `DEMO_MODE`, uid nằm trong
`DEMO_UIDS`); tài khoản khác nhận **404**. Trả `{ "action": "...", "result": { ... } }`.

| action | Làm gì | result |
|---|---|---|
| `seed` | Nạp lịch sử 4 tuần: 9 buổi, streak 3 tuần, 1 kỷ lục, cân nặng 4 tuần, 21 bữa ăn 7 ngày trước. Chạy lại về đúng trạng thái ban đầu | `workouts`, `currentWeeks`, `measurements`, `meals` |
| `skip-two` | Đánh dấu 2 buổi gần nhất là bỏ → coach hỏi lý do, gửi thông báo | `skipped`, `notified` |
| `close-week` | Chốt tuần ngay | `closed`, `status`, `currentWeeks`, `newAchievements` |
| `review` | Tạo tổng kết tuần (AI) | `listeners` |
| `checkin` | Gửi thông báo check-in sáng ngay | `result`: `SENT` / `STORED_ONLY` (máy chưa đăng ký nhận thông báo) / `QUIET_HOURS` / `DAILY_LIMIT` |
| `push-test` | Gửi một thông báo thử | như trên |

---

```
Bạn đang ở nhánh feat/app-demo (worktree D:\levelup-worktrees\app-demo), không chuyển nhánh, không merge vào main.
Đọc AGENTS.md và docs/prompts/antigravity-demo-streak.md. Chỉ sửa app/ (không camera_counter/, backend/, mongo/).
Màu theo app_colors.dart, bố cục theo Figma trang "Yes". Không chạy dart format cho cả thư mục, chỉ file bạn sửa.

1. Màn Chuỗi tuần (Streak), lịch sử 8 tuần:
   - Trạng thái `none` hiển thị "Không có dữ liệu" (màu xám, icon trống), KHÔNG phải "Đang diễn ra".
     Chỉ `in_progress` mới là "Đang diễn ra". `achieved` = "Đạt", `missed` = "Chưa đạt", `frozen` = "Dùng thẻ đóng băng".
   - Tuần hiển thị dạng "Tuần 05/10 – 11/10" thay vì "Tuần bắt đầu 2026-10-05". Tuần mới nhất ở trên cùng.
   - Bấm vào một tuần → màn Chi tiết tuần (route mới, ví dụ /streak/week/:weekStart).

2. Màn Chi tiết tuần (GET /streak/weeks/{weekStart}):
   - Đầu màn: tuần, trạng thái, "x/y buổi".
   - 7 dòng Thứ Hai → Chủ nhật, mỗi dòng: thứ + ngày; các buổi trong kế hoạch (tên, giờ, trạng thái: đã tập ✓,
     bỏ, chưa tập, nghỉ); các buổi đã tập (giờ bắt đầu, số phút; plannedSessionId null thì ghi "Tập thêm";
     countsForStreak false thì ghi "dưới 5 phút, không tính streak"). Ngày không có gì: "Nghỉ".
   - Hôm nay được làm nổi bật. Có trạng thái đang tải, lỗi (mapErrorMessage, nút thử lại).

3. Màn giả lập demo (ẩn):
   - Mở bằng cách chạm 5 lần liên tiếp (trong 3 giây) vào logo/tiêu đề ở đầu Trang chủ. Route /demo.
   - Các nút, mỗi nút gọi POST /demo/{action}, hiện đang chạy và kết quả bằng câu tiếng Việt dễ hiểu:
     "Nạp dữ liệu demo" (seed), "Giả lập bỏ 2 buổi" (skip-two), "Chốt tuần ngay" (close-week),
     "Tạo tổng kết tuần" (review), "Gửi check-in sáng" (checkin), "Gửi thông báo thử" (push-test).
   - Với checkin / push-test: SENT → "Đã gửi, xem thanh thông báo"; STORED_ONLY → "Máy này chưa đăng ký nhận
     thông báo"; QUIET_HOURS → "Đang giờ yên lặng, sẽ gửi lúc 07:00"; DAILY_LIMIT → "Hết lượt thông báo hôm nay".
   - 404 → "Tài khoản này chưa bật chế độ demo" (hiện ngay trên màn, không văng lỗi).
   - Sau mỗi nút thành công: invalidate các provider liên quan (streak, plan hiện tại, home, nutrition, progress)
     để quay lại các tab thấy dữ liệu mới ngay.

4. Onboarding màn đầu (chọn mục tiêu / nhập tên): thêm dòng nhỏ "Đang đăng nhập: <email> · Đổi tài khoản".
   Bấm "Đổi tài khoản" → đăng xuất (giống nút Đăng xuất ở Cài đặt, có xóa FCM token) và về màn đăng nhập.
   Lý do: tài khoản Firebase có rồi nhưng database mới chưa có hồ sơ thì app vào thẳng onboarding, người dùng
   không biết đang dùng tài khoản nào.

5. Test (flutter test, dùng repository giả như các test hiện có):
   - map trạng thái tuần (none không ra "Đang diễn ra"), định dạng nhãn tuần.
   - Chi tiết tuần: 7 dòng, buổi tập thêm, ngày nghỉ.
   - Màn demo: chạm 5 lần mở màn; nút gọi đúng action; 404 hiện câu "chưa bật chế độ demo"; STORED_ONLY hiện đúng câu.
   - Onboarding hiện email và nút Đổi tài khoản gọi signOut.
   flutter analyze sạch, flutter test qua hết.

6. Commit trên feat/app-demo, dạng "app: màn giả lập demo, chi tiết tuần streak". Báo lại để Claude Code review.
```
