# Bàn giao Claude Code review – LevelUp Pro

Nhánh `feat/codex-pro-plan`, worktree `D:\levelup-worktrees\codex-pro`. Chưa merge vào main.

- Pro và giới thiệu tắt mặc định. Tắt Pro vẫn dùng giới hạn YAML (coach 30, ảnh 10) cho mọi tài khoản.
- `ProductConfigService` cache 5 giây; Admin lưu thành công thì vô hiệu hoá cache ngay sau commit.
  Instance khác thấy cấu hình mới trong tối đa 5 giây. Version ngăn Admin lưu đè cấu hình cũ.
- `PlanAccess` dùng giờ máy chủ. `/me` bổ sung subscription, isAdmin, productConfig, createdAt,
  referralRedeemEligible (cửa sổ 7 ngày và chưa từng nhập mã đều do backend quyết định).
- Webhook dùng một security chain riêng để Authorization secret không bị hiểu thành Firebase JWT.
  Event ledger và plan cùng transaction; retry khi xung đột Mongo; timestamp ngăn sự kiện cũ ghi đè sự kiện mới.
- Referral, ledger mốc và ngày Pro cùng transaction với buổi tập đạt countsForStreak.
  Gửi thông báo sau commit qua NotificationGateway; dedupeKey theo referral id.
- Admin dùng DEMO_UIDS, độc lập DEMO_MODE. Endpoint demo giữ điều kiện cũ. Thay đổi cấu hình/cấp Pro có audit.
- App dùng FakeBillingService, chỉ báo “Sắp ra mắt”; không thêm SDK mua hàng. Pro chỉ xuất hiện khi enabled.
  Link mời mở trang sao chép mã trên chính backend; chưa tích hợp universal/app links.

Biến môi trường mới: `REVENUECAT_WEBHOOK_SECRET`. Giá trị phải khớp **toàn bộ** header Authorization cấu hình
trong RevenueCat; nếu dashboard dùng `Bearer ...` thì secret cũng bao gồm tiền tố đó. Trống luôn trả 401.
Không thêm biến bật Pro; bật/tắt bằng Admin sau review.

Collection mới (ProductIndexes tạo trên cả DB hiện có, không cần reset):
`app_config`, `billing_events`, `referrals`, `referral_rewards`, `admin_audit`.
Index unique: billing_events.eventId, referrals.inviteeId, referral_rewards(referrerId,friends),
users.referralCode (partial, chỉ document có chuỗi referralCode).
Validator users hiện cho phép trường bổ sung nên không cần sửa mongo/init.js.

Kiểm tra trước bàn giao:

```powershell
cd backend
.\mvnw.cmd test
cd ..\app
flutter analyze
flutter test --concurrency=2
```

Test mới bao phủ giới hạn free/pro/tắt Pro/giới hạn 0, secret sai/trống, mua/hết hạn/huỷ/gia hạn,
webhook lặp và đồng thời, mã sai/của mình/quá hạn/đã nhập, buổi 299/300 giây,
thưởng nhiều mốc không trùng, Admin 404/validation/audit/version/cấp thủ công,
widget ẩn/hiện Pro/giới thiệu, quota coach/ảnh, lỗi mã và sửa/lưu mốc Admin.

Nhờ Claude Code review commit trước khi merge. Chưa bật bán hoặc kết nối RevenueCat thật.
