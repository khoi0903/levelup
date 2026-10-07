# Prompt cho Antigravity – Đổi bài không thích (feedback người test)

Feedback: "có bài mình không thích thì thay bằng bài khác", "coach gợi ý bài tương tự", "không thích mấy bài này thì có
option khác không, chuẩn bị đi tập luôn".

Backend (Claude Code, nhánh feat/be-swap-exercise, sẽ có trên Render):

- `GET /plans/sessions/{sessionId}/alternatives?exerciseId=<bài muốn đổi>` → tối đa 6 bài, đã sắp xếp:
  ```json
  [ { "exerciseId": "…", "nameVi": "Squat ôm tạ", "primaryMuscle": "legs", "tracking": "reps",
      "cameraSupported": true, "reason": "Cùng nhóm cơ · Không cần dụng cụ · Đếm được bằng camera" } ]
  ```
  Chỉ bài an toàn với người dùng (nơi tập, dụng cụ, chấn thương), chưa có trong buổi, chưa bị "không gợi ý nữa".
- `POST /plans/sessions/{sessionId}/swap` body `{"fromExerciseId": "…", "toExerciseId": "…", "remember": true|false}`
  → trả PlanView (kế hoạch tuần đã cập nhật). `remember: true` = "Không gợi ý bài này nữa" (tuần sau không xếp lại).
  Lỗi: 400 `EXERCISE_NOT_ALLOWED` / `EXERCISE_NOT_IN_SESSION`, 409 `SESSION_NOT_PLANNED` (buổi đã tập/đã bỏ), 404.
- Chỉ buổi còn `planned` trong lịch mới đổi được. Buổi "Tập thêm" (id `extra-…`) không gọi backend: đổi ngay trên máy.

---

```
Bạn đang ở nhánh feat/app-swap-exercise (worktree D:\levelup-worktrees\app-swap), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-swap-exercise.md.
Chỉ sửa app/lib, app/test. Không dart format cả thư mục.

1. Màn bắt đầu buổi (workout_start_screen): mỗi dòng bài có nút "Đổi" (icon ⇄). Bấm → bottom sheet
   "Đổi bài <tên>":
   - Danh sách bài thay thế từ GET …/alternatives: ảnh mẫu (ExerciseImage), tên, dòng reason, nhãn "Camera"
     nếu cameraSupported. Đang tải: skeleton; lỗi: mapErrorMessage + thử lại; rỗng: "Chưa có bài thay thế phù hợp".
   - Ô tích "Không gợi ý bài này nữa" (mặc định tắt).
   - Chọn một bài → POST …/swap → cập nhật buổi đang xem (invalidate plan/home/workout setup), SnackBar
     "Đã đổi <cũ> → <mới>". 409 SESSION_NOT_PLANNED → "Buổi này đã tập hoặc đã bỏ, không đổi được nữa".
   - Nút cuối sheet "Hỏi coach gợi ý thêm" → mở tab Coach với câu soạn sẵn
     "Mình không thích bài <tên>, gợi ý bài khác cùng nhóm cơ giúp mình" (chưa gửi, người dùng bấm gửi).
2. Buổi tập thêm (id extra-…): nút "Đổi" vẫn có; danh sách lấy từ GET /exercises (cùng primaryMuscle trước,
   bỏ bài đã có trong buổi), đổi ngay trong bộ nhớ, không gọi backend, không có ô "không gợi ý nữa".
3. Màn đang tập (workout_active_screen): nút "Đổi bài này" nhỏ cạnh tên bài, chỉ hiện khi bài hiện tại CHƯA có
   hiệp nào được ghi; dùng cùng bottom sheet; đổi xong cập nhật item hiện tại trong WorkoutSessionState
   (và draft drift), giữ số hiệp, mục tiêu theo kiểu đếm của bài mới.
4. Test (repository giả): mở sheet hiện danh sách; chọn bài gọi swap đúng from/to/remember; 409 hiện câu đúng;
   buổi extra đổi trong máy không gọi API; màn đang tập ẩn nút khi đã ghi hiệp. flutter analyze sạch,
   flutter test qua hết.
5. Commit "app: đổi bài không thích, gợi ý bài tương tự". Báo Claude Code review.
```
