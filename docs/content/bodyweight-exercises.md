# Bổ sung bài không cần dụng cụ — bàn giao Claude Code

Nhánh `feat/content-bodyweight`, worktree `D:\levelup-worktrees\codex-bodyweight`.
Thêm 14 bài vào 20 bài gốc: 3 vai, 3 tay, 3 lưng, 5 core/cardio/chân/mông.
Mọi bài mới có `equipment: []` hoặc `["mat"]`; tường là bề mặt cố định như bài hít đất tường hiện có.
Không dùng ghế, bục hoặc tạ. Dead bug và bird dog đã có nên không thêm lại.

| Tên | Slug | Nhóm cơ | Kiểu đếm | Camera |
|---|---|---|---|---|
| Xoay tay vòng tròn nhỏ | `arm-circles` | Vai | Thời gian | Không |
| Nâng tay chữ Y và T nằm sấp | `prone-y-t-raise` | Vai | Số lần | Không |
| Trượt tay trên tường | `wall-slide` | Vai | Số lần | Không |
| Hít đất tường tay hẹp | `close-grip-wall-push-up` | Tay | Số lần | Có |
| Duỗi tay sau vào tường | `wall-triceps-extension` | Tay | Số lần | Có |
| Cuốn tay trước tự kháng lực | `self-resisted-biceps-curl` | Tay | Số lần | Không |
| Nâng thân nằm sấp nhẹ | `low-superman` | Lưng | Số lần | Không |
| Thiên thần tuyết nằm sấp | `prone-snow-angel` | Lưng | Số lần | Không |
| Chèo tay nằm sấp không tạ | `prone-row` | Lưng | Số lần | Không |
| Trượt gót nằm ngửa | `supine-heel-slide` | Core | Số lần | Không |
| Kéo gối chậm chống tay | `slow-mountain-climber` | Core | Số lần | Không |
| Đá chân sau chống gối | `quadruped-glute-kickback` | Mông | Số lần | Không |
| Gập gối đứng không tạ | `standing-hamstring-curl` | Chân | Số lần | Có |
| Bước ngang chạm chân | `side-step-touch` | Cardio | Thời gian | Không |

## Lựa chọn nội dung

