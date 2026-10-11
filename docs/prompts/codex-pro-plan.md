# Prompt cho Codex – Gói LevelUp Pro + giới thiệu bạn bè + trang Admin (làm sẵn, CHƯA bật bán)

Người dùng chốt (2026-10-11): làm sẵn backend + giao diện gói Pro, **tắt mặc định** (feature flag), chưa bán thật.
Codex được phép sửa cả `backend/` và `app/` cho việc này (người dùng giao). Claude Code review rồi merge.

Nguyên tắc (AGENTS.md): hệ thống động lực (check-in, nhắc, streak, buddy, tổng kết tuần, kế hoạch, camera) **luôn
miễn phí**. Pro chỉ mở rộng phần tốn AI và phần nâng cao. Backend quyết định ai là Pro, không tin app.

| | Miễn phí | Pro |
|---|---|---|
| AI coach | 10 tin/ngày | 100 tin/ngày |
| Chụp món tính calo | 3 ảnh/ngày | 30 ảnh/ngày |
| Biểu đồ tiến bộ | 4 tuần gần nhất | toàn bộ |
| Giọng coach | 2 phong cách | 7 phong cách |

Giá dự kiến: 49.000đ/tháng, 399.000đ/năm, dùng thử 7 ngày (chỉ hiển thị, chưa bán).

**Giới thiệu bạn bè (2026-10-11)**: mỗi người có mã giới thiệu + link chia sẻ. Người mới nhập mã (onboarding hoặc
trong 7 ngày đầu) được N ngày Pro (mặc định 7). Người giới thiệu chỉ được tính khi bạn mới tập xong buổi đầu tiên
≥ 5 phút (chống tài khoản ảo). Mốc thưởng mặc định: 1 bạn → 7 ngày, 3 bạn → 30 ngày, 10 bạn → 90 ngày, cộng dồn vào
hạn Pro (plan.source = "referral").

**Trang Admin (thay màn Demo)**: admin = uid trong DEMO_UIDS (dùng lại danh sách demo, không thêm biến mới). Cấu hình lưu trong DB (đổi có hiệu lực ngay, có nhật ký),
thay cho biến PRO_ENABLED: bật/tắt Pro và giới thiệu, giới hạn free/pro, mốc giới thiệu, giá hiển thị, cấp Pro thủ
công theo email; các nút demo cũ vẫn ở đó nhưng chỉ hiện khi DEMO_MODE bật.

