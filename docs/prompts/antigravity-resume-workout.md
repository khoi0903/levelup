# Prompt cho Antigravity – Tiếp tục buổi tập đang dở

Feedback người dùng (2026-10-07): "khi tập dở vô lại nó bắt tập lại từ đầu".

Hiện trạng: `WorkoutController` đã lưu nháp sau mỗi thao tác (`_saveDraft(status: 'active')`, drift,
`workoutDraftRepositoryProvider`), có sẵn `getActiveDraft()`, `WorkoutSessionState.fromJson`, `restore()`, `discard()`,
nháp hết hạn sau 12 giờ (`isExpired`). Nhưng không màn nào đọc lại nháp: bấm "Bắt đầu" luôn gọi `start(setup)` tạo
buổi mới; đóng app thì mất `activeWorkoutProvider`.

```
Bạn đang ở nhánh feat/app-resume-workout (worktree D:\levelup-worktrees\app-resume), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-resume-workout.md.
Chỉ sửa app/lib, app/test. Không dart format cả thư mục.

1. Khi vào màn bắt đầu buổi (workout_start_screen) hoặc bấm "Bắt đầu"/"Chỉ có 5 phút" ở màn chính:
   - Nếu activeWorkoutProvider đang giữ buổi chưa xong của CÙNG session.id → vào thẳng màn đang tập, đúng bài/hiệp.
   - Nếu không, đọc getActiveDraft(): còn hạn, cùng session.id (hoặc buổi tập thêm cùng id extra-…) và còn hiệp
     chưa xong → hỏi bằng dialog "Bạn đang tập dở buổi này (đã xong X/Y hiệp). Tiếp tục?" với hai nút
     "Tiếp tục" (restore(WorkoutSessionState.fromJson(...)) rồi vào màn đang tập) và "Tập lại từ đầu"
     (discard() rồi start như cũ).
   - Nháp của buổi KHÁC: không hỏi, xoá nháp cũ khi bắt đầu buổi mới.
   - Nháp status 'pending_submit' (đã tập xong, chưa gửi được) giữ nguyên luồng gửi lại hiện có, không đụng.
2. Màn chính: nếu có buổi đang tập dở (provider hoặc nháp còn hạn) thì nút "Bắt đầu" đổi chữ thành "Tiếp tục buổi tập".
3. Giữ startedAt gốc khi tiếp tục (thời lượng tính từ lúc bắt đầu thật; nếu nghỉ quá lâu thì backend vẫn nhận vì
   endedAt chốt lúc finish). clientId giữ nguyên để không gửi trùng.
4. Test (repository giả): có nháp cùng buổi → hiện dialog, "Tiếp tục" vào đúng bài/hiệp với các hiệp đã ghi;
   "Tập lại từ đầu" xoá nháp; nháp hết hạn hoặc khác buổi → không hỏi; provider đang giữ buổi → vào thẳng.
   flutter analyze sạch, flutter test --concurrency=2 qua hết.
5. Commit "app: tiếp tục buổi tập đang dở". Báo Claude Code review.
```
