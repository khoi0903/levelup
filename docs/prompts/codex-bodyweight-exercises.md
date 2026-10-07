# Prompt cho Codex – Thêm bài không cần dụng cụ

Hiện có 20 bài (`mongo/seed/exercises.json`), người tập ở nhà không dụng cụ chỉ có 14 bài và **vai, tay, lưng không có
bài nào** (chỉ có bài tạ đơn / dây kháng lực). Hệ quả: tập thêm ít lựa chọn, "Đổi bài" thường chỉ ra 2–3 bài.

```
Bạn đang ở nhánh feat/content-bodyweight (worktree D:\levelup-worktrees\codex-bodyweight), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/codex-bodyweight-exercises.md.
Được sửa: mongo/seed/exercises.json, mongo/cv-configs.json, app/assets/content/form-cues.json,
app/assets/content/voice-lines.json (nếu cần), docs/content/, app/lib/features/camera_counter/ (chỉ khi cần cấu hình
đếm mới), test liên quan. Không sửa backend/.

1. Thêm 12–15 bài KHÔNG cần dụng cụ (equipment: [] hoặc chỉ "mat"), an toàn cho người mới, cùng định dạng bài có sẵn
   (slug, nameVi, nameEn, instructions tiếng Việt 3–5 câu, cues 2–3 ý, primaryMuscle, difficulty 1–3, tracking
   reps|duration, met, contraindications đúng vùng: lower_back|knee|shoulder|neck|wrist|ankle|hip, isActive, cv).
   Ưu tiên nhóm đang thiếu:
   - vai (≥3): ví dụ pike push-up nhẹ, xoay tay vòng tròn, nâng tay chữ Y-T nằm sấp
   - tay (≥3): ví dụ chống đẩy kim cương nghiêng tường, dip ghế, plank chạm vai
   - lưng (≥3): ví dụ superman, thiên thần tuyết nằm sấp, chèo tay nằm sấp (prone row không tạ)
   - thêm 3–5 bài core/cardio/chân/mông nhẹ để buổi đa dạng (dead bug, mountain climber chậm, bird dog có thì bỏ qua
     vì đã có "Duỗi tay chân đối bên", step-up thấp, glute kickback…). Không trùng bài đã có.
2. Camera: chỉ đặt cv.supported=true và thêm mongo/cv-configs.json cho bài mà RepCounter hiện tại đếm ổn định
   (một khớp chính, biên độ góc rõ, nhìn được từ máy đặt ngang hông). Bài khó đếm để cv.supported=false. Thêm test
   synthetic pose cho mỗi cấu hình mới như các bài sẵn có.
3. form-cues.json: thêm mẹo kỹ thuật/lỗi tư thế cho bài có camera, theo đúng schema; chạy
   docs/content/validate_form_cues.py và validate_voice_lines.py.
4. Kiểm tra: JSON hợp lệ, slug không trùng, mọi bài có contraindications hợp lý; mongo load-seed chạy được trên
   MongoDB dev (cổng 27018): cd mongo && docker compose up -d rồi chạy load-seed như README.
   flutter analyze sạch, flutter test --concurrency=2 qua hết.
5. Commit "content: thêm bài không cần dụng cụ cho vai, tay, lưng". Báo Claude Code review kèm bảng bài mới
   (tên, nhóm cơ, kiểu đếm, camera có/không). Claude Code sẽ chạy backend test và nạp lên Atlas.
```
