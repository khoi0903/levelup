# Prompt cho Codex – Bộ câu đọc giọng nói khi tập (7 phong cách)

App sắp có giọng đọc khi tập (Antigravity làm bằng `flutter_tts`, giọng tiếng Việt có sẵn trong máy, không cần
mạng): đếm số lần, báo sắp xong, đếm lùi bài giữ, nhắc tư thế, nghỉ, bắt đầu. Mục đích chính: người mắt kém hoặc
đặt điện thoại xa (để camera thấy cả người) vẫn biết mình tới lần thứ mấy.

Giọng máy chỉ có 1–2 giọng tiếng Việt, nên "tính cách" thể hiện qua **câu chữ + tốc độ + cao độ**.
Phong cách giọng là cài đặt riêng trong app (mặc định theo coachStyle của người dùng: supportive | strict | funny).

7 phong cách (id cố định, app dùng đúng id này):

| id | Tên hiển thị | Tinh thần |
|---|---|---|
| `supportive` | Động viên | ấm áp, khen từng tiến bộ nhỏ |
| `strict` | Nghiêm khắc | ngắn, dứt khoát, không than vãn |
| `funny` | Hài hước | đùa nhẹ, tự nhiên, không xúc phạm |
| `calm` | Bình tĩnh | chậm, nhắc hít thở, nhẹ nhàng |
| `hype` | Bùng nổ | như bình luận viên thể thao, nhiều năng lượng |
| `genz` | Bạn thân Gen Z | thân mật kiểu giới trẻ, dễ hiểu, không tục |
| `minimal` | Tối giản | chỉ số và lệnh ngắn nhất (dành cho người mắt kém / thích yên tĩnh) |

---

```
Bạn đang ở nhánh feat/codex-voice-lines (worktree D:\levelup-worktrees\codex-voice), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md, docs/prompts/codex-voice-lines.md, docs/content/coach-messages.json
(văn phong coach hiện có). Lần này bạn được tạo đúng MỘT file trong app: app/assets/content/voice-lines.json
(file nội dung, app đọc làm asset). Ngoài ra chỉ sửa docs/. Không sửa code Dart, backend/, mongo/.

1. app/assets/content/voice-lines.json, cấu trúc:
   {
     "version": 1,
     "styles": {
       "<id>": {
         "nameVi": "...", "descriptionVi": "... (1 câu cho màn chọn)",
         "rate": 0.5,      // tốc độ flutter_tts 0.0–1.0 (0.5 ≈ bình thường), calm thấp hơn, hype/strict cao hơn
         "pitch": 1.0,     // 0.5–2.0
         "countEvery": 1,  // đọc số mỗi n lần (minimal = 1, chỉ số)
         "lines": {
           "start_countdown": [...],   // trước hiệp: có {n} là số giây đếm, ví dụ "Chuẩn bị, {n}"
           "go": [...],                // "Bắt đầu!"
           "rep": [...],               // đọc số lần: "{n}" (mặc định chỉ số; phong cách khác có thể thêm chữ ngắn)
           "almost_done": [...],       // còn {left} lần, {left} = 3
           "last_rep": [...],          // lần cuối
           "set_done": [...],          // xong hiệp {set}/{sets}
           "rest_start": [...],        // nghỉ {sec} giây
           "rest_ending": [...],       // còn {sec} giây nghỉ (sec = 10)
           "hold_remaining": [...],    // bài giữ/thời gian: còn {sec} giây (đọc ở 30, 20, 10)
           "hold_last": [...],         // 5 giây cuối, chỉ đọc số: "{sec}"
           "form_generic": [...],      // nhắc tư thế chung khi camera thấy sai
           "lost_person": [...],       // camera không thấy người: "Lùi ra để thấy cả người"
           "exercise_next": [...],     // bài tiếp theo: {exercise}
           "workout_done": [...],      // xong buổi: {minutes} phút, {kcal} kcal (kcal có thể thiếu → câu không dùng kcal)
           "personal_record": [...]    // kỷ lục mới
         }
       }
     }
   }
   - Mỗi khóa trong "lines" 3–6 câu (minimal 1–2), app chọn ngẫu nhiên, không lặp câu liền nhau.
   - Câu NGẮN để đọc kịp giữa hai lần (rep ≤ 4 từ, almost_done ≤ 8 từ). Viết số bằng chữ số trong placeholder,
     để giọng máy tự đọc ("{n}" → "mười hai").
   - Tiếng Việt có dấu, tự nhiên, không tục, không body-shaming, không hứa hẹn y khoa. Gen Z: thân mật nhưng
     người lớn tuổi vẫn hiểu (tránh từ lóng khó hiểu, viết tắt không đọc được như "kkk", emoji).
   - Placeholder chỉ dùng đúng tên đã liệt kê.
2. docs/content/voice-lines.md: bảng 7 phong cách (tên, tinh thần, rate/pitch, ví dụ 3 câu), quy tắc viết câu,
   cách thêm phong cách mới.
3. Kiểm tra (script Python trong docs/content/ hoặc mô tả lệnh chạy, không cần test Dart): đủ 7 id, đủ 15 khóa
   lines cho mỗi id, không placeholder lạ, độ dài rep/almost_done đúng giới hạn, JSON hợp lệ UTF-8.
4. Commit trên feat/codex-voice-lines: "content: câu đọc giọng nói khi tập, 7 phong cách". Báo Claude Code review.
```