Biến thể tay hẹp trên tường giảm tải bằng cách đứng gần tường; không yêu cầu ép tay thành hình kim cương.
Chống đẩy tường huy động tay sau cùng với ngực, theo [Mayo Clinic](https://www.mayoclinic.org/healthy-lifestyle/pregnancy-week-by-week/in-depth/pregnancy-exercises/art-20546799).
Gập gối đứng dùng nhịp hạ chậm, có điểm tựa nhẹ giữ thăng bằng; lựa chọn này tham khảo [ACE](https://www.acefitness.org/resources/pros/expert-articles/9015/the-hamstrings-blueprint-evidence-based-exercises-for-better-function/?topicScope=workouts).
Các bài nằm sấp dùng biên độ thấp, giữ cổ tự nhiên; hướng dẫn nêu dừng khi đau ở vùng chịu tải.
`contraindications` dùng đúng bảy mã vùng của hệ thống, xét tải lên khớp và tư thế từng bài.
MET là ước lượng cho cường độ nhẹ (2,5–3,5), cần hiệu chỉnh theo dữ liệu thực tế; không phải đo calo cá nhân.

## Cấu hình camera

Dùng nguyên `RepCounter` và `FormChecker`, không thay thuật toán.
Ba cấu hình mới đều nhìn ngang từ điện thoại đặt ngang hông (`table_side`), phiên bản 1:

| Slug | Góc chính | Ngưỡng xuống / lên | Thời gian tối thiểu | Mã lỗi |
|---|---|---|---|---|
| `close-grip-wall-push-up` | shoulder–elbow–wrist | <115° / >150° | 700 ms | `pushup_not_deep_enough`, `body_not_straight` |
| `wall-triceps-extension` | shoulder–elbow–wrist | <115° / >150° | 800 ms | `triceps_not_bent_enough`, `body_not_straight` |
| `standing-hamstring-curl` | hip–knee–ankle | <115° / >155° | 700 ms | `hamstring_not_curled_enough` |

Hai bài tường tập hai tay cùng lúc, chọn bên thấy rõ (`auto`). Gập gối đứng chọn góc nhỏ hơn (`min`) để chân trụ không lấn át chân tập; tập hết một bên rồi quay người đổi chân gần camera.
Các cấu hình yêu cầu độ tin cậy 0,6; giữ nguyên cơ chế xác nhận hai khung và loại chu kỳ quá nhanh.
Mã lỗi độ sâu dùng mốc 100°, mức độ tại 105°/110°; lỗi thân dùng dải 160°–180°.

11 bài mới còn lại chưa hỗ trợ camera: vòng tay và Y–T có nhiều pha, các bài nằm sấp dễ che khớp với góc nhìn ngang hoặc có biên độ nhỏ; các bài phối hợp chi, gót trên sàn và bước ngang cần kiểm tra thêm ngoài một góc khớp.
Synthetic pose kiểm tra chu kỳ đầy đủ, bắt đầu giữa động tác, biên độ thiếu, rung một khung, nhịp quá nhanh, mất độ tin cậy, mã lỗi và chân trụ có độ tin cậy cao hơn.
Các test xác nhận logic với dữ liệu giả lập; trước demo cần thử trên điện thoại thật để kiểm tra góc nhìn, che khuất và ngưỡng. Không cố vượt tầm vận động thoải mái để được camera đếm.

Mẹo đầu bài có đủ 34 slug; 27 cặp lỗi camera, 135 câu. `voice-lines.json` dùng câu chung theo sự kiện nên không cần đổi.
Đồng bộ bản sao cấu hình/tên bài trong màn debug, chỉ sửa trong `camera_counter`.
20 cấu hình gốc được giữ nguyên; seed gốc có vài cờ `false` dù đã có config. `load-seed.js` hiện bật camera cho mọi slug có config, vì vậy sau nạp có 23 bài camera. Trong 14 bài mới chỉ có đúng 3 bài bật camera.

## Kiểm tra và yêu cầu review

Chạy từ gốc repo:

```powershell
python -B docs/content/validate_bodyweight_exercises.py
python -B docs/content/validate_form_cues.py
python -B docs/content/validate_voice_lines.py
```

MongoDB dev, cổng 27018:

```powershell
cd mongo
docker compose up -d
docker compose run --rm mongo-init
```

Nạp thành công 34 bài (23 cấu hình camera), 100 món, 15 huy hiệu. Đọc lại database xác nhận 14 bài mới, đúng 3 cờ camera bật, không trùng slug, dụng cụ chỉ rỗng hoặc thảm.

App:

```powershell
cd app
flutter analyze
flutter test --concurrency=2
```

Kết quả ngày 07/10/2026:

- Ba validator nội dung đều đạt; JSON, slug, vùng chống chỉ định và hợp đồng câu nhắc hợp lệ.
- `flutter test --concurrency=2`: **347 test qua hết**, gồm 16 test mới cho phần mở rộng.
- `flutter analyze`: còn **1 lint có sẵn** `curly_braces_in_flow_control_structures` tại `app/lib/features/workout/presentation/screens/workout_active_screen.dart:97`, đã xác nhận tồn tại trong `HEAD`. Không có lỗi phân tích ở các file thay đổi. File workout nằm ngoài phạm vi được phép sửa; đã xin phép sửa riêng dấu ngoặc và chưa thay đổi khi chưa được duyệt.
- `git diff --check` đạt; 20 bài gốc, cấu hình CV gốc và câu nhắc gốc giữ nguyên.

Claude Code review nội dung, vùng chống chỉ định và ngưỡng camera; chạy backend test rồi nạp Atlas theo quy trình của team. Thay đổi này chưa nạp Atlas.
