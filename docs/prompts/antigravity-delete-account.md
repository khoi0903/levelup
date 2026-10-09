# Prompt cho Antigravity – Xoá tài khoản (Google Play) + báo buổi tập gửi trễ

Google Play bắt buộc app có chức năng xoá tài khoản ngay trong ứng dụng.

Backend (Claude Code, PR feat/be-delete-account):
- `DELETE /me` body `{"confirm": true}` → 204. Xoá vĩnh viễn tài khoản Firebase và toàn bộ dữ liệu (kế hoạch,
  buổi tập, check-in, bữa ăn, coach, buddy...). Thiếu `confirm: true` → 400 VALIDATION_ERROR. Không hoàn tác được.
- Trang web công khai: `<API_BASE_URL>/privacy.html` (chính sách quyền riêng tư) và
  `<API_BASE_URL>/delete-account.html` (hướng dẫn xoá). Hướng dẫn ghi: "Tôi → kéo xuống cuối → Xoá tài khoản".

Thêm: buổi tập bắt đầu quá 24 giờ trước giờ máy chủ (nháp offline gửi trễ) vẫn được lưu nhưng backend trả
`countsForStreak: false` → app chưa giải thích gì.

```
Bạn đang ở nhánh feat/app-delete-account (worktree D:\levelup-worktrees\app-delete), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-delete-account.md.
Chỉ sửa app/lib, app/test. Không dart format cả thư mục. Màu theo app_colors.dart.

1. Tab Tôi (profile_screen), cuối màn, dưới nút "Đăng xuất": mục "Xoá tài khoản" (chữ màu lỗi/đỏ, icon
   delete_forever), tách khỏi các cài đặt khác.
   - Bấm → dialog 1: tiêu đề "Xoá tài khoản?", nội dung liệt kê ngắn dữ liệu bị xoá (hồ sơ, lịch sử tập, bữa ăn,
     tin nhắn coach, streak, bạn tập) và "Không thể hoàn tác". Nút "Huỷ" / "Tiếp tục".
   - Dialog 2: yêu cầu gõ chữ XOÁ (chấp nhận cả XOA, không phân biệt hoa thường) mới bật nút "Xoá vĩnh viễn".
   - Gọi DELETE /me {"confirm": true} (UserRepository.deleteAccount). Đang xoá: chặn bấm, vòng tải.
   - Thành công: xoá dữ liệu trên máy (drift: nháp buổi tập; shared_preferences của app; giọng đọc/camera giữ
     cũng được), đăng xuất Firebase, về màn đăng nhập, SnackBar "Đã xoá tài khoản".
   - Lỗi: mapErrorMessage, giữ nguyên đăng nhập.
   - Link nhỏ "Chính sách quyền riêng tư" trong tab Tôi mở `<API_BASE_URL>/privacy.html` (url_launcher nếu đã có,
     không có thì dùng gói đã có trong pubspec; không thêm gói nặng).
2. Màn kết quả buổi tập (workout_result_screen): khi countsForStreak == false VÀ thời lượng ≥ 5 phút (tức bị loại
   vì gửi trễ), hiện dòng giải thích: "Buổi tập đã lưu nhưng không tính vào chỉ tiêu tuần vì gửi lên quá 24 giờ
   sau khi tập". Buổi dưới 5 phút giữ câu cũ.
3. Test (repository giả): luồng xoá đủ 2 bước gọi đúng DELETE /me {"confirm":true} rồi về màn đăng nhập; gõ sai chữ
   thì nút bị khoá; lỗi API giữ đăng nhập; màn kết quả hiện dòng gửi trễ đúng điều kiện.
   flutter analyze sạch, flutter test --concurrency=2 qua hết.
4. Commit "app: xoá tài khoản trong tab Tôi, báo buổi tập gửi trễ". Báo Claude Code review.
```
