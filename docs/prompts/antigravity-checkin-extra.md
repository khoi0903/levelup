# Prompt cho Antigravity – Check-in cho buổi tập thêm, tab Tập, tự chọn đủ bài

Feedback người dùng (2026-10-09):
1. Check-in chỉ chỉnh buổi trong lịch của hôm nay; lịch giờ chỉ để nhắc nên ngày không có lịch check-in gần như vô
   tác dụng → check-in phải chỉnh cả **buổi tập thêm**.
2. Tab **Tập** khi tuần này không còn buổi nào mở (đã tập/đã bỏ hết) vẫn rơi về buổi đầu tuần (có khi 0 bài)
   → "Buổi này chưa có bài tập". Nên mở thẳng màn Tập thêm.
3. Tab "Tự chọn bài" ở màn Tập thêm chỉ hiện bài lọc theo dụng cụ → nên **liệt kê đủ bài**.

Backend (Claude Code, PR feat/be-checkin-context): `GET /me` thêm
`"todayCheckin": {"energy": "tired|normal|energized", "sleep": "lt6|h6_7|h7_8|gt8" | null}` (null nếu chưa check-in).
"Thấp" = energy tired hoặc sleep lt6 (cùng điều kiện backend dùng để giảm buổi trong lịch).

```
Bạn đang ở nhánh feat/app-checkin-extra (worktree D:\levelup-worktrees\app-checkin-extra), không chuyển nhánh,
không merge vào main. Đọc AGENTS.md và docs/prompts/antigravity-checkin-extra.md.
Chỉ sửa app/lib, app/test. Không dart format cả thư mục. Màu theo app_colors.dart.

1. MeResponse đọc todayCheckin (model TodayCheckin {energy, sleep}, getter isLow).
2. Màn Tập thêm (workout_extra_screen + extra_workout_builder):
   - Check-in thấp: buổi gợi ý nhẹ hơn (bớt 1 hiệp mỗi bài, tối thiểu 1; ưu tiên bài difficulty thấp; mặc định
     chọn sẵn mức thời lượng ngắn nhất), dòng gợi ý trên đầu: "Sáng nay bạn thấy mệt nên buổi gợi ý nhẹ hơn".
   - Sung sức: giữ đủ hiệp, cho phép mức dài nhất; dòng "Bạn đang sung sức, thử buổi đầy đủ nhé".
   - Chưa check-in: như hiện tại, kèm nút nhỏ "Check-in" mở /checkin.
   - GIỮ cách tải dữ liệu một lần trong initState (đừng tạo Future trong build: từng gây nháy trắng, xem PR #38).
3. Tab Tập (route /workout không có sessionId): nếu kế hoạch tuần này không còn buổi mở có lịch hôm nay
   (isSessionOpen && scheduledDate == /me.localDate && có bài) thì mở thẳng /workout/extra
   (pushReplacement/redirect), không hiện buổi đã bỏ hoặc 0 bài. Có buổi hôm nay thì như cũ.
4. Tab "Tự chọn bài": liệt kê ĐỦ bài isActive.
   - Bài cần dụng cụ người dùng chưa khai: vẫn chọn được, nhãn nhỏ "Cần tạ đơn" / "Cần dây kháng lực" / "Cần xà đơn"
     (thảm không tính).
   - Bài chống chỉ định với vùng đang đau (contraindications ∩ chấn thương đang active): hiện mờ, không chọn được,
     nhãn "Không hợp với chấn thương <vùng>" (an toàn là quy tắc cứng).
   - Giữ tìm kiếm không dấu và lọc nhóm cơ như hiện có; sắp xếp: bài phù hợp trước, bài cần dụng cụ sau, bài
     chống chỉ định cuối.
   - Tab "Gợi ý" (buổi tự ghép) vẫn chỉ dùng bài phù hợp như cũ.
5. Test (repository giả): todayCheckin thấp → buổi gợi ý ít hiệp hơn + dòng gợi ý; tab Tập không có buổi hôm nay →
   vào màn Tập thêm; Tự chọn bài hiện bài cần tạ với nhãn và chọn được, bài chống chỉ định mờ và không chọn được.
   flutter analyze sạch, flutter test --concurrency=2 qua hết.
6. Commit "app: check-in cho buổi tập thêm, tab Tập mở Tập thêm khi hết buổi, tự chọn đủ bài". Báo Claude Code review.
```
