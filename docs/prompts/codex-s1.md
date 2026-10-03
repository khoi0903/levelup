# Prompt cho Codex – Sprint 1

## Cài và mở Codex
Cài một lần (đăng nhập bằng tài khoản ChatGPT Plus):
```
npm install -g @openai/codex
```
Mỗi việc có **thư mục riêng** (Git worktree), đã đứng sẵn ở đúng nhánh. Ba việc chạy song song được:

| Việc | Mở Codex trong thư mục | Nhánh |
|---|---|---|
| 1 | `D:\levelup-worktrees\codex-seed` | `feat/seed-exercises` |
| 2 | `D:\levelup-worktrees\codex-content` | `feat/content-coach` |
| 3 | `D:\levelup-worktrees\codex-camera` | `feat/app-camera-counter` |

Ví dụ: `cd D:\levelup-worktrees\codex-seed` rồi gõ `codex`. Hoặc mở thư mục đó bằng VS Code
và dùng extension Codex. Codex tự đọc `AGENTS.md` ở gốc thư mục.

Mỗi việc dưới đây là **một phiên Codex riêng, trong thư mục riêng**. Dán nguyên khối trong mỗi phần.

---

## Việc 1 · 20 bài tập cho thư viện (`mongo/seed/exercises.json`)

```
Bạn đang ở nhánh feat/seed-exercises, không chuyển nhánh. Đọc AGENTS.md trước.
Chỉ được tạo hoặc sửa file mongo/seed/exercises.json, không đụng file nào khác.

Đọc validator của collection "exercises" trong mongo/init.js để biết đúng tên trường,
kiểu dữ liệu và các giá trị enum (tracking, contraindications).

Viết file mongo/seed/exercises.json: một mảng JSON gồm đúng 20 bài tập cho người mới bắt đầu,
tập ở nhà hoặc phòng gym, nội dung tiếng Việt tự nhiên, câu ngắn.
Bắt buộc có: Bật nhảy tại chỗ (jumping jack), Squat không tạ, Squat ôm tạ (goblet squat), Plank,
Glute bridge, Dead bug, Hít đất, Lunge, Đẩy vai tạ đơn. 11 bài còn lại tự chọn cho đủ nhóm cơ
chân, mông, ngực, lưng, vai, tay, core, cardio. Ít nhất 10 bài không cần dụng cụ.

Mỗi phần tử gồm: slug (chữ thường, gạch nối, không dấu, duy nhất), nameVi, nameEn,
instructions (3-5 câu), cues (2-4 lời nhắc ngắn), primaryMuscle (legs, glutes, chest, back,
shoulders, arms, core, full_body, cardio), difficulty (số nguyên 1-5),
tracking (reps | reps_weight | duration), met (số), equipment (chỉ dùng dumbbell, mat,
resistance_band, pullup_bar; [] nếu không cần), contraindications (chỉ dùng các vùng có trong
enum của init.js), isActive: true.
Với squat, push-up, jumping jack, lunge, glute bridge thêm "cv": { "supported": true }.

Không đưa lời khuyên y tế. Chống chỉ định ghi thận trọng.
Kiểm tra JSON hợp lệ và slug không trùng. Commit: "seed: 20 bài tập".
```

> Nhờ một huấn luyện viên thật đọc lại hướng dẫn và chống chỉ định trước khi demo.

---

## Việc 2 · Mẫu tin nhắn AI coach (`docs/content/coach-messages.json`)

