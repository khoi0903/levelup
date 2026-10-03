# Prompt cho Antigravity – Sprint 2: bảng màu dịu mắt (bản B)

Worktree (Claude Code tạo sẵn): `D:\levelup-worktrees\app-ui-soft`, nhánh `feat/app-ui-soft`.
Mở thư mục đó trong Antigravity, dán phần dưới.

So sánh hai bản team đã chọn: https://claude.ai/artifact/Erm3nzHg14bD6Vs7d7kcGY (team chọn **B**).

---

Bạn đang ở nhánh `feat/app-ui-soft`, không chuyển nhánh. Đọc `AGENTS.md` trước.
Chỉ sửa trong `app/`, không đụng `app/lib/features/camera_counter/`, `backend/`, `mongo/`.

Team thấy bảng màu Figma trang "Yes" chói và chữ khó đọc (chữ trắng trên nút chỉ đạt ~2.5:1,
chữ phụ ~3:1, chuẩn là 4.5:1). Giữ nguyên bố cục, font Plus Jakarta Sans, bo góc, chữ tiêu đề
`#171F45`; chỉ đổi màu và độ trong suốt theo bảng dưới.

## Bảng màu mới
| Token trong `app_colors.dart` | Cũ | Mới |
|---|---|---|
| `screenGradient` | chéo 172°, `#DCE4FF`→`#8CA0F2` | dọc: `#E4E9FF` 0% → `#F4F6FF` 38% → `#F7F8FC` 100% |
| `background` | `#DCE4FF` | `#F4F6FF` |
| `textSecondary` | `#465381` | `#3A4570` |
| `textMuted` | `#56648E` | `#3A4570` (gộp với textSecondary, xóa token thừa) |
| `primary` / `accent` | `#7084E8` | `#4B63E8` |
| `accentLink` | `#4B63E8` | `#3B52D9` |
| Nút chính | gradient trong suốt + viền trắng | màu đặc `#4B63E8`, không viền, chữ trắng, bóng `rgba(75,99,232,0.55)` blur 20 offset y 8 |
| Thanh tiến độ | gradient, rãnh trắng 40% | màu đặc `#4B63E8`, rãnh `#E1E6F8` |
| Thẻ thường | trắng 4%, viền trắng 75% | trắng đặc `#FFFFFF`, viền `#DDE3F7` 1px, bóng `rgba(40,53,105,0.12)` blur 14 |
| Thẻ đang chọn | trắng 65%, viền trắng | nền `#F5F7FF`, viền `#4B63E8` 1.5px, bóng `rgba(75,99,232,0.28)` blur 18 |
| Radio chưa chọn | trắng 20%, viền `#C7D2FE` 80% | nền trắng, viền `#C4CCEB` 2px |
| Chip `1/7`, nút phụ | kính mờ | nền trắng, viền `#DDE3F7`, chữ `#3A4570` |
| `surface` / `border` | trắng trong suốt | `#FFFFFF` / `#DDE3F7` |

## Việc cần làm
1. Đổi `lib/core/constants/app_colors.dart` theo bảng. Xóa các token không còn dùng
   (bgGradient2–4 kiểu cũ, btnGradient*, progressGradient*, cardNormalBg trong suốt...).
2. Bỏ `BackdropFilter` (hiệu ứng kính) trong `GlassCard`, `OnboardingHeader`, `SecondaryButton`:
   thẻ giờ là nền đặc nên không cần làm mờ, còn đỡ tốn pin. Có thể đổi tên `GlassCard` → `AppCard`.
3. Màn hình không được hardcode màu; chỉ dùng token.
4. Kiểm tra mọi màn đã có (Bootstrap, 7 màn onboarding, OB-Plan, Home): chữ phụ, link, chữ trên nút
   đều đọc rõ trên nền mới.

## Kiểm tra trước khi báo xong
- `flutter analyze` sạch, `flutter test` đạt.
- `flutter build web`, chụp F1 và Home, đặt cạnh bản B trong link so sánh ở trên.
- Commit trên nhánh, không merge vào `main`.
