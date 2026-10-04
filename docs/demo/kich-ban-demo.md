# Kịch bản demo LevelUp — 11 phút 40 giây, 2 điện thoại

Máy A là người dùng chính, máy B là buddy. Một người trình bày kiêm tập mẫu, một người điều khiển máy B, một người vận hành API trên laptop. Không cần điện thoại thứ ba. Các thao tác ghép buddy và cổ vũ dưới đây là thao tác demo trực tiếp của người vận hành.

Nguồn: [F1–F8](../01-user-flows.html), [Công cụ demo và kịch bản gợi ý](../02-ke-hoach-10-tuan.html#demo-tools), `DemoController`, `DemoService`, `SkipPlanner`, `WeekCloseService`, `WeeklyReviewService` trong backend. Nhãn nút cần đối chiếu với bản build lúc tổng duyệt.

## Chuẩn bị trước 30 phút

1. Sạc hai máy, bật chia sẻ màn hình, tắt tự khóa, chuẩn bị Wi-Fi riêng và 4G dự phòng. Đặt máy A đủ xa để thấy toàn thân, đủ sáng, sàn không trơn. Có đĩa cơm tấm hoặc ảnh món ăn in rõ, ảnh gốc trên máy và video quay sẵn từng flow.
2. Chạy MongoDB dev tại `mongodb://localhost:27018/fitness?replicaSet=rs0`, nạp kho bài và món bằng quy trình seed hiện có. Backend chạy profile `dev`, cổng mặc định **8081**. Trên điện thoại dùng IP LAN của laptop, không dùng `localhost`. Kiểm tra app đang gọi API thật, tài khoản và camera hoạt động.
3. Chuẩn bị hai UID trên hai máy: `demo-main-<lần>` **chưa onboarding** trên A, `demo-buddy-<lần>` đã onboarding trên B. Tên hiển thị lần lượt “Lan” và “Minh”, timezone `Asia/Ho_Chi_Minh`. Bản app hiện tại lấy UID từ `--dart-define=DEV_UID=...`, API từ `--dart-define=API_BASE_URL=http://<IP-LAN>:8081`; dùng bản build API thật đã tổng duyệt. Nút Đăng xuất chưa thay được DEV_UID của API. Dùng UID mới mỗi lần diễn để tránh dữ liệu cũ; không chuyển tài khoản trên A giữa buổi. UID phải thật sự bắt đầu bằng `demo`, tên hoặc email có chữ “demo” không đủ.
4. Với xác thực dev, header là `Authorization: Bearer dev-demo-main-<lần>`; UID bên trong là `demo-main-<lần>`. App tự tạo token từ DEV_UID. Profile dev hiện chỉ nhận token dev này, không gửi Firebase ID token vào cấu hình đó. `/demo/*` lấy người dùng từ token, không nhận `userId` trong body. `application-dev.yaml` mặc định bật demo và `DEMO_UIDS=demo*`; kiểm tra không bị biến môi trường ghi đè. Giữ các công cụ này trong môi trường dev.
5. Lưu sẵn đoạn chuẩn bị fixture bên dưới thành file tạm trên laptop, thay đúng UID main. Thử nó cùng `POST /demo/seed` bằng bộ UID tổng duyệt. Với bộ diễn trực tiếp: **seed buddy trước giờ; main chỉ chạy fixture rồi seed một lần ở mốc 01:35 sau onboarding**. Gộp thao tác thành hai lệnh sẵn để hoàn tất trong 15 giây, xem phản hồi `weeks=4`, `workouts=9`, `currentWeeks=3`. Seed tạo 4 tuần đã qua: 1 tuần chưa đạt, 3 tuần đạt, 9 buổi 20 phút và 1 PR số lần bằng 12; thêm tuần hiện tại `in_progress`, 0 buổi. **Seed giữ kế hoạch tập nhưng xóa log tập, streak, PR, báo bỏ buổi, thông báo, tin coach, thống kê ngày của chính tài khoản đó.** Seed ghi lại huy hiệu buổi đầu/streak 2 tuần; không tạo bữa ăn, cân nặng, cặp buddy hay tổng kết tuần. Sau khi bắt đầu tập, không seed lại main.
6. Tổng duyệt main chọn coach Động viên, lịch có ngày hôm nay và ít nhất 3 ngày rảnh nếu còn trong tuần. Kiểm tra bài camera có tracking số lần trong kế hoạch. Nếu muốn PR mới, xem `personalRecordExerciseId` từ seed và tập đúng bài đó với số lần đã xác nhận vượt 12; huy hiệu 10 buổi không phụ thuộc việc có PR mới. Khi diễn, fixture giữ mục tiêu 3 buổi dù cuối tuần onboarding chỉ tạo được một ngày rảnh.
7. A mở bộ UID main mới, chưa hoàn tất onboarding; B đã onboarding, chưa ghép buddy. Kiểm tra quyền camera/thông báo, token thiết bị và còn ngân sách nhận push. Giờ demo nên trong 07:00–22:00; tối đa mặc định 2 push/người/ngày và có dedupe, không ép gửi lại để vượt giới hạn.
8. Tổng duyệt `skip-two`, `close-week`, `review` trên bộ UID khác. Xem phản hồi API và tải lại app sau mỗi lệnh. Quay video hoàn chỉnh; đừng chốt tuần của bộ UID sắp dùng trực tiếp.

### Fixture để diễn được cả “bỏ 2 buổi” và “Bận → đổi lịch”

Onboarding thường chỉ sinh tối đa 3 buổi. Sau một buổi tập và `skip-two`, sẽ không còn hai buổi để minh họa cả rút ngắn và dời lịch. Vì vậy cần fixture dev riêng, không dùng kế hoạch mặc định rồi hứa màn hình sẽ đổi.

Vào ngày từ Thứ Hai đến Thứ Sáu, chuẩn bị 5 buổi `planned` trong kế hoạch active của main: hôm nay lúc 17:00 (buổi sẽ tập), 18:30 (buổi sẽ rút ngắn), 19:30 và 20:30 (hai buổi sẽ giả lập bỏ), ngày mai 18:30 (buổi sẽ dời). Ngày kia phải trống và vẫn trong cùng tuần. Đây là lịch minh họa cho công cụ demo; giữ mục tiêu 3 buổi. `skip-two` xét **ngày**, không xét giờ, và chọn hai buổi planned mới nhất theo ngày/giờ: sau khi buổi 17:00 hoàn thành, hai buổi 20:30 và 19:30 sẽ bị bỏ, còn 18:30 để xử lý lý do Bận.

Người vận hành có thể chuẩn bị fixture bằng `mongosh` trên DB dev, trước seed. Đoạn này chỉ đổi kế hoạch của UID demo được chỉ định, sao chép cấu trúc bài từ kế hoạch có sẵn. Không chạy trên dữ liệu người dùng thật.

```javascript
// Trong mongosh kết nối mongodb://localhost:27018/fitness?replicaSet=rs0
const uid = "demo-main-<lần>"; // thay đúng UID của bộ demo
const store = db.getSiblingDB("fitness");
if (!uid.startsWith("demo")) throw new Error("Chỉ dùng UID demo");
const u = store.users.findOne({ authUid: uid });
if (!u) throw new Error("Chưa có user: cần đăng nhập và onboarding UID này trước");
const fmt = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Ho_Chi_Minh", year: "numeric", month: "2-digit", day: "2-digit"
});
const parts = Object.fromEntries(fmt.formatToParts(new Date()).map(p => [p.type, p.value]));
const today = `${parts.year}-${parts.month}-${parts.day}`;
const date = new Date(today + "T12:00:00Z");
const weekday = date.getUTCDay() || 7;
function plus(n) {
  const d = new Date(date); d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
const weekStart = plus(1 - weekday);
const p = store.training_plans.findOne({ userId: u._id, weekStart, status: "active" });
if (!p || !p.sessions?.length) throw new Error("Cần onboarding và kế hoạch active tuần này");
const base = p.sessions[0];
const slots = [[today, "17:00"], [today, "18:30"], [today, "19:30"],
               [today, "20:30"]];
if (weekday <= 5) slots.push([plus(1), "18:30"]);
const sessions = slots.map(([scheduledDate, scheduledTime], i) => ({
  _id: new ObjectId(), scheduledDate, scheduledTime,
  title: i === 0 ? "Demo tập 5 phút" : "Demo điều chỉnh lịch",
  durationMin: 15, status: "planned", variant: "normal", items: base.items
}));
printjson(store.training_plans.updateOne(
  { _id: p._id, userId: u._id, status: "active" },
  { $set: { sessions, targetSessions: 3 } }
));
```

Nếu demo Thứ Bảy/Chủ nhật, đoạn trên tạo 4 buổi hôm nay: tập buổi 17:00; bỏ hai buổi 20:30/19:30; còn buổi 18:30. Ở F3 chọn **Mệt**, xem bản nhẹ/bớt hiệp buổi còn lại. Nói “Các buổi còn lại đã nhẹ hơn”, không nói đã dời buổi sang ngày trống khi tuần không còn ngày. Kiểm tra plan của onboarding là tuần hiện tại bằng cách chọn ngày hôm nay trong lịch rảnh.

### Các lệnh trên laptop

Nếu build đã có màn demo ẩn, dùng nút tương ứng. Tài liệu thiết kế nói chạm logo 5 lần nhưng chưa thấy màn đó trong mã app hiện tại; phương án chắc chắn là người vận hành gọi API. Không giả định có thêm action “gửi check-in” hoặc “mở huy hiệu”.

```powershell
$demoApi = 'http://127.0.0.1:8081' # thay nếu PORT được cấu hình khác
$mainHeaders = @{ Authorization = 'Bearer dev-demo-main-<lần>' }
$buddyHeaders = @{ Authorization = 'Bearer dev-demo-buddy-<lần>' }
# Trước giờ demo (buddy đã onboarding):
Invoke-RestMethod -Method Post -Uri "$demoApi/demo/seed" -Headers $buddyHeaders
# Sau F1, mốc 01:35: chạy file fixture tạm đã chuẩn bị ở trên rồi seed main:
# mongosh 'mongodb://localhost:27018/fitness?replicaSet=rs0' --file <file-fixture-tạm.js>
Invoke-RestMethod -Method Post -Uri "$demoApi/demo/seed" -Headers $mainHeaders
# Ở bước F3:
Invoke-RestMethod -Method Post -Uri "$demoApi/demo/skip-two" -Headers $mainHeaders
# Ở bước F4 rồi F6:
Invoke-RestMethod -Method Post -Uri "$demoApi/demo/close-week" -Headers $mainHeaders
Invoke-RestMethod -Method Post -Uri "$demoApi/demo/review" -Headers $mainHeaders
```

`skip-two` phải trả `skipped=2`; `notified` là danh sách trigger xử lý, không phải xác nhận push đã tới máy. Cổng thông báo vẫn có thể chặn theo ngân sách/giờ yên lặng. `close-week` chốt **tuần hiện tại**, chỉ lần đầu trả `closed=true`; nó đã gọi listener tổng kết. `review` gọi lại listener cùng tuần, không đổi ngày hay tự chốt tuần, không đảm bảo tạo bản tổng kết mới nếu bản cũ đã tồn tại. Kiểm tra màn Tổng kết/GET reviews, không chỉ dựa vào HTTP 200 hoặc số listener.

## Diễn trực tiếp — tổng 11:40

| Thời gian | Flow / máy | Bấm gì | Nói gì | Màn hình mong đợi |
|---|---|---|---|---|
| 00:00–00:20 | Mở đầu / A+B | Chiếu hai máy; A ở tài khoản mới, B ở Trang chủ. | “LevelUp tập trung giúp người dùng quay lại khi thiếu động lực. Check-in, streak tuần, buddy và tổng kết luôn miễn phí.” | Hai máy sẵn sàng, chưa gọi action nào. |
| 00:20–01:35 | F1 / A | Đi đủ 9 màn onboarding: mục tiêu Khỏe hơn; thông tin cơ thể mẫu; kinh nghiệm mới, không chấn thương, tập ở nhà; lịch rảnh buổi tối; lý do ‘Khỏe để chơi với con’; coach Động viên; xem kế hoạch; giải thích và cho quyền thông báo; ở lời mời tập thử chọn Hẹn giờ. Buddy chọn Để sau nếu xuất hiện. | “Tuần đầu nhẹ để dễ bắt đầu. Coach nhớ lý do thay đổi và giọng bạn chọn. Người dùng có thể tập thử 5 phút ngay hoặc hẹn giờ.” | Hồ sơ lưu thật, kế hoạch có ngày/giờ và bài, không nằm ở loading. Không hứa tuần đầu đã đạt khi chưa tập. |
| 01:35–01:50 | Nạp dữ liệu mẫu / laptop + A | Vận hành chạy fixture đã chuẩn bị rồi `POST /demo/seed` trên chính UID main vừa onboarding. A kéo làm mới Trang chủ. | “Tôi nạp thêm 4 tuần dữ liệu mẫu để minh họa hành trình dài hơn. Phần tập sau đây sẽ được ghi thật.” | 9 buổi lịch sử, streak 3 tuần; tiến độ tuần hiện tại 0/3, fixture lịch đúng. Không đổi DEV_UID. |
| 01:50–02:05 | F2 / A | Check-in chọn Sung sức. Mở buổi demo 17:00, chọn bản 5 phút, đọc bài rồi Bắt đầu. | “Check-in giúp chọn nhịp tập. Sung sức vẫn tập theo kế hoạch; phần nâng cao là tùy chọn.” | Check-in lưu, coach phản hồi vừa phải; session đã là bản 5 phút, bộ đếm giờ bắt đầu. |
| 02:05–03:05 | F2 camera / A | Bật camera, xác nhận quyền nếu cần; đứng đúng khung, tập squat hoặc bài đếm lần đã tổng duyệt, xác nhận số lần. | “Số lần và phản hồi tư thế xử lý trên điện thoại. Video tập không rời máy; kết quả số lần được người tập xác nhận.” | Đếm lần trực tiếp khi đủ điểm pose; thông báo chỉnh tư thế nếu thật sự phát hiện. Không cố tạo tư thế nguy hiểm để lấy cảnh báo. |
| 03:05–04:05 | F2 / A | Tiếp tục các động tác theo hướng dẫn, nghỉ giữa hiệp theo lịch, giữ buổi tập đang chạy. | “Kết quả ghi nhận cả thời gian và số lần. Mỗi người tập theo khả năng của mình.” | Timer tiếp tục, các hiệp và số lần được ghi; chưa kết thúc sớm. |
| 04:05–05:05 | F5 / B và người phụ trên A | Người tập tiếp tục buổi tập; người phụ mở Buddy trên A khi bản build đã thử cho phép giữ timer: Tạo mã mời của bạn. B vào Buddy, nhập mã, Ghép cặp ngay. Nếu điều hướng sẽ mất buổi, ghép cặp trước giờ demo và ở đây chỉ mở trạng thái trên B. | “Hai người ghép bằng mã. Buddy mặc định thấy trạng thái tập và streak; cân nặng và bữa ăn không tự chia sẻ.” | Cặp Lan–Minh có thật, B thấy trạng thái A chưa hoàn thành; buổi tập trên A vẫn giữ giờ/hiệp sau khi trở lại. |
| 05:05–06:05 | F2 + giải thích F4 / A | Tiếp tục động tác và thời gian nghỉ; cho khán giả thấy timer. | “Streak tính theo tuần vì ngày nghỉ có trong kế hoạch. Chỉ buổi từ 5 phút mới tính một buổi, nên tôi để timer chạy đủ thời lượng thật.” | Timer không bị đặt lại, nhật ký buổi đang tập còn nguyên. |
| 06:05–07:05 | F2 / A | Hoàn thành phần còn lại. Khi đủ 300 giây mới Kết thúc; chọn RPE 6, không báo đau trong buổi mẫu, Lưu kết quả. | “RPE 6 cho biết mức tập vừa sức. Coach dùng phản hồi này để giữ nhịp buổi sau.” | API lưu thành công, `durationSec >= 300`, `countsForStreak=true`; tiến độ tuần 1/3. Không gọi buổi chưa lưu là đã hoàn thành. |
| 07:05–07:35 | F7 / A | Xem kết quả, huy hiệu 10 buổi; mở bộ sưu tập huy hiệu nếu màn ăn mừng không tự bật. Xem PR nếu có thật. | “9 buổi mẫu cộng buổi vừa tập là cột mốc 10 buổi. App ghi nhận tiến bộ, kể cả khi hôm nay không có kỷ lục mới.” | Huy hiệu `sessions_10`; PR mới chỉ khi đúng bài và vượt kỷ lục đã có. |
| 07:35–08:35 | F3 / A + laptop | Vận hành gọi `skip-two`; A tải lại tin coach, chọn Bận, gửi lý do. Mở lịch vừa cập nhật. Cuối tuần chọn Mệt theo nhánh chuẩn bị. | “Đây là giả lập bỏ hai buổi bằng logic backend. Khi tôi báo bận, buổi tối nay rút còn 10 phút, buổi sau dời sang ngày trống; không yêu cầu tập bù.” | `skipped=2`; coach hỏi lý do. Sau báo Bận: `action=shortened`, buổi 18:30 còn 10 phút, buổi ngày mai sang ngày kia, tin `skip_busy`. Nhánh Mệt: bản nhẹ/bớt hiệp, `reduced_intensity`. |
| 08:35–09:05 | F5 / B → A | B làm mới Buddy, bấm Cổ vũ. A mở tin trong app; nếu push đến thì mở từ thông báo. | “Buddy thấy tôi vừa tập xong và gửi lời cổ vũ. Nhắc bạn có giới hạn một lần mỗi ngày.” | B thấy A đã tập; cổ vũ lưu thật, A nhận tin trong app. Push tùy token/quyền và ngân sách; không bấm gửi liên tục. |
| 09:05–10:05 | F8 / A | Dinh dưỡng → Chụp món ăn, chụp cơm tấm → xem nhận diện/khoảng kcal → sửa khẩu phần thành 0,75 phần hoặc số gam tương đương → Lưu. Mở coach hỏi gợi ý bữa tối nếu còn thời gian. | “Ảnh giúp ước lượng; khẩu phần và cách nấu vẫn làm số liệu thay đổi. Người dùng sửa trước khi lưu, rồi xem calo và macro của ngày.” | Tên món, khoảng kcal, khẩu phần sửa làm số liệu thay đổi, bữa ăn lưu trong hôm nay. Gợi ý tối chỉ dựa trên dữ liệu thật, mục tiêu tối thiểu 1200 kcal, nam 1500. |
| 10:05–10:40 | F4 / laptop + A | Gọi `close-week`, A tải lại Streak. | “Tôi chốt sớm để minh họa. Tuần này mới 1/3 buổi, tài khoản mẫu không có thẻ đóng băng: streak hiện tại về 0, kỷ lục 3 tuần vẫn còn. Nghỉ không xóa hành trình đã có.” | Lần đầu `closed=true`, `status=missed`, `currentWeeks=0`, `bestWeeks=3`. Không tuyên bố được thẻ hay streak 4 tuần khi chưa đạt mục tiêu. |
| 10:40–11:25 | F6 / laptop + A | Gọi `review`, mở Tổng kết tuần, đọc kết quả/chiến thắng/một điều cải thiện; bấm Đồng ý kế hoạch đề xuất. | “Tổng kết ghi nhận một buổi vừa quay lại. Với 1/3 mục tiêu, luật đề xuất giảm nhịp tuần sau. Người dùng xác nhận thì kế hoạch mới được áp dụng.” | Tổng kết đúng tuần, dữ liệu 1/3 và RPE thực; đề xuất giảm, kế hoạch nháp tuần sau; sau xác nhận thành kế hoạch đã áp dụng. AI lỗi vẫn có lời tổng kết theo mẫu. |
| 11:25–11:40 | Kết / A+B | Đặt hai máy cạnh nhau, A ở kế hoạch tuần sau, B ở Buddy. | “Từ bắt đầu, tập, bỏ buổi đến quay lại: LevelUp giữ mục tiêu vừa sức và có người đồng hành.” | Hai máy phản ánh cùng cặp buddy; không thao tác thêm vào DB. |

Năm hàng 02:05–07:05 là **5 phút thật**, gồm tập và nghỉ trong buổi đang chạy; không cộng thời gian trước Bắt đầu. Nếu thao tác máy làm timer tạm dừng, bù đủ giây; rút lời nói hoặc dùng bản ghi ở các bước sau để vẫn dưới 12 phút. Không gửi một duration giả để lấy streak. Ghép buddy trước giờ diễn là phương án dự phòng đã có màn/video ghép mã; cần tổng duyệt việc rời màn workout trước khi chọn phương án ghép trực tiếp.

## Nếu mạng/AI lỗi thì làm gì

| Lỗi | Thao tác của người trình bày/vận hành | Lời nói và kết quả hợp lệ |
|---|---|---|
| AI coach chậm/lỗi | Chờ tối đa khoảng 10 giây trên sân khấu rồi dùng báo lý do Bận/Mệt bằng nút; tải kế hoạch trả về. | “AI lỗi thì app vẫn chạy bằng luật dự phòng.” Onboarding có luật tạo tuần 1; báo bỏ buổi chỉnh lịch bằng luật và câu mẫu; chat có fallback. AI không ghi trực tiếp DB. |
| AI tổng kết lỗi | Vẫn chốt tuần và mở Tổng kết; kiểm tra listener/review nếu chưa có. | Số liệu và đề xuất tuần sau do luật quyết định; lời tổng kết dùng mẫu dự phòng. Không nói văn bản mẫu vừa được AI sinh. |
| AI nhận diện ảnh lỗi | Chuyển Tìm món → chọn Cơm tấm → sửa khẩu phần → Lưu. | “Nhận diện ảnh đang không khả dụng; tôi chọn món từ kho đã có.” F8 vẫn ghi bữa ăn được, không có luật tự nhận diện ảnh thay AI. |
| Wi-Fi/mạng backend lỗi | Chuyển hotspot 4G hoặc mạng LAN dự phòng đã thử; kiểm tra API từ cả hai máy. Nếu quá 20 giây chưa phục hồi, chiếu video của đoạn tương ứng, giữ lời dẫn. | Fallback AI cần backend còn truy cập được. Không hứa mất mạng toàn bộ vẫn gọi được API; chỉ công bố lưu offline khi bản build đã kiểm chứng. Với buổi chưa đồng bộ, nói rõ chưa xác nhận lưu trên server. |
| Camera không bắt pose | Chỉnh khoảng cách/ánh sáng, đứng toàn thân; nếu chưa được, tắt đếm tự động và xác nhận số lần thủ công. | Vẫn hoàn thành đủ 5 phút thật. Không bịa số lần hay lỗi tư thế. |
| Push không đến | Kiểm tra phản hồi API, làm mới Coach/Buddy trong app; mở tin tại đó, dùng video push nếu cần. | Quyền, token thiết bị, giờ yên lặng, maxPerDay và dedupe đều có thể chặn push; không tắt các giới hạn để diễn. |
| `skip-two` trả dưới 2 | Kiểm tra đúng token main và còn hai session planned ngày <= hôm nay. Dùng video nếu fixture sai; không gọi lại mù quáng. | HTTP 200 không đồng nghĩa bỏ đủ hai buổi. Không diễn lý do bằng một kế hoạch đã hết buổi cần đổi. |
| `close-week` trả `closed=false`, review cũ | Tuần đã chốt; dùng bộ UID mới cho lần demo kế tiếp, dùng video trong lần hiện tại. | Seed không xóa `weekly_reviews`, kế hoạch nháp tuần sau hay cặp buddy. Gọi `review` lại không tạo tổng kết mới cho cùng tuần đã có. |

## Danh sách kiểm tra trước giờ demo

- [ ] Hai máy đủ pin, trình chiếu và âm thanh ổn; vùng tập đủ sáng/an toàn, camera bắt đủ toàn thân.
- [ ] Profile dev, cổng 8081/IP LAN đúng, MongoDB cổng 27018, kho bài/món đã nạp; app dùng API thật.
- [ ] Hai build dùng đúng DEV_UID demo mới; A main chưa onboarding, B buddy có hồ sơ đúng timezone; F1 sẽ chọn coach Động viên.
- [ ] Buddy đã seed; main có lệnh fixture/seed sẵn chạy sau F1; bộ tổng duyệt trả 4 tuần / 9 buổi / streak 3, tuần hiện tại chưa chốt.
- [ ] Fixture đủ buổi; đã xác định chính xác hai ID `skip-two` sẽ chọn và buổi còn lại để đổi; nhánh Bận còn ngày trống trong tuần, hoặc đã chọn nhánh Mệt cuối tuần.
- [ ] Buổi camera đúng bài đã tổng duyệt; lưu 5 phút thật; không cần PR giả để đạt huy hiệu 10 buổi.
- [ ] Mã ghép cặp và token thông báo hoạt động, còn ngân sách push; có phương án mở tin ngay trong app.
- [ ] API `seed`, `skip-two`, `close-week`, `review` đã thử trên bộ UID tổng duyệt; main chỉ seed một lần sau F1, trước buổi tập thật.
- [ ] Có ảnh/món ăn, tìm món thủ công hoạt động; đã thử sửa khẩu phần và lưu bữa ăn.
- [ ] Tổng kết có mẫu dự phòng, xác nhận kế hoạch tuần sau hoạt động; không hứa tính năng chưa thử.
- [ ] Video F1–F8 lưu sẵn trên laptop, 4G/LAN dự phòng đã thử; tổng thời gian tổng duyệt 10–12 phút.
