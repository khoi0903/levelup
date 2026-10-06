# Prompt cho Antigravity – Giọng đọc khi tập (7 phong cách) + ảnh mẫu bài tập

**Giọng đọc:** `flutter_tts` với giọng tiếng Việt có sẵn của Android (Google TTS, không cần mạng). Nội dung câu đọc do
Codex soạn ở `app/assets/content/voice-lines.json` (nhánh feat/codex-voice-lines, cấu trúc trong
`docs/prompts/codex-voice-lines.md`). Trong lúc chờ file thật, dùng file mẫu nhỏ trong test.

**Ảnh mẫu:** `app/assets/exercises/<slug>.webp` (slug như `bodyweight-squat`, xem mongo/seed/exercises.json).
Claude Code sẽ thêm 20 ảnh sau; code phải chạy được khi chưa có ảnh (hiện icon thay thế). Nếu bài có
`thumbnailUrl` từ GET /exercises thì ưu tiên URL đó, rồi mới tới ảnh trong app.

---

```
Bạn đang ở nhánh feat/app-voice (worktree D:\levelup-worktrees\app-voice), không chuyển nhánh, không merge vào main.
Đọc AGENTS.md, docs/prompts/antigravity-voice-images.md, docs/prompts/codex-voice-lines.md.
Chỉ sửa app/lib, app/test, app/pubspec.yaml (KHÔNG tạo/sửa app/assets/content/voice-lines.json – Codex làm;
không sửa camera_counter/, backend/, mongo/, app/android trừ khi flutter_tts bắt buộc). Không dart format cả thư mục.

1. VoiceCoach (lib/features/workout/... hoặc lib/core/voice/):
   - Interface + FlutterTtsVoiceCoach + FakeVoiceCoach (ghi lại câu đã nói, cho test).
   - Đọc voice-lines.json từ asset (đăng ký app/assets/content/ trong pubspec). Thiếu file / thiếu khóa → câu mặc
     định ngắn trong code, không crash.
   - Ngôn ngữ vi-VN; máy không có giọng tiếng Việt → tắt giọng đọc và báo một lần "Máy chưa có giọng đọc tiếng
     Việt, cài Google Text-to-Speech để bật".
   - Chọn câu ngẫu nhiên trong danh sách, không lặp câu liền trước; thay placeholder {n} {left} {set} {sets} {sec}
     {exercise} {minutes} {kcal}.
   - Hàng đợi: câu mới quan trọng hơn (số lần) ngắt câu dài đang đọc; không đọc chồng.
   - Giảm âm lượng nhạc khác khi đang đọc nếu flutter_tts hỗ trợ (audio ducking), không thì bỏ qua.
2. Nối vào luồng tập (màn đang tập + màn camera + màn nghỉ):
   - đếm lùi trước hiệp + "go"; mỗi lần đếm được (camera hoặc bấm tay) → "rep" theo countEvery;
     còn 3 lần → "almost_done"; lần cuối → "last_rep"; xong hiệp → "set_done" + "rest_start";
     nghỉ còn 10 giây → "rest_ending"; bài giữ/thời gian: 30/20/10 giây → "hold_remaining", 5 giây cuối → "hold_last";
     camera báo sai tư thế → "form_generic" (tối đa 1 lần / 8 giây); mất người → "lost_person";
     chuyển bài → "exercise_next"; xong buổi → "workout_done" (có kcalBurned thì đọc), kỷ lục → "personal_record".
   - Không đọc khi app ở nền.
3. Cài đặt (màn Cài đặt, lưu bằng shared_preferences, không gửi backend):
   - Công tắc "Giọng đọc khi tập" (mặc định bật).
   - "Phong cách giọng": "Theo phong cách coach" (mặc định, dùng profile.coachStyle) + 7 phong cách (nameVi,
     descriptionVi từ JSON), nút ▶ nghe thử mỗi phong cách.
   - "Tốc độ đọc": chậm / vừa / nhanh (nhân với rate của phong cách).
   - Gợi ý dưới "Tối giản": "Phù hợp người mắt kém: chỉ đọc số và lệnh ngắn".
   - Nút loa bật/tắt nhanh ngay trên màn đang tập.
4. Ảnh mẫu bài tập: widget ExerciseImage(slug, thumbnailUrl): thumbnailUrl → ảnh mạng (có cache, lỗi thì
   rơi xuống asset); không có → assets/exercises/<slug>.webp; không có asset → icon tạ trên nền nhạt.
   Hiện ở: màn bắt đầu buổi (mỗi dòng bài), màn đang tập (ảnh lớn ở trên), màn Tập thêm (danh sách chọn bài),
   màn đặt camera. Đăng ký app/assets/exercises/ trong pubspec (tạo thư mục với .gitkeep).
5. Accessibility: các nút chính có Semantics label tiếng Việt; số lần trên màn đang tập có liveRegion để TalkBack
   đọc khi đổi.
6. Test: chọn câu + placeholder + không lặp; countEvery; luồng tập gọi đúng thứ tự (go → rep… → almost_done →
   last_rep → set_done → rest_start) với FakeVoiceCoach; tắt giọng thì không gọi; ExerciseImage rơi về icon khi
   thiếu ảnh. flutter analyze sạch, flutter test qua hết.
7. Commit trên feat/app-voice: "app: giọng đọc khi tập 7 phong cách, ảnh mẫu bài tập". Báo Claude Code review.
```
