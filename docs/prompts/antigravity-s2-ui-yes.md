# Prompt cho Antigravity – Sprint 2: đổi giao diện theo Figma trang "Yes"

Tạo worktree mới (Claude Code làm): `D:\levelup-worktrees\app-ui-yes`, nhánh `feat/app-ui-yes`.
Mở thư mục đó trong Antigravity, dán phần dưới.

---

Bạn đang ở nhánh `feat/app-ui-yes`, không chuyển nhánh. Đọc `AGENTS.md` trước.
Chỉ sửa trong `app/`, không đụng `app/lib/features/camera_counter/`, `backend/`, `mongo/`.

App đang dùng bảng màu cam cũ. Thiết kế đúng nằm ở **Figma trang "Yes"**:
https://www.figma.com/design/SPR387u9dcll7Ora7KH8b5/Untitled?node-id=68-263
Đọc qua Figma MCP (`get_design_context`, `get_screenshot`). Phong cách mới: nền gradient xanh tím,
thẻ kính mờ (trắng trong suốt + viền trắng + bóng xanh), bo góc lớn, font Plus Jakarta Sans.

## Bảng màu lấy từ màn F1 (node 68:264)
| Vai trò | Giá trị |
|---|---|
| Nền màn hình (gradient chéo ~172°) | `#DCE4FF` 0% → `#CBD6FD` 35% → `#A8B8F8` 70% → `#8CA0F2` 100% |
| Chữ chính / tiêu đề | `#171F45` |
| Chữ phụ | `#465381`; chữ mờ hơn `#56648E` |
| Màu nhấn (checkmark, nút chọn) | `#7084E8`; link `#4B63E8` |
| Thanh tiến độ | gradient `#8CA0F2` → `#7D93EC` → `#6D84E8`, rãnh trắng 40% |
| Thẻ đang chọn | nền trắng 65%, viền trắng 95%, bóng `rgba(92,107,214,0.22)` + viền ngoài `rgba(135,153,250,0.45)` 1.5px |
| Thẻ thường | nền trắng 4%, viền trắng 75%, bóng `rgba(79,93,172,0.14)` |
| Radio chưa chọn | nền trắng 20%, viền `rgba(199,210,254,0.8)` 2px |
| Nút chính | gradient `rgba(162,178,255,0.72)` → `rgba(135,153,250,0.8)`, viền trắng 75%, chữ trắng ExtraBold, bóng `rgba(78,93,201,0.4)` |
| Bo góc | thẻ 24, nút 16, chip/pill 9999 |

## Việc cần làm
1. Cập nhật `lib/core/constants/app_colors.dart` và `lib/app/theme.dart` theo bảng trên. Thêm token
   cho gradient nền, nền thẻ kính, bóng. Không hardcode màu trong từng màn hình; màn nào đang
   hardcode màu cam thì đổi sang token.
2. Font: dùng `google_fonts` (đã có) với Plus Jakarta Sans cho toàn app.
3. Tạo widget dùng chung: `GradientBackground`, `GlassCard` (có trạng thái selected),
   `PrimaryButton` kiểu mới, thanh tiến độ onboarding. Dùng `BackdropFilter` cho hiệu ứng mờ.
4. Áp vào các màn đã có: Bootstrap, 7 màn onboarding, OB-Plan, Home. Mỗi màn đối chiếu với frame
   tương ứng trên trang "Yes" (onboarding: các frame hàng đầu; Home: "F2 trang chủ" 68:892).
   Chỉ đổi giao diện, không đổi luồng, không đổi logic gọi API.
5. Màu `accent` xanh lá cũ không còn trong thiết kế mới: thay bằng màu nhấn mới, xóa token thừa.

## Kiểm tra trước khi báo xong
- `flutter analyze` sạch, `flutter test` đạt (sửa test nếu chỉ đổi màu/style, không xóa test).
- `flutter build web` rồi chụp màn hình F1 và Home, đặt cạnh ảnh Figma tương ứng trong báo cáo.
- Commit trên nhánh, không merge vào `main`.
