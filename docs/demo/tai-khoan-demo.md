# Tài khoản demo LevelUp

Dùng **2 tài khoản Firebase email/mật khẩu**: chính trên máy A, buddy trên máy B. Cả hai kết nối cùng backend Render và Atlas `fitness`. Cài APK/cấu hình hạ tầng theo [deploy.md](../deploy.md).

## 1. Tạo tài khoản và làm onboarding

1. Máy A → app → màn đăng nhập → **Đăng ký**, dùng email của team dành riêng cho demo; đặt mật khẩu trong trình quản lý mật khẩu của team.
2. Hoàn thành onboarding: tên, mục tiêu, thông tin cơ thể thử, kinh nghiệm/chấn thương, nơi tập/dụng cụ, lịch rảnh, lý do thay đổi, phong cách coach. Kiểm tra đã có kế hoạch trên Trang chủ.
3. Cho phép thông báo/camera. Để mời buddy sau, ghép ở mục 4.
4. Máy B làm tương tự với email khác và tên dễ phân biệt, ví dụ **Minh Demo** và **An Buddy**. Dùng múi giờ `Asia/Ho_Chi_Minh` cho cả hai.

**Không ghi mật khẩu thật vào file này, Git hoặc chat.** Bảng dưới chỉ là mẫu trống để team điền trong bản riêng ở nơi an toàn; không commit bản chứa thông tin đăng nhập.

| Thông tin | Chính — máy A | Buddy — máy B |
|---|---|---|
| Email | __________ | __________ |
| Mật khẩu / tham chiếu kho mật khẩu | __________ | __________ |
| Tên hiển thị | __________ | __________ |
| Firebase UID (`authUid`) | __________ | __________ |

## 2. Lấy đúng UID từ Atlas

1. **MongoDB Atlas → cluster → Browse Collections → fitness → users**.
2. Tìm hồ sơ vừa tạo bằng email hoặc tên đã nhập, kiểm tra đúng người. Sao chép trường **`authUid`** của mỗi tài khoản.
3. Hai UID phải khác nhau. Không dùng `_id` MongoDB thay `authUid`: `_id` là ID hồ sơ nội bộ, `authUid` là UID Firebase mà nút demo kiểm tra.
4. Chưa có document: đăng nhập lại và hoàn thành onboarding trên đúng URL Render; kiểm tra đúng database/cluster. Tài khoản Firebase Authentication chưa đồng nghĩa có hồ sơ backend.

## 3. Bật quyền demo trên Render

Render → service **levelup-backend → Environment**, đặt:

```text
DEMO_MODE=true
DEMO_UIDS=<uid1>,<uid2>
```

Thay chỗ giữ chỗ bằng hai `authUid`, phân cách dấu phẩy, không giữ `< >`. Lưu → **Manual Deploy → Deploy latest commit**. Chờ deploy hoàn tất, health `UP`. Render dùng Firebase thật, không đặt profile `dev` hoặc dùng token `dev-...`.

Từng máy: **Trang chủ → chạm logo/tiêu đề 5 lần trong 3 giây → Nạp dữ liệu demo**. Nếu “Tài khoản này chưa bật chế độ demo”/404, kiểm tra email đang đăng nhập, hai UID, cờ demo và lần deploy. Không mở được màn ẩn thì kiểm tra APK đã có màn theo [prompt Antigravity](../prompts/antigravity-demo-streak.md).

Chính phải có 9 buổi cũ, streak 3 tuần, 1 PR, 4 mốc cân nặng và 21 bữa trong 7 ngày trước. Nếu bữa bằng 0, kho `foods` chưa nạp: nhờ người phụ trách nạp seed theo `deploy.md`, rồi nạp demo lại. Seed thay lịch sử của chính tài khoản đó, chỉ dùng hồ sơ thử.

## 4. Ghép buddy trong app

1. Máy A đăng nhập chính → **Buddy → Tạo mã mời của bạn**; giữ mã 6 ký tự, hiệu lực 7 ngày.
2. Máy B đăng nhập buddy → **Buddy → Bạn có mã từ bạn bè?** → nhập mã A → **Ghép cặp ngay**.
3. Làm mới Buddy trên cả hai. A thấy buddy, B thấy chính; trạng thái tập/streak đúng.
4. Giữ **Cổ vũ 🔥** chưa bấm cho lượt diễn chính. Lượt thử có thể dùng hết lượt trong ngày; nạp demo không xóa cặp/lượt cổ vũ. Đã dùng thì chuẩn bị video hoặc cặp demo mới cho lượt diễn.

## 5. Chuẩn bị lượt diễn và khôi phục sau tổng duyệt

- `seed` **giữ `training_plans`**. Chính cần ít nhất 2 buổi `planned` có ngày ≤ hôm nay và một buổi `planned` khác để coach điều chỉnh. Nếu thiếu sau bỏ buổi/đổi lịch, nhờ Claude Code chuẩn bị lại kế hoạch riêng; không coi seed là reset toàn bộ. Xem [Kịch bản demo](kich-ban-demo.md) và phương án video.
- Onboarding trực tiếp: tạo thêm tài khoản mới email/mật khẩu trên máy A, dừng trước hoàn tất onboarding. Đây là tài khoản tạm F1, **không phải tài khoản demo cố định**, không cần thêm vào `DEMO_UIDS`. Nếu chỉ dùng hai tài khoản, quay onboarding chính trước lần đầu hoàn tất, dùng đoạn đó ở F1.
- Kiểm tra nhận push, nạp demo lại trước buổi diễn, mở app/làm mới trước 5 phút. Nạp lại không làm mới quota AI trong ngày; tránh thử AI/cổ vũ quá nhiều.
- Hết chuỗi demo: Render → `DEMO_MODE=false` → lưu → **Manual Deploy**. Thông tin đăng nhập tiếp tục ở kho mật khẩu của team.
