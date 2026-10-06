# Prompt cho Codex – Câu nhắc tư thế riêng cho từng bài (giọng đọc khi tập)

Giọng đọc (app/assets/content/voice-lines.json) hiện chỉ có câu nhắc chung `form_generic` ("chỉnh tư thế nhé").
Bộ đếm camera đã báo lỗi tư thế theo **mã** cho từng bài (`FormIssue.code`, cấu hình trong mongo/cv-configs.json).
Hiện có 22 cặp (bài, mã lỗi):

| slug | mã lỗi |
|---|---|
| bird-dog | leg_not_extended |
| bodyweight-squat | shallow_depth |
| dead-bug | leg_not_extended |
| dumbbell-bent-over-row | row_not_high_enough |
| dumbbell-biceps-curl | curl_not_full_range |
| dumbbell-floor-press | press_not_locked_out |
| dumbbell-shoulder-press | press_not_locked_out |
| glute-bridge | bridge_hips_not_high_enough |
| goblet-squat | shallow_depth |
| jumping-jack | arms_not_overhead |
| march-in-place | torso_leaning |
| plank | body_not_straight |
| push-up | body_not_straight, pushup_not_deep_enough |
| reverse-lunge | lunge_not_deep_enough |
| seated-resistance-band-row | row_not_high_enough |
| side-lying-leg-raise | leg_not_high_enough |
| standing-calf-raise | heels_not_high_enough |
| step-jack | arms_not_straight |
| wall-push-up | body_not_straight, pushup_not_deep_enough |
| wall-sit | knee_not_at_90 |

---

```
Bạn đang ở nhánh feat/codex-form-cues (worktree D:\levelup-worktrees\codex-form-cues), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md, docs/prompts/codex-form-cues.md, docs/content/voice-lines.md,
mongo/seed/exercises.json (cues, instructions đã có của từng bài), mongo/cv-configs.json (formRules).
Chỉ tạo/sửa app/assets/content/form-cues.json và docs/content/. Không sửa code Dart, backend/, mongo/.

1. app/assets/content/form-cues.json:
   {
     "version": 1,
     "exercises": {
       "<slug>": {
         "startTip": ["...", "..."],          // 1–2 câu: điểm kỹ thuật quan trọng nhất, đọc khi bắt đầu bài (≤ 12 từ)
         "issues": {
           "<mã lỗi>": {
             "cue": ["...", "...", "..."],    // 2–3 câu SỬA cụ thể, nói việc cần làm (≤ 8 từ): "Hạ hông thấp hơn"
             "minimal": ["..."]               // 1 câu cực ngắn cho phong cách Tối giản (≤ 4 từ): "Xuống sâu hơn"
           }
         }
       }
     }
   }
   - Đủ 20 slug trong mongo/seed/exercises.json (bài nào không có mã lỗi vẫn có startTip) và đủ 22 cặp ở bảng trên.
   - Câu nói VIỆC CẦN LÀM (khẳng định), không chê ("sai rồi", "kém"). Trung tính để ghép với mọi phong cách;
     app có thể thêm lời theo phong cách trước/sau câu.
   - An toàn: không khuyến khích ép quá sức; bài liên quan khớp gối/lưng nhắc kiểm soát, không nhắc "cố thêm" khi
     đau. Không hứa hẹn y khoa.
   - Tiếng Việt tự nhiên, đọc bằng giọng máy vẫn rõ (tránh từ tiếng Anh, viết tắt, ký hiệu).
2. docs/content/form-cues.md: bảng từng bài (startTip + mỗi mã lỗi và câu nhắc), quy tắc viết, cách thêm mã mới
   khi cv-configs có formRule mới.
3. Mở rộng docs/content/validate_voice_lines.py (hoặc script mới validate_form_cues.py): đủ 20 slug, đủ 22 cặp và
   khớp đúng mã trong mongo/cv-configs.json (đọc file), giới hạn số từ, JSON UTF-8 hợp lệ.
4. Commit trên feat/codex-form-cues: "content: câu nhắc tư thế riêng cho từng bài". Báo Claude Code review.
```

## Phần app (Antigravity, làm sau khi xong feat/app-voice)

Khi camera báo `FormIssue(code)` ở bài `slug`: đọc `exercises[slug].issues[code].cue` (phong cách Tối giản dùng
`minimal`), không có thì dùng `form_generic` của voice-lines.json. Giữ giới hạn 1 lần / 8 giây. Đầu mỗi bài đọc
`startTip` (sau câu "exercise_next"), tắt được trong cài đặt "Đọc mẹo kỹ thuật đầu bài".
