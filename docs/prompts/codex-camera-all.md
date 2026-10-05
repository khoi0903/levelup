# Prompt cho Codex – Đếm bằng camera cho 5 bài còn lại

Hiện 15/20 bài trong `mongo/seed/exercises.json` đã có cấu hình camera trong `mongo/cv-configs.json`
(bộ đếm `app/lib/features/camera_counter`, chế độ `reps` theo góc khớp lên/xuống và `hold` giữ trong dải góc).
5 bài chưa có vì cần kiểu đếm bộ đếm chưa hỗ trợ:

| slug | tracking | Vấn đề |
|---|---|---|
| `dead-bug` | reps | Duỗi tay chân **luân phiên** trái/phải; 1 lần = một bên duỗi rồi về |
| `bird-dog` | reps | Như trên, tư thế quỳ bốn điểm, camera đặt ngang |
| `march-in-place` | duration | Đi bộ tại chỗ: tính **thời gian đang chuyển động** (gối nâng xen kẽ), dừng thì dừng đồng hồ |
| `step-jack` | duration | Bước ngang + đưa tay: như trên |
| `dumbbell-floor-press` | reps_weight | Nằm ngửa trên sàn đẩy tạ: góc khuỷu, camera đặt thấp nhìn ngang |

App dùng bộ đếm qua `RepCountingSession` (app/lib/features/workout/data/camera/rep_counting_session.dart,
Antigravity phụ trách) với `CvConfig.fromJson` và `RepSnapshot` (count, isHold, holdDuration, holding…).
Giữ API hiện có tương thích để app không phải sửa nhiều.

---

```
Bạn đang ở nhánh feat/codex-camera-all (worktree D:\levelup-worktrees\codex-camera-all), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md, docs/prompts/codex-camera-all.md, app/lib/features/camera_counter/README.md.
Chỉ sửa app/lib/features/camera_counter/**, app/test/features/camera_counter/** (hoặc test hiện có của bộ đếm),
mongo/cv-configs.json. Không sửa app/lib khác, backend/, app/android/. Không chạy dart format cho cả thư mục.

1. Chế độ mới trong CvConfig (thêm vào CvMode, parse từ JSON, mặc định giữ nguyên hành vi cũ):
   a. `alternating` (reps): theo dõi hai bên (trái/phải) cùng một cặp khớp, đếm 1 khi MỘT bên đi hết chu kỳ
      flex/extend rồi về; hai bên làm xen kẽ. Có chống đếm kép khi hai bên cùng chuyển động, ngưỡng hysteresis
      như chế độ reps.
   b. `active` (duration): tính thời gian đang chuyển động: có chu kỳ (ví dụ gối trái/phải nâng xen kẽ, hoặc tay
      mở/đóng) trong cửa sổ ~2 giây gần nhất thì đồng hồ chạy, đứng yên thì dừng. Trả về như hold (holdDuration =
      tổng giây đang chuyển động, holding = đang chuyển động) để app hiện được như bài giữ.
2. mongo/cv-configs.json: thêm cấu hình cho 5 bài (cameraPosition, joints, ngưỡng góc, quy tắc tư thế cơ bản
   như các bài hiện có). dumbbell-floor-press dùng reps thường với góc khuỷu, cameraPosition "side",
   ghi chú đặt điện thoại thấp sát sàn.
3. Test thuần Dart với chuỗi pose giả (như test hiện có): alternating đếm đúng 6 lần cho 3 chu kỳ trái + 3 phải,
   không đếm khi chỉ rung nhẹ; active chạy đồng hồ khi có chu kỳ và dừng sau ~2 giây đứng yên; config mới parse
   được; 20/20 slug trong mongo/seed/exercises.json có cấu hình trong cv-configs.json (test đọc file JSON).
4. Cập nhật README.md của camera_counter (bảng chế độ, cách đặt camera cho từng bài mới).
5. flutter analyze sạch, flutter test qua hết. Commit trên feat/codex-camera-all, dạng
   "camera: chế độ alternating và active, cấu hình camera cho đủ 20 bài". Báo lại; Claude Code sẽ nạp lại
   cv-configs lên Atlas (mongo/setup-atlas.ps1) và Antigravity nối chế độ mới vào app nếu cần.
```
