# Prompt cho Codex – Camera không đếm từ hiệp thứ 2

Feedback người test Kiên (2026-10-07), máy thật Android:

> Test bài squat không tạ, để camera trên mặt ghế ngồi cỡ trên hông. Hiệp đầu đếm ổn bình thường, sang hiệp sau thì
> không đếm nữa. Thoát bài đó vào lại thì đếm lại được bình thường nhưng phải làm lại các hiệp.

Vậy không phải ngưỡng góc hay vị trí đặt máy: lỗi ở vòng đời camera/phiên đếm giữa hai hiệp.

Luồng hiện tại (đọc trước khi sửa):
- `workout_active_screen.dart` `_countWithCamera`: mỗi hiệp `context.push('/workout/camera')` → `CameraSetScreen` mới.
  Có "Tự mở camera khi bắt đầu hiệp" (`_maybeAutoCamera`, key `exerciseIndex/setNumber/exerciseId`).
- `camera_set_screen.dart`: hiệp 1 thường qua `_SetupView`; nếu đã chọn "không hỏi lại hôm nay" thì vào thẳng
  `_CountingView` (khác đường so với hiệp 1). `_CountingView.initState` tạo phiên qua `repSessionFactoryProvider`,
  `_finish` chờ `session.stop()`, `dispose` gọi `stop()` không chờ.
- `features/workout/data/camera/rep_counting_session.dart` → `CameraRepSession` (`camera_counter/data`): mỗi phiên tạo
  `FrontCameraRepDevice` + `MlkitStreamPoseDetector` mới, hàng đợi `_enqueue`, `_generation`, `_processing`.

```
Bạn đang ở nhánh fix/codex-camera-set2 (worktree D:\levelup-worktrees\codex-camera-set2), không chuyển nhánh, không
merge vào main. Đọc AGENTS.md và docs/prompts/codex-camera-set2.md.
Được sửa: app/lib/features/camera_counter/, app/lib/features/workout/data/camera/,
app/lib/features/workout/presentation/screens/camera_set_screen.dart (chỉ phần vòng đời camera/phiên đếm),
app/test/. Không dart format cả thư mục.

1. Tìm nguyên nhân hiệp 2 không đếm. Viết test tái hiện TRƯỚC khi sửa: hai phiên CameraRepSession/
   _CameraRepCountingSession liên tiếp với camera + detector giả (phiên 1 start → có rep → stop; phiên 2 start →
   frame mới phải tăng repCount). Thêm widget test: CameraSetScreen hiệp 1 đếm, pop, mở hiệp 2 (cả đường đi qua
   _SetupView và đường "không hỏi lại hôm nay") → hiệp 2 vẫn nhận kết quả. Nghi vấn cần kiểm:
   - phiên cũ chưa nhả camera xong (dispose gọi stop() không chờ) khi phiên mới initialize;
   - generation/_acceptFrames/_processing kẹt (frame bị bỏ hết);
   - stream results: listen sau khi phiên phát/đóng; _latest cũ; snapshot của hiệp trước;
   - countdown/_countingDown hoặc targetReps hiệp 2 (args.targetReps lấy từ _reps) làm tự kết thúc ngay;
   - RepCounter/presence (personMissing) trạng thái chung giữa hai hiệp.
2. Sửa tận gốc, giữ nguyên hành vi hiệp 1. Nếu cần, màn camera chờ phiên cũ stop xong trước khi start phiên mới.
3. Thêm log debug (debugPrint, chỉ khi kDebugMode) ở start/stop/frame đầu tiên của mỗi phiên để lần sau dễ soi.
4. flutter analyze sạch, flutter test --concurrency=2 qua hết.
5. Commit "app: camera đếm được ở mọi hiệp, không chỉ hiệp đầu". Báo Claude Code review, ghi rõ nguyên nhân tìm được.
```
