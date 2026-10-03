# Prompt cho Antigravity – sửa sau review Sprint 1

Tạo worktree mới (Claude Code hoặc bạn chạy trong `D:\fitness-app`):
```
git worktree add -b fix/app-s1-review D:\levelup-worktrees\app-fix main
```
Mở `D:\levelup-worktrees\app-fix` trong Antigravity, dán phần dưới.

---

Bạn đang ở nhánh `fix/app-s1-review`, không chuyển nhánh. Đọc `AGENTS.md` trước.
Chỉ sửa trong `app/`, không đụng `app/lib/features/camera_counter/`.

Review của Claude Code cho Sprint 1 phát hiện 3 lỗi, sửa theo thứ tự:

1. **Bỏ dữ liệu mẫu khỏi giá trị mặc định** trong `OnboardingState`
   (`lib/features/onboarding/domain/models/onboarding_models.dart`).
   Hiện đang điền sẵn: đau lưng dưới, tạ đơn + thảm, Thứ 2/4/6, câu "sơ mi trước Tết"...
   Người dùng thật bấm "Tiếp tục" liên tục sẽ gửi lên server rằng mình bị đau lưng.
   - Mọi lựa chọn mặc định rỗng hoặc null. Màn nào bắt buộc chọn thì nút "Tiếp tục" bị
     vô hiệu cho tới khi chọn đủ (mục tiêu, kinh nghiệm, nơi tập, ít nhất 1 ngày rảnh,
     khung giờ, thời lượng, phong cách coach; chiều cao và cân nặng hợp lệ).
   - Dữ liệu mẫu chỉ dùng trong test.

2. **Dụng cụ lưu bằng mã, không lưu chữ tiếng Việt.** Đổi `equipment` thành enum
   `Equipment { dumbbell, mat, resistance_band, pullup_bar }`, nhãn tiếng Việt lấy từ
   `app_strings.dart`. Lựa chọn "Không có" nghĩa là danh sách rỗng.
   Backend chỉ nhận đúng các mã này (xem `backend/.../onboarding/OnboardingRequest.java`).

3. **Ảnh chụp màn hình trong `app/screenshots/` đang hiện chữ thành ô vuông** (font giả của
   môi trường test). Xóa thư mục này và test `screenshot_test.dart`. Khi cần ảnh để so với
   Figma, chạy app thật (`flutter run -d chrome`) rồi chụp.

**Chưa đổi màu sắc.** Màu sẽ cập nhật theo Figma khi đã kết nối được Figma MCP; khi đó
chỉ cần sửa `lib/core/constants/app_colors.dart` và `lib/app/theme.dart`.

Kiểm tra trước khi báo xong: `flutter analyze` sạch, `flutter test` đạt, thêm widget test:
nút "Tiếp tục" ở màn mục tiêu bị vô hiệu khi chưa chọn gì.
