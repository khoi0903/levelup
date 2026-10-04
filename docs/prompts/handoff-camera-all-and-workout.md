# Bàn giao: camera cho mọi bài (Codex) và luồng tập (Antigravity)

Hai việc này do agent của Claude làm dở rồi hết quota. Phần đã có đều qua `flutter analyze` và 60 test cũ.
Mỗi bên mở đúng thư mục, dán phần prompt tương ứng.

| Việc | Thư mục | Nhánh | Ai |
|---|---|---|---|
| Camera đếm mọi bài | `D:\levelup-worktrees\codex-camera-all` | `feat/app-camera-all` | Codex (ChatGPT) |
| Luồng tập nối backend | `D:\levelup-worktrees\app-workout` | `feat/app-workout-flow` | Antigravity |

Hai việc chạy song song được: Antigravity không sửa `camera_counter/`, Codex chỉ sửa `camera_counter/` và `mongo/`.

---

## Prompt cho Codex – camera đếm mọi bài

```
Bạn đang ở nhánh feat/app-camera-all, không chuyển nhánh. Đọc AGENTS.md và
app/lib/features/camera_counter/README.md trước. Chỉ sửa trong app/lib/features/camera_counter/,
app/test/features/camera_counter/, mongo/cv-configs.json, mongo/seed/exercises.json (trường cv).

Nhánh đã có 2 commit (xem git log main..HEAD và git diff main...HEAD):
- c503b53: CvConfig tổng quát (direction flex|extend, mode reps|hold với holdMin/holdMax, side auto|both,
  khớp mới elbow/wrist/heel/footIndex, form rules trong domain/form_rule.dart), RepCounter hỗ trợ hold.
- a6cfca8: mongo/cv-configs.json cấu hình 15 bài, exercises.json đánh dấu cv.supported.

Làm nốt:
1. data/camera_rep_session.dart: đọc lại phần đang dở. API công khai phải giữ tương thích
   (CameraRepSession(config:), start/pause/stop, results, latestResult với repCount, personMissing,
   averageConfidence, formScore, issues, status, error) và THÊM holdDuration + mode để UI hiển thị bài giữ tư thế.
2. Test (đang thiếu hoàn toàn cho phần mới): dùng synthetic_pose.dart, test từng direction, hold (vào/ra
   khoảng góc, mất người thì dừng đếm giờ), side both, từng form rule, squat JSON cũ vẫn parse và đếm y như
   trước, và mọi config trong mongo/cv-configs.json đều parse được (đọc file bằng đường dẫn tương đối).
3. README: bảng bài → hỗ trợ?/mode/direction/khớp/vị trí đặt máy, bài không hỗ trợ ghi 1 dòng lý do,
   nguồn tham khảo ngưỡng góc.
4. Màn debug: thêm chỗ chọn bài (lấy từ cấu hình), hiện repCount hoặc holdDuration, góc, bên, độ tin cậy,
   lỗi tư thế, setupTipVi.
LƯU Ý: Android dùng ImageFormatGroup.yuv420 + yuv420ToNv21 (commit f8f32e3, máy Xiaomi có đệm cuối hàng).
Không đổi lại sang nv21.
Kiểm tra: cd app; flutter analyze; flutter test đều đạt. Không chạy build Android (máy 8 GB RAM).
Commit nhỏ, không merge vào main. Báo cáo: API thêm mới (tên chính xác), bảng bài, số test.
```

---

## Prompt cho Antigravity – luồng tập nối backend

```
Bạn đang ở nhánh feat/app-workout-flow, không chuyển nhánh. Đọc AGENTS.md trước.
Chỉ sửa app/lib/features/workout/**, app/lib/features/home/**, app/lib/app/router.dart, app/test/**.
Không sửa app/lib/features/camera_counter/ (Codex đang làm song song), backend/, mongo/.

Nhánh đã có (xem git log main..HEAD): model + ApiWorkoutRepository + lớp bọc camera (d26b97f), các màn
F2/F2b: tổng quan buổi, đang tập, đặt camera, đang đếm, xác nhận số lần, RPE, kết quả, nút Bắt đầu ở Home
(5202ca8), và test/features/workout/workout_test_helpers.dart (dở).

Làm nốt:
1. Đọc lại toàn bộ code nhánh, chạy thử trên Chrome với backend dev (flutter run -d chrome
   --dart-define=DEV_UID=test-workout): Home → Bắt đầu → tập bằng đếm tay → RPE → Kết quả; kiểm tra
   trong MongoDB có workout_logs, training_plans buổi đó thành completed, weekly_streaks tăng.
2. Test (đang thiếu): body POST /workouts đúng tên trường backend (xem backend/.../workouts/WorkoutRequest.java),
   gửi lại khi lỗi mạng dùng CÙNG clientId, xác nhận camera có sửa số thì repSource = camera_corrected,
   màn kết quả hiện kỷ lục và huy hiệu, bài tracking = duration dùng đồng hồ.
3. Màu chỉ dùng app_colors.dart (bản dịu mắt), bố cục theo Figma trang "Yes".
4. Bài giữ tư thế (plank, wall sit): Codex đang thêm holdDuration vào CameraRepSession; tạm thời dùng đồng hồ,
   để 1 TODO rõ chỗ sẽ nối.
Kiểm tra: flutter analyze sạch, flutter test đạt. Không chạy build Android (máy 8 GB RAM).
Commit trên nhánh, không merge vào main. Báo cáo: các màn, route, kết quả chạy thử, số test.
```
