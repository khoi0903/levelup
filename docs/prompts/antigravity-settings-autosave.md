# Prompt cho Antigravity – Cài đặt tự lưu + đổi nơi tập & dụng cụ

Feedback người dùng (2026-10-07):
1. "Nút lưu không có tác dụng gì cho lắm: thay đổi gì đó, qua trang khác rồi về cài đặt thì chỗ sửa vẫn được sửa."
   Nguyên nhân: `profile_screen.dart` là tab (giữ state khi đổi tab), sửa xong chưa bấm "Lưu cài đặt" vẫn hiện giá trị
   mới → tưởng đã lưu; `_initFields` chỉ đọc server một lần. Màn còn trộn hai kiểu: giọng đọc / tự mở camera lưu ngay,
   các mục khác phải bấm Lưu.
2. Sau onboarding không đổi được nơi tập và dụng cụ → tập thêm chỉ có 14/20 bài, mua tạ cũng không mở được bài tạ.

Backend (Claude Code, PR feat/be-settings-equipment): `PATCH /me` nhận thêm
`{"location": "home|gym|outdoor", "equipment": ["dumbbell","mat","resistance_band","pullup_bar"]}`
(`[]` = không dụng cụ, không gửi = giữ nguyên). `GET /me` đã có `profile.location`, `profile.equipment`. Có hiệu lực
ngay với bài gợi ý / tập thêm / đổi bài; lịch tuần đang tập giữ nguyên, tuần sau xếp theo dụng cụ mới.

```
Bạn đang ở nhánh feat/app-settings-autosave (worktree D:\levelup-worktrees\app-settings), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-settings-autosave.md.
Chỉ sửa app/lib, app/test. Không dart format cả thư mục. Màu theo app_colors.dart.

1. Tự lưu: mỗi thay đổi ở màn Hồ sơ & Cài đặt gửi ngay PATCH /me chỉ với trường vừa đổi (công tắc, chip, +/-
   lưu ngay; ô tên lưu khi bấm Xong trên bàn phím hoặc rời ô, không rỗng). Bỏ nút "Lưu cài đặt".
   - Thành công: SnackBar ngắn "Đã lưu", cập nhật userStatusFutureProvider để màn khác thấy giá trị mới.
   - Lỗi: hoàn tác về giá trị cũ trên giao diện + SnackBar mapErrorMessage. Đổi nhanh nhiều lần: không gửi chồng
     (gộp hoặc gửi tuần tự), giá trị cuối cùng thắng.
   - Lịch rảnh (thứ + khung giờ): giữ một nút "Lưu lịch tập" riêng vì phải chọn nhiều ô, hoặc tự lưu sau 1 giây
     không bấm thêm; ghi chú nhỏ "Áp dụng từ tuần sau".
   - Đổi mục tiêu: hỏi xác nhận trước ("Mục tiêu calo sẽ tính lại từ hôm nay") rồi mới lưu.
   - Mở lại tab luôn hiện đúng giá trị trên server (không giữ giá trị chưa lưu).
2. Mục mới "Nơi tập & dụng cụ" trong tab Tôi: chọn Ở nhà / Phòng gym / Ngoài trời, và dụng cụ đang có
   (Tạ đơn, Thảm, Dây kháng lực, Xà đơn) giống bước onboarding (dùng lại widget nếu được). Tự lưu như mục 1.
   Phòng gym: ẩn danh sách dụng cụ, ghi "Phòng gym có đủ dụng cụ". Lưu xong invalidate danh sách bài tập
   (GET /exercises) để màn Tập thêm thấy bài mới ngay. Ghi chú: "Lịch tuần này giữ nguyên, tuần sau xếp theo dụng cụ mới".
3. Test (repository giả): đổi công tắc gửi đúng PATCH chỉ một trường; lỗi thì hoàn tác; rời tab rồi quay lại hiện
   giá trị server; đổi dụng cụ gửi {"equipment":[...]} và màn Tập thêm thấy thêm bài; chọn gym gửi {"location":"gym"}.
   flutter analyze sạch, flutter test --concurrency=2 qua hết.
4. Commit "app: cài đặt tự lưu, đổi nơi tập và dụng cụ". Báo Claude Code review.
```
