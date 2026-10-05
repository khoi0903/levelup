# Prompt cho Antigravity – Lưu buổi tập offline (drift), coach hiện chữ dần, sửa đổi tài khoản

## API coach streaming (Claude Code làm ở backend, nhánh feat/be-coach-stream)

`POST /coach/messages/stream` – body giống `POST /coach/messages` (`{"text": "..."}`), header Authorization như cũ.
Trả `Content-Type: text/event-stream` (Server-Sent Events). Các event:

```
event: delta
data: {"text":"Chào Khôi, hôm nay "}        ← phần chữ mới của câu trả lời, nối tiếp nhau

event: done
data: { ...giống hệt body của POST /coach/messages: userMessage, reply, remainingToday... }

event: error
data: {"code":"COACH_LIMIT"}                 ← hoặc mã lỗi khác; dùng mapErrorMessage
```

- `done` là bản cuối đã được backend kiểm tra (kể cả thẻ đề xuất `card`). Nội dung `reply.content` trong `done`
  có thể khác chút với chữ đã ghép từ `delta` (AI lỗi thì backend dùng câu trả lời dự phòng) → luôn thay bằng `done`.
- Có thể không có `delta` nào (AI không chạy) mà tới thẳng `done`.
- Server cũ chưa có endpoint → 404: quay về gọi `POST /coach/messages` như hiện tại.

---

```
Bạn đang ở nhánh feat/app-offline-coach (worktree D:\levelup-worktrees\app-offline-coach), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-offline-coach-stream.md.
Chỉ sửa app/lib, app/test, app/pubspec.yaml (KHÔNG sửa app/android/** – Codex đang sửa build.gradle.kts và
proguard ở nhánh khác; không sửa camera_counter/, backend/, mongo/). Không chạy dart format cho cả thư mục.

1. Lưu buổi tập đang tập xuống máy (drift, AGENTS.md đã chọn drift):
   - Thêm drift + drift_flutter (hoặc sqlite3_flutter_libs) + path_provider, build_runner/drift_dev ở dev_dependencies.
     Commit cả file *.g.dart sinh ra.
   - Bảng workout_drafts: clientId (khóa), sessionId, json trạng thái (WorkoutSessionState: các set đã ghi,
     exerciseIndex, setNumber, startedAt…), updatedAt, status (active | pending_submit).
   - Lưu sau mỗi set ghi xong và khi chuyển bài. Xóa khi POST /workouts thành công.
   - Mở app mà còn draft active (dưới 12 giờ): Trang chủ hiện thẻ "Bạn đang tập dở <tên buổi> · Tiếp tục / Bỏ".
     Tiếp tục → vào lại màn tập đúng bài, đúng set. Bỏ → xóa draft. Quá 12 giờ → tự xóa.
   - Gửi buổi tập lỗi mạng: chuyển draft sang pending_submit, hiện "Đã lưu trên máy, sẽ gửi khi có mạng".
     Mỗi lần mở app hoặc vào Trang chủ thử gửi lại (cùng clientId nên backend không lưu trùng).
   - Repository qua interface + bản giả trong bộ nhớ cho test (giống CameraSetupSkip).
   - Không lưu video/ảnh camera (AGENTS.md: video không rời điện thoại, cũng không cần lưu).

2. Coach hiện chữ dần (API ở trên):
   - Gửi tin: tin người dùng hiện ngay như hiện tại; bong bóng coach xuất hiện và chữ lớn dần theo từng delta
     (bỏ dòng "Coach đang trả lời…" khi delta đầu tiên tới). Event done → thay cả hai tin bằng bản từ server
     (id thật, card nếu có), cập nhật remainingToday.
   - Dio: responseType stream, tách event theo dòng trống, parse "event:" và "data:". Viết parser riêng có test.
   - Lỗi giữa chừng / event error: gỡ bong bóng tạm, trả lại chữ vào ô nhập như hiện tại, hiện mapErrorMessage.
   - 404 từ endpoint stream → dùng POST /coach/messages (giữ nguyên luồng cũ).
   - Repository giả cho test phát delta theo thời gian (StreamController).

3. Đổi tài khoản / đăng xuất: mọi đường đăng xuất (Cài đặt, nút "Đổi tài khoản" ở onboarding, 401) phải reset
   onboardingControllerProvider (và các provider giữ dữ liệu người cũ) để người sau không thấy tên/mục tiêu đã
   nhập của người trước. Xóa luôn draft buổi tập của người cũ.

4. Test: draft lưu/khôi phục/hết hạn, gửi lại pending, parser SSE (nhiều event trong một chunk, event bị cắt giữa
   hai chunk, tiếng Việt UTF-8 bị cắt giữa byte), coach stream (delta → done thay tin, error trả chữ, 404 dùng
   endpoint cũ), đăng xuất reset onboarding. flutter analyze sạch, flutter test qua hết.

5. Commit trên feat/app-offline-coach, dạng "app: lưu buổi tập offline (drift), coach hiện chữ dần".
   Báo lại để Claude Code review.
```
