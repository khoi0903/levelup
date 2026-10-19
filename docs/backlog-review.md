# Điểm review để sau (chờ người dùng thật gặp mới sửa)

Từ các vòng review PR #81, #84, #85 (2026-10-19). Đều là trường hợp hiếm, không làm hỏng dữ liệu hay crash app.
Sửa khi có báo lỗi thật hoặc khi đụng lại phần code đó.

## Kho món chờ duyệt (nutrition)
- **Lỗi tạm thời của Atlas bị báo là "món đã được duyệt"**: `FoodCandidateService.inTransaction` đổi mọi
  `TransientTransactionError` thành 409 `CANDIDATE_REVIEWED`. Nên thử lại 1 lần, chỉ báo 409 khi món không còn pending.
- **Ước tính món nhiều rau bị nâng calo**: `RecognitionParser.Estimate.of` lấy `max(kcal AI, 4P+4C+9F)`, món nhiều
  chất xơ có thể dư tới ~25%. Chỉ nâng khi kcal gần 0 hoặc khi phần lớn là đường.
- **Kiểm tra `status` ở `FoodCandidatesController` viết tay**: muốn dùng `@Pattern` thì phải thêm handler
  `HandlerMethodValidationException` vào `ApiErrors` để giữ định dạng `{code}`.

## Bước chân, calo vận động (training / app health_connect, activity)
- **Dùng 2 điện thoại**: `activity.activeKcal` và `activity.activeKcalInWorkouts` lấy `$max` riêng từng trường,
  nên cặp số có thể đến từ hai máy khác nhau và phép trừ phần trùng lệch. Muốn đúng thì lưu theo từng máy.
- **Buổi tập kéo qua nửa đêm**: `ActivityService.todayView` chỉ lấy buổi tập có `localDate` hôm nay, phần sau 0h của
  buổi bắt đầu hôm trước không bị trừ. Nên lấy buổi tập có khoảng thời gian chồng lên hôm nay.
- **Đọc Health Connect hai lần mỗi lần làm mới**: `getTodayCaloriesBurned` và `getActiveKcalInWindows` đọc cùng bản
  ghi. Đọc một lần rồi tính cả hai.
- **Phụ thuộc hai chiều** giữa feature `activity` và `health_connect` (WorkoutWindow, màn lịch sử đọc controller).
- **Nhãn thứ T2…CN lặp** giữa `activity_history_screen.dart` và `home_screen.dart`: tách helper dùng chung.
- **Màn lịch sử**: không ngày nào có bước nhưng có calo tập thì hiện "Trung bình 0 bước/ngày"; nên hiện hướng dẫn
  kết nối khi không có ngày nào có bước.

## Test
- Test camera giờ kiểm tra quy tắc thay vì số bài cố định (PR #83), thêm bài tập không làm hỏng test nữa.
