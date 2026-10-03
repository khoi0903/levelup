# Prompt cho Antigravity – Sprint 1 (app Flutter)

Mở thư mục `D:\fitness-app` trong Antigravity, rồi dán nguyên phần dưới đây.

---

Bạn là Flutter developer của dự án app fitness cho người Việt. Repo đã có sẵn.

## Đọc trước khi làm
1. `AGENTS.md` – quy ước bắt buộc của cả dự án. Đọc hết.
2. `docs/01-user-flows.html` – flow F1 (onboarding) và F2 (vòng lặp ngày).
3. `docs/figma-export/screens/` – wireframe từng màn dạng HTML. Mở các file:
   `Main.html`, `OB-Body.html`, `OB-Training.html`, `OB-Schedule.html`, `OB-Why.html`,
   `OB-Coach.html`, `OB-Plan.html`, `OB-Notify.html`, `OB-Start.html`, `Home.html`, `Workout.html`.
4. `docs/03-database-mongodb.html` – mục collection `users`: tên trường và giá trị enum
   (goal, experience, location, coachStyle, bodyArea...). Model Dart phải dùng đúng các tên này.

## Phạm vi
- **Chỉ sửa trong thư mục `app/`.** Không đụng `backend/`, `mongo/`, `docs/`, `AGENTS.md`.
- Làm trên nhánh mới `feat/app-s1-onboarding`. Commit nhỏ, dạng `app: thêm màn OB-Body`.
- Backend chưa có. Mọi dữ liệu lấy qua **interface repository**, tạm thời dùng bản giả
  (fake) trả dữ liệu mẫu. Sau này chỉ cần thay bằng bản gọi API, không sửa giao diện.

## Việc cần làm
0. **Đặt tên app là LevelUp**: tên hiển thị `LevelUp` trên Android (`android:label`)
   và iOS (`CFBundleDisplayName`). Đổi Application ID Android và Bundle ID iOS thành
   `vn.levelup.app` (hiện đang là `vn.fitnessapp.fitness_app`). Đổi ngay bây giờ vì sau khi
   lên store thì không đổi được nữa.
1. **Cài package** trong `app/pubspec.yaml`: `flutter_riverpod`, `go_router`, `google_fonts`.
   Chưa cài Firebase, camera, drift (để sprint sau).
2. **Cấu trúc thư mục**:
   ```
   lib/
     app/        router.dart, theme.dart
     core/       widget dùng chung (nút chính, nút phụ, chip chọn, thanh tiến độ onboarding)
     features/
       onboarding/{data,domain,presentation}
       workout/{data,domain,presentation}
       home/{data,domain,presentation}
   ```
3. **Theme** lấy từ wireframe:
   - Font: Be Vietnam Pro (`google_fonts`)
   - Nền `#F4F5F3`, chữ `#1B211E`, chữ phụ `#5E6863`, viền `#D5D9D6`
   - Màu chính `#C4461F` (nền nhạt `#FCEDE7`), màu tiến bộ `#1E7465` (nền nhạt `#E1F0EC`)
   - Bo góc nút 14, thẻ 16, chip 22. Chiều cao nút chính 52. Vùng chạm tối thiểu 44.
4. **9 màn onboarding** đúng thứ tự: Main → OB-Body → OB-Training → OB-Schedule → OB-Why
   → OB-Coach → OB-Plan → OB-Notify → OB-Start. Có thanh tiến độ "x/7", nút quay lại.
   Lưu câu trả lời vào một `OnboardingState` (Riverpod). Màn OB-Plan hiển thị kế hoạch
   tuần 1 từ `FakePlanRepository` (3 buổi như wireframe).
5. **Màn Home** và **màn Đang tập** (Workout) dùng dữ liệu giả: đếm giờ nghỉ 60 giây,
   tăng giảm tạ và số lần, nút "Xong hiệp này".
6. **Văn bản tiếng Việt** đúng như wireframe. Gom chuỗi vào một chỗ để sau này đa ngôn ngữ.
7. **Test**: widget test cho flow onboarding đi từ màn đầu tới màn OB-Start.

## Kiểm tra trước khi báo xong
- `flutter analyze` không còn lỗi.
- `flutter test` chạy qua.
- Chạy app trên máy ảo Android (hoặc thêm nền tảng web bằng `flutter create --platforms web .`
  trong thư mục `app/` để xem nhanh trên trình duyệt). Chụp màn hình từng màn và so với
  wireframe HTML tương ứng. Liệt kê chỗ nào còn khác.

## Báo cáo khi xong
- Danh sách file đã tạo, ảnh chụp các màn, những chỗ còn khác wireframe, việc còn dở.
- Không merge vào `main`. Để nhánh lại cho Claude Code review.
