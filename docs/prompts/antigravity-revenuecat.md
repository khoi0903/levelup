# Prompt cho Antigravity – Mua gói Pro thật bằng RevenueCat

Backend đã sẵn (PR #57 + feat/be-activity):
- `POST /billing/revenuecat/webhook` (header `Authorization` = `REVENUECAT_WEBHOOK_SECRET` trên Render) cập nhật
  `users.plan` theo `app_user_id` = **Firebase UID**. Sự kiện RevenueCat chỉ đổi hạn trả tiền; ngày Pro được tặng
  (giới thiệu, admin) giữ riêng, hạn thực tế là hạn xa hơn.
- `/me.subscription {enabled, tier, expiresAt, limits}` là nguồn sự thật duy nhất; app không tự quyết ai là Pro.
- Bán hay không do Admin bật `proEnabled` (mặc định tắt).

## Người dùng cần chuẩn bị (làm 1 lần, trước khi Antigravity thử mua thật)

1. **Play Console → Kiếm tiền → Gói thuê bao**: tạo 2 sản phẩm
   - `levelup_pro_monthly`: gói cơ bản `monthly`, 49.000đ/tháng, ưu đãi dùng thử 7 ngày.
   - `levelup_pro_yearly`: gói cơ bản `yearly`, 399.000đ/năm, dùng thử 7 ngày.
   Cần hồ sơ thanh toán (payments profile) đã xác minh. Sản phẩm chỉ kích hoạt được sau khi đã có bản AAB chứa
   quyền BILLING trên một kênh (test kín là đủ).
2. **RevenueCat** (app.revenuecat.com, miễn phí tới 2.500 USD doanh thu/tháng): tạo project LevelUp → thêm app
   Google Play `vn.levelup.app` → tải JSON service account để RevenueCat đọc giao dịch (dùng lại
   `play-publisher@levelup-pro...` và cấp thêm quyền "Xem dữ liệu tài chính" + "Quản lý đơn đặt hàng và gói thuê bao"
   trong Play Console → Người dùng và quyền).
   - Entitlement `pro`; gắn 2 sản phẩm trên. Offering `default` gồm package `$rc_monthly`, `$rc_annual`.
   - Integrations → Webhooks: URL `https://levelup-backend-kjqn.onrender.com/billing/revenuecat/webhook`,
     Authorization header = một chuỗi bí mật bạn tự đặt → cùng chuỗi đó đặt vào Render env
     `REVENUECAT_WEBHOOK_SECRET` rồi Manual Deploy.
   - Lấy **Public SDK key cho Android** (bắt đầu `goog_`). Đây là khoá công khai, build bằng
     `--dart-define=REVENUECAT_ANDROID_KEY=goog_...` (không commit).
3. Play Console → Kiểm thử giấy phép: thêm email Google của bạn để mua thử không mất tiền.

```
Bạn đang ở nhánh feat/app-revenuecat (worktree D:\levelup-worktrees\app-revenuecat), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-revenuecat.md.
Chỉ sửa app/ (pubspec, lib, test, android nếu plugin cần). Không dart format cả thư mục. Màu theo app_colors.dart.

1. Thêm purchases_flutter (bản ổn định mới nhất hỗ trợ Flutter hiện tại) vào pubspec. Chỉ Android; iOS/web dùng
   FakeBillingService như cũ.
2. RevenueCatBillingService implements BillingService (product/domain/services):
   - configure một lần sau khi đăng nhập Firebase: PurchasesConfiguration(REVENUECAT_ANDROID_KEY) với
     appUserID = FirebaseAuth uid (đúng uid backend dùng tìm user). Đăng xuất → Purchases.logOut(); đổi tài khoản
     → logIn(uid mới). Key lấy từ String.fromEnvironment('REVENUECAT_ANDROID_KEY'); rỗng → dùng FakeBillingService.
   - purchase(period): lấy offering current, package monthly / annual, purchasePackage. Huỷ (userCancelled) → trả
     về chuỗi rỗng, không báo lỗi. Thành công → không tự set Pro: invalidate /me và chờ tối đa ~10 giây (thử lại
     /me mỗi 2 giây) tới khi subscription.tier == "pro" (webhook có thể trễ), rồi trả "Đã kích hoạt Pro".
     Quá hạn chờ → "Đã thanh toán, Pro sẽ kích hoạt trong ít phút".
   - restore(): Purchases.restorePurchases() rồi invalidate /me.
   - Giá hiển thị: lấy từ package.storeProduct.priceString khi có, không có thì dùng giá trong productConfig.
   billingServiceProvider chọn RevenueCatBillingService khi Android + có key, ngược lại FakeBillingService.
3. Màn Pro (pro_screen): nút mua tháng/năm gọi purchase (đang mua: khoá nút + vòng tải), thêm link
   "Khôi phục giao dịch" (restore), dòng nhỏ "Tự gia hạn, huỷ bất kỳ lúc nào trong Google Play → Gói thuê bao".
   Đã Pro: hiện "Pro đến <expiresAt>" và nút "Quản lý gói" mở
   https://play.google.com/store/account/subscriptions?package=vn.levelup.app.
   proEnabled == false (Admin chưa bật) → giữ nguyên như hiện tại (không hiện nút mua).
4. Test (BillingService giả): mua thành công → /me được tải lại và hiện trạng thái Pro; huỷ mua không hiện lỗi;
   key rỗng dùng FakeBillingService; restore gọi đúng hàm. flutter analyze sạch, flutter test --concurrency=2 qua hết.
5. Commit "app: mua gói Pro bằng RevenueCat (Android)". Báo Claude Code review.
```

Build thử: `flutter build apk --release --split-per-abi --dart-define=API_BASE_URL=https://levelup-backend-kjqn.onrender.com --dart-define=REVENUECAT_ANDROID_KEY=goog_...`.
Mua thật chỉ chạy với bản cài từ CH Play (kênh test kín), không chạy với APK cài tay.
