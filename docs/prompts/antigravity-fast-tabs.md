# Prompt cho Antigravity – Chuyển trang nhanh (hiện dữ liệu cũ ngay, cập nhật ngầm)

Người dùng: chuyển tab/trang mất 1,5–2 giây (vòng xoay). Nguyên nhân: 14 FutureProvider dữ liệu đều `autoDispose`,
không có cache (`keepAlive` = 0) → rời tab là bỏ dữ liệu, quay lại tải lại + spinner toàn màn. Mỗi request lên Render
(Singapore) mất ~0,25–0,45 s, một màn gọi 2–4 request nối nhau.

```
Bạn đang ở nhánh feat/app-fast-tabs (worktree D:\levelup-worktrees\app-fast), không chuyển nhánh, không merge vào
main. Đọc AGENTS.md và docs/prompts/antigravity-fast-tabs.md. Chỉ sửa app/lib, app/test. Không dart format cả thư mục.

1. Cache trong bộ nhớ: thêm extension `cacheFor(Duration)` cho Ref (ref.keepAlive() + Timer hủy sau thời hạn,
   hủy timer khi onDispose). Áp dụng 5 phút cho: userStatusFutureProvider, homePlanProvider, streakFutureProvider,
   streakWeekDetailProvider, nutritionTodayProvider, weeklyPlanFutureProvider, latestReviewFutureProvider,
   buddyTodayFutureProvider, progress (MeasurementHistory), referralViewProvider. KHÔNG cache: foodSearchProvider,
   adminConfigProvider, workoutSetupProvider (đã đọc homePlanProvider), activeWorkoutDraftProvider.
   Mọi chỗ đang ref.invalidate(...) sau khi ghi (lưu buổi tập, check-in, coach áp dụng, đổi bài, đổi lịch, cài đặt)
   phải vẫn làm mới đúng — viết test cho ít nhất: lưu buổi tập xong màn chính thấy số buổi mới.
2. Không spinner toàn màn khi đã có dữ liệu: các màn chính (Trang chủ, Tập, Coach lịch sử, Dinh dưỡng, Tôi, Streak)
   dùng `.when(skipLoadingOnRefresh: true, skipLoadingOnReload: true, ...)` hoặc valueOrNull; khi đang tải lại
   chỉ hiện thanh LinearProgressIndicator mảnh trên đầu. Lần đầu (chưa có dữ liệu) dùng skeleton có sẵn
   (core/widgets/app_skeleton.dart) thay vòng xoay. Lỗi khi đã có dữ liệu cũ: giữ dữ liệu, SnackBar báo lỗi.
3. Kéo xuống để làm mới (RefreshIndicator) ở Trang chủ, Dinh dưỡng, Tôi, Streak: invalidate provider của màn đó.
4. Mở app nhanh: lưu bản JSON cuối cùng của GET /me và GET /plans/current vào shared_preferences theo uid; lúc mở
   app hiện ngay bản đã lưu rồi tải mới ngầm (đã có mạng thì thay). Xoá khi đăng xuất / xoá tài khoản (cùng chỗ
   đang clear SharedPreferences). Không lưu dữ liệu nhạy cảm khác.
5. Tải song song: Trang chủ đang chờ /me rồi mới gọi các API khác thì đổi sang gọi song song những API không phụ
   thuộc nhau (/plans/current, /streak, /buddies/today).
6. Test (repository giả có đếm số lần gọi): vào Trang chủ → sang tab khác → quay lại trong 5 phút KHÔNG gọi lại API
   và không hiện spinner; sau invalidate thì gọi lại; mở app có cache hiện dữ liệu ngay; đăng xuất xoá cache.
   flutter analyze sạch, flutter test --concurrency=2 qua hết.
7. Commit "app: chuyển trang nhanh (cache 5 phút, không spinner khi có dữ liệu, mở app hiện dữ liệu đã lưu)".
   Báo Claude Code review.
```
