# Prompt cho Antigravity – Màn "Tập thêm" cho người dùng chọn (làm tiếp trên feat/app-offline-coach)

Lỗi hiện tại: Trang chủ và tab Tập bấm "Tập thêm" thì app mở buổi kế tiếp trong lịch (thường là buổi ngày mai).
Người dùng không được chọn gì.

Backend đã sẵn (không sửa backend):
- `POST /workouts` không có `plannedSessionId` = buổi tập thêm: lưu log, không đánh dấu lịch, vẫn tính streak
  nếu `durationSec >= 300`. Bài tùy ý (`sets[].exerciseId`).
- `GET /exercises` – thư viện bài (nameVi, primaryMuscle, equipment, tracking reps|duration, difficulty,
  contraindications, cv…). `GET /me` – profile (location, equipment, injuries trong hồ sơ nếu có).
- App đã có: `plannedSessionId` chỉ gửi khi id là ObjectId của buổi trong lịch (workout_session_state.dart) →
  buổi tạo trên máy dùng id dạng "extra-<uuid>" sẽ tự là tập thêm.

---

```
Tiếp tục trên nhánh feat/app-offline-coach (worktree D:\levelup-worktrees\app-offline-coach), SAU khi xong phần
drift + coach stream. Không chuyển nhánh, không merge vào main. Đọc docs/prompts/antigravity-extra-workout.md.
Chỉ sửa app/lib, app/test. Không chạy dart format cho cả thư mục.

1. Màn "Tập thêm" (route /workout/extra), mở từ mọi nút "Tập thêm" (Trang chủ khi buổi hôm nay đã xong hoặc
   buổi kế tiếp ở ngày sau, tab Tập, màn kết quả buổi tập). Bỏ việc mở buổi của ngày khác.
   a. Buổi gợi ý nhanh (thẻ): "5 phút nhanh", "Toàn thân", "Chân & mông", "Tay & vai", "Bụng (core)".
      Ghép 3–5 bài từ GET /exercises theo primaryMuscle, chỉ bài isActive, hợp nơi tập (home/gym) và dụng cụ của
      người dùng, bỏ bài có contraindications trùng chấn thương. Mặc định 2–3 hiệp, số lần/thời gian theo
      difficulty. Hàm ghép là hàm thuần có test.
   b. Tự chọn bài: danh sách bài (ô tìm theo tên không dấu, lọc nhóm cơ), tích chọn, mỗi bài chỉnh số hiệp và
      số lần hoặc số giây (bài tracking duration). Nút "Bắt đầu (n bài)".
   c. "Tập lại buổi hôm nay" nếu hôm nay đã có buổi trong lịch đã hoàn thành.
2. Bắt đầu → dựng SessionView tạm (id "extra-<uuid>", title theo lựa chọn, items đã chọn) và đi vào đúng luồng
   tập hiện có (màn bắt đầu, đếm camera, nghỉ, kết thúc, lưu offline bằng drift). Màn kết quả ghi "Buổi tập thêm".
3. Trang chủ: nút chính khi hôm nay không có buổi / buổi kế tiếp ở ngày sau ghi "Tập thêm" và mở màn ở mục 1;
   vẫn hiện thông tin buổi kế tiếp (thứ, giờ) chỉ để xem.
4. Test: hàm ghép buổi gợi ý (lọc nơi tập, dụng cụ, chấn thương, đủ 3–5 bài), tự chọn bài → bắt đầu → POST
   /workouts không có plannedSessionId, nút "Tập thêm" không mở buổi ngày mai.
5. Commit riêng trên cùng nhánh: "app: màn Tập thêm cho chọn buổi gợi ý hoặc tự chọn bài". Báo lại để review.
```