```
Bạn đang ở nhánh feat/content-coach, không chuyển nhánh. Đọc AGENTS.md trước.
Chỉ được tạo file docs/content/coach-messages.json.

Viết mẫu tin nhắn cho AI coach của app LevelUp. Vấn đề sản phẩm: 60% người dùng bỏ app vì mất
động lực, nên coach phải giữ chân người dùng, không làm họ thấy tội lỗi.
3 phong cách: strict (ngắn, thẳng, không chê bai), supportive (ấm áp), funny (dí dỏm, không châm chọc).
9 tình huống: checkin_morning, pre_workout, missed_1 (gợi ý bản 5 phút), missed_2 (hỏi điều gì
cản trở: Bận, Mệt, Đau, Chán, Quên), lapsed_7 (mời quay lại, nhắc lý do của họ), workout_done,
new_pr, weekly_win, checkin_tired. Mỗi tình huống x mỗi phong cách: 3 biến thể.
Biến: {ten}, {ly_do}, {so_buoi}, {bai_tap}, {so_lieu}, {thoi_luong}.

Quy tắc: tối đa 2 câu và 160 ký tự; mỗi tin một hành động; không trách móc, không so sánh với
người khác, không nói tiêu cực về cân nặng hay ngoại hình; không lời khuyên y tế; strict không emoji,
hai phong cách còn lại tối đa 1 emoji.
Định dạng: { "checkin_morning": { "strict": [..3..], "supportive": [..], "funny": [..] }, ... }
Viết thêm một script kiểm tra nhỏ (hoặc tự kiểm) để chắc không tin nào quá 160 ký tự.
Commit: "content: mẫu tin nhắn coach".
```

---

## Việc 3 · Thuật toán đếm squat (`app/lib/features/camera_counter/`)

```
Bạn đang ở nhánh feat/app-camera-counter, không chuyển nhánh. Đọc AGENTS.md và mục F2b trong docs/04-backend-flow.html.
Chỉ được tạo hoặc sửa file trong:
  app/lib/features/camera_counter/
  app/test/features/camera_counter/
Không sửa pubspec.yaml, không sửa giao diện, không thêm package (Antigravity sẽ nối với camera
và ML Kit sau). Đây là phần lõi Dart thuần, chạy được bằng unit test.

Cần làm trong app/lib/features/camera_counter/domain/:
1. Model khung xương: PoseLandmark(type, x, y, likelihood) cho các khớp vai, hông, gối,
   cổ chân hai bên; PoseFrame(timestamp, landmarks).
2. Hàm tính góc tại một khớp từ 3 điểm (ví dụ hông–gối–cổ chân).
3. CvConfig đọc từ JSON (giống trường "cv.configs[].config" của collection exercises):
   { "joints": ["hip","knee","ankle"], "downBelow": 95, "upAbove": 160, "minConfidence": 0.6,
     "minRepMs": 600 }
4. RepCounter: máy trạng thái up -> down -> up = 1 lần.
   - Chọn bên người (trái/phải) có độ tin cậy cao hơn trong mỗi khung.
   - Bỏ qua khung có độ tin cậy dưới minConfidence.
   - Chống rung: góc phải vượt ngưỡng ít nhất 2 khung liên tiếp mới đổi trạng thái.
   - Một lần dưới minRepMs thì không tính (tránh đếm khi người dùng lắc).
   - Trả về: số lần, độ tin cậy trung bình, danh sách lần tập kèm góc sâu nhất.
5. FormChecker cho squat: "shallow_depth" nếu góc gối sâu nhất > 100 độ; trả về
   danh sách { repIndex, code, severity 1-3 }. Tính formScore 0-100.
6. Trạng thái "không thấy người": quá 1 giây không có khung đủ tin cậy thì báo để giao diện
   tạm dừng.

Unit test trong app/test/features/camera_counter/ với dữ liệu giả lập:
- 10 lần squat chuẩn -> đếm đúng 10
- có nhiễu (góc dao động quanh ngưỡng) -> không đếm thừa
- 3 lần squat nông -> có 3 lỗi shallow_depth
- khung độ tin cậy thấp xen giữa -> không làm sai số lần
Chạy: cd app && flutter test test/features/camera_counter
Commit nhỏ theo từng bước.
```

---

## Quy tắc chung khi dùng Codex
- Mỗi việc một thư mục và một nhánh riêng. Không chạy `git checkout` hay `git switch`, không làm trên `main`.
- Codex xong thì báo Claude Code review nhánh đó trước khi merge.
- Không dán API key, mật khẩu, connection string thật vào Codex.
