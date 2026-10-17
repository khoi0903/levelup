# Prompt cho Antigravity – Hỏi thăm vùng đau sau buổi tập

Hiện tại: báo đau ở màn kết thúc buổi thì buổi sau luôn bị giảm nhẹ, không ai hỏi lại. Người chỉ mỏi cơ cũng bị
tập nhẹ. Đổi thành: phân biệt mỏi cơ / đau nhói, hôm sau hỏi thăm, hết đau thì tập bình thường.

Backend (Claude Code, nhánh feat/be-pain-followup):
- `POST /workouts` thêm trường tuỳ chọn `painType`: `"soreness"` (mỏi cơ bình thường: không đổi lịch, không hỏi lại)
  hoặc `"sharp"` (đau nhói / đau khớp: theo dõi vùng đó, đổi bài có hại cho vùng đó ở các buổi còn lại, từ hôm sau
  hỏi thăm). Chỉ gửi khi `painAreas` không rỗng. Không gửi `painType` thì như cũ (bớt 1 hiệp buổi sau).
- `GET /me` thêm `painFollowUps`: danh sách vùng cần hỏi thăm hôm nay, rỗng nếu không có:
  `[{"bodyArea":"knee","label":"đầu gối","reportedOn":"2026-10-16","days":1}]`.
  Hôm báo đau chưa có; đã trả lời trong ngày thì biến mất tới hôm sau.
- `POST /pain-followups/{bodyArea}` body `{"answer":"gone|better|same|worse"}` → 200
  `{"status":"resolved|monitoring|injury","message":"...","plan":{...PlanView như GET /plans/current...}}`.
  gone → hết theo dõi, tập bình thường. better / same → vẫn tránh vùng này, mai hỏi lại. worse, hoặc same sau 3 ngày
  → `injury`: khuyên đi khám, vùng này bị tránh cho tới khi người dùng báo đã khỏi. Riêng `gone` dùng được cho mọi
  vùng đang tránh (kể cả chấn thương khai lúc onboarding). Vùng không còn theo dõi (với answer khác gone) → 404
  `PAIN_FOLLOWUP_NOT_FOUND`.
- `GET /me` thêm `activeInjuries`: `[{"bodyArea":"knee","label":"đầu gối","followUp":false}]`, các vùng đang bị tránh
  khi chọn bài.
- Thông báo đẩy `type: "pain_followup"`, `data.route: "/home"`, buổi sáng từ 8:00, tối đa 1 tin/ngày.
- `GET /exercises` đã tự bỏ bài chống chỉ định với vùng đang đau/đang theo dõi.

```
Bạn đang ở nhánh feat/app-pain-followup (worktree D:\levelup-worktrees\app-pain-followup), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-pain-followup.md.
Chỉ sửa app/lib, app/test. Không dart format cả thư mục. Màu theo app_colors.dart, bố cục theo các thẻ sẵn có.

1. Màn kết thúc buổi (workout_finish_screen), mục "Có chỗ nào đau không?": khi đã chọn ít nhất 1 vùng, hiện thêm
   2 lựa chọn (SelectionChip, bắt buộc chọn 1, mặc định chưa chọn → nút Lưu nhắc chọn):
   - "Mỏi cơ bình thường" → painType "soreness". Dòng gợi ý: "Mỏi sau tập là bình thường. Giãn cơ, uống đủ nước nhé."
   - "Đau nhói / đau khớp" → painType "sharp". Dòng gợi ý: "Coach sẽ đổi bài tránh vùng này và hỏi thăm bạn ngày mai.
     Đau kéo dài thì nên đi khám."
   Thêm painType vào WorkoutDraft / request (lưu cả trong nháp offline drift, đọc lại được).
2. Trang chủ (home_screen): nếu /me.painFollowUps không rỗng, hiện thẻ "Hỏi thăm" ở trên cùng (trên thẻ buổi hôm nay),
   mỗi vùng một thẻ: tiêu đề "<Label viết hoa chữ đầu> hôm nay sao rồi?", phụ đề "Báo đau <days> ngày trước".
   4 nút: "Hết đau" (gone), "Đỡ hơn" (better), "Vẫn đau" (same), "Đau hơn" (worse).
   Bấm → POST /pain-followups/{bodyArea}; đang gửi thì khoá nút; xong hiện message của backend (SnackBar hoặc thay
   nội dung thẻ 3 giây rồi ẩn), invalidate /me và kế hoạch tuần (homePlanProvider, plans/current) để buổi hôm nay
   cập nhật bài. status "injury" thì hiện message dạng cảnh báo (màu warning), không tự ẩn cho tới khi bấm "Đã hiểu".
   404 → ẩn thẻ, refresh /me. Lỗi khác → mapErrorMessage, giữ thẻ.
3. Tập thêm khi đang có vùng đau (workout_extra_screen): nếu /me.painFollowUps không rỗng hoặc người dùng vừa báo đau
   nhói hôm nay (painType sharp trong buổi vừa lưu), hiện dòng nhắc nhẹ ở đầu màn: "Bạn đang đau <label>. Nghỉ cũng là
   một phần của tập luyện; nếu vẫn muốn tập, mình đã bỏ bài tác động vào vùng này." Vẫn cho tập, không chặn.
   Thêm 2 lựa chọn nhanh: "Tập phần khác" (danh sách từ GET /exercises như hiện tại, đã lọc sẵn) và "Bản nhẹ 10 phút"
   (chỉ bài difficulty ≤ 2, ít hiệp, tổng ~10 phút). Buổi từ 5 phút vẫn tính streak như thường.
4. Tab Tôi: mục "Vùng đang tránh" liệt kê /me.activeInjuries (ẩn nếu rỗng). Mỗi dòng có nút "Đã khỏi" → hỏi xác nhận
   → POST /pain-followups/{bodyArea} {"answer":"gone"} → refresh /me và kế hoạch, SnackBar message.
5. Bấm thông báo pain_followup (route "/home") → mở Trang chủ, thẻ hỏi thăm hiện ngay (refresh /me khi mở app từ
   thông báo).
6. Test (repository giả): chọn vùng đau bắt buộc chọn loại đau, gửi đúng painType; thẻ hỏi thăm hiện khi
   painFollowUps có dữ liệu và gọi đúng POST /pain-followups/knee {"answer":"same"}; 404 ẩn thẻ; status injury hiện
   cảnh báo; màn tập thêm hiện dòng nhắc khi đang đau; "Đã khỏi" gửi answer gone. flutter analyze sạch, flutter test --concurrency=2 qua hết.
7. Commit "app: hỏi thăm vùng đau sau buổi tập, phân biệt mỏi cơ và đau nhói". Báo Claude Code review.
```

Chưa có bài giãn cơ trong thư viện bài tập (không có primaryMuscle kiểu mobility/stretch), nên "Bản nhẹ" dùng bài
difficulty thấp. Khi có nội dung giãn cơ (giao Codex), đổi lựa chọn này thành "Giãn cơ 10 phút".