```
Bạn đang ở nhánh feat/codex-pro-plan (worktree D:\levelup-worktrees\codex-pro), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md, backend/README.md và docs/prompts/codex-pro-plan.md.
Được sửa backend/ và app/ cho việc này. Không dart format cả thư mục. Màu theo app_colors.dart.

BACKEND (Java, đúng nhóm/tầng; ArchitectureTest phải qua)
1. Cấu hình sản phẩm lưu trong collection app_config (một document "product", kèm version, updatedBy, updatedAt),
   đọc qua shared/ hoặc identity/service/ProductConfigService có cache ngắn (≤ 30 giây). Giá trị mặc định khi chưa
   có document: proEnabled=false, referralEnabled=false, coach free 10 / pro 100, chụp món free 3 / pro 30,
   referralInviteeDays=7, mốc [{friends:1,days:7},{friends:3,days:30},{friends:10,days:90}], giá 49000/399000 VND,
   trialDays=7. Khi proEnabled=false: MỌI người dùng dùng giới hạn hiện tại (coach 30, chụp món 10, đọc từ
   application.yaml như bây giờ) để không đổi hành vi bản đang chạy.
2. users.plan: {tier: "free"|"pro", source: "revenuecat"|"manual"|"referral", expiresAt, updatedAt} (thêm vào mongo/init.js
   validator nếu cần, không bắt buộc trường). Lớp identity/service/PlanAccess: isPro(user, now) = tier pro và
   expiresAt > now (giờ máy chủ). Coach và nhận diện món lấy giới hạn qua PlanAccess.
3. GET /me trả thêm "subscription": {"enabled": bool, "tier", "expiresAt", "limits": {"coachPerDay",
   "photosPerDay"}} để app hiển thị đúng.
4. POST /billing/revenuecat/webhook (không cần Firebase token, permitAll trong SecurityConfig): kiểm tra header
   Authorization bằng hằng thời gian với REVENUECAT_WEBHOOK_SECRET (trống thì luôn 401). Xử lý INITIAL_PURCHASE,
   RENEWAL, PRODUCT_CHANGE, UNCANCELLATION → pro tới expiration_at_ms; EXPIRATION → free; CANCELLATION giữ tới hết
   hạn. app_user_id = uid Firebase (authUid). Idempotent theo event.id (collection billing_events, unique index).
   Ghi log, không ghi dữ liệu thẻ.
5. Giới thiệu bạn bè (training/engagement tuỳ chỗ hợp lý, ghi trong backend/README.md):
   - users.referralCode (6–8 ký tự, duy nhất, tạo khi cần); GET /referrals/me → {code, link, successfulCount,
     nextMilestone, rewardsEarned}.
   - POST /referrals/redeem {code}: chỉ khi referralEnabled, tài khoản tạo chưa quá 7 ngày, chưa từng nhập mã,
     không phải mã của chính mình → người mới được referralInviteeDays ngày Pro; lưu referrals {referrerId,
     inviteeId, status: pending}. Lỗi rõ ràng: REFERRAL_DISABLED, INVALID_CODE, OWN_CODE, ALREADY_REDEEMED,
     TOO_LATE.
   - Khi người được mời lưu buổi tập đầu tiên countsForStreak → referral status=completed (một lần), cộng số bạn
     thành công cho người giới thiệu; vượt mốc nào thì cộng ngày Pro của mốc đó (mỗi mốc một lần, idempotent).
   - Gửi thông báo cho người giới thiệu qua cổng thông báo duy nhất (dedupeKey theo referral id).
6. Admin: dùng lại DEMO_UIDS qua demo/DemoAccess (thêm isAdmin(uid) = uid khớp DEMO_UIDS, KHÔNG cần
   DEMO_MODE; còn các nút /demo/* vẫn cần DEMO_MODE như cũ). /me trả "isAdmin". GET/PUT /admin/config (kiểm
   tra hợp lệ: số ≥ 0, mốc tăng dần, giá > 0; ghi admin_audit {uid, before, after, at}); POST /admin/grant-pro
   {email, days} (cấp Pro thủ công, source "manual"). Không phải admin → 404. Các endpoint /demo/* giữ nguyên.
7. Test: giới hạn theo gói (free bị chặn ở tin thứ 11 khi proEnabled=true; proEnabled=false giữ 30), webhook
   sai secret 401, mua → /me tier pro, hết hạn → free, gửi lại cùng event không ghi trùng; giới thiệu: nhập mã
   đúng/sai/của mình/quá hạn, bạn tập buổi đầu thì người giới thiệu được tính một lần, vượt mốc cộng đúng ngày;
   admin: người thường 404, PUT config sai bị 400, đổi config có hiệu lực ngay. ./mvnw test qua hết.

APP (Flutter)
8. MeResponse đọc subscription, isAdmin. Chỉ khi subscription.enabled == true mới hiện mọi thứ liên quan Pro.
9. Màn "LevelUp Pro" (route /pro): bảng Miễn phí / Pro như trên, 2 lựa chọn giá (tháng / năm, ghi "tiết kiệm 32%"),
   "Dùng thử 7 ngày", nút mua gọi lớp BillingService trừu tượng. Bản này dùng FakeBillingService (hiện SnackBar
   "Sắp ra mắt"); KHÔNG thêm gói RevenueCat/in_app_purchase vào pubspec lần này.
10. Lối vào: tab Tôi có thẻ "LevelUp Pro"; khi coach/chụp món bị chặn vì hết lượt (mã COACH_LIMIT,
   PHOTO_LIMIT_REACHED) thì thông báo kèm nút "Xem gói Pro" (chỉ khi enabled). Không hiện quảng cáo Pro ở màn tập,
   check-in, streak, buddy.
11. Giới thiệu bạn bè (chỉ khi referralEnabled): thẻ "Mời bạn, nhận Pro" ở tab Tôi → màn mã giới thiệu (nút sao
    chép, chia sẻ bằng share sheet hệ thống nếu đã có gói, không thì sao chép link), tiến độ tới mốc tiếp theo, danh
    sách mốc. Onboarding (bước cuối) và tab Tôi (trong 7 ngày đầu) có ô "Nhập mã giới thiệu". Thông báo lỗi theo mã.
12. Trang Admin thay màn Demo: bấm 5 lần vào lời chào chỉ mở khi /me.isAdmin (hoặc demoEnabled cho nút demo).
    Các mục: Bật/tắt (Pro, giới thiệu), Giới hạn, Mốc giới thiệu (thêm/sửa/xoá), Giá & dùng thử, Cấp Pro theo
    email, và các nút demo cũ (chỉ hiện khi demoEnabled). Lưu bằng PUT /admin/config, báo lỗi hợp lệ từ máy chủ.
13. Test (repository giả): enabled=false không thấy gì về Pro; enabled=true thấy thẻ và mở được màn /pro;
    hết lượt coach hiện nút "Xem gói Pro"; referralEnabled ẩn/hiện màn mời; nhập mã sai hiện đúng lỗi; người thường
    không mở được Admin, admin sửa mốc và lưu gửi đúng body. flutter analyze sạch, flutter test --concurrency=2 qua.

14. Commit "be+app: gói LevelUp Pro, giới thiệu bạn bè, trang Admin (tắt mặc định)". Báo Claude Code review,
    liệt kê biến môi trường mới (REVENUECAT_WEBHOOK_SECRET) và collection mới.
```
