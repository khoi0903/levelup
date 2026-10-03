# Prompt cho Codex – Sprint 2

Hai việc chạy song song, mỗi việc một project riêng trong app Codex (Worktree: tắt).

| Việc | Thư mục | Nhánh | Model gợi ý |
|---|---|---|---|
| 1. 100 món Việt + huy hiệu | `D:\levelup-worktrees\codex-foods` | `feat/seed-foods` | mới nhất, Medium |
| 2. Backend `POST /checkins` | `D:\levelup-worktrees\codex-checkins` | `feat/be-checkins` | mới nhất, High |

Việc 2 cần Java 21: trong terminal của Codex chạy `$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"`
trước `.\mvnw.cmd test`.

---

## Việc 1 · 100 món Việt và bộ huy hiệu

```
Bạn đang ở nhánh feat/seed-foods, không chuyển nhánh. Đọc AGENTS.md trước.
Chỉ được tạo 2 file: mongo/seed/foods.json và mongo/seed/achievements.json.

A. mongo/seed/foods.json – mảng JSON đúng 100 món ăn và đồ uống phổ biến ở Việt Nam.
Đọc validator collection "foods" trong mongo/init.js để biết tên trường. Mỗi phần tử:
  nameVi ("Cơm tấm sườn bì chả"), searchName (chữ thường, bỏ dấu: "com tam suon bi cha"),
  aliases (tên gọi khác, không dấu), category (com | bun_pho_mi | banh_mi | xoi | an_vat |
  mon_canh | do_uong | trang_mieng | trai_cay | mon_chay), servingDesc ("1 đĩa", "1 tô", "1 ly 500ml"),
  servingGrams, kcal, proteinG, carbsG, fatG (số, cho 1 khẩu phần), source: "curated",
  verified: false, sourceNote (ghi nguồn tham khảo hoặc "ước tính").
Phân bổ: ~25 món cơm và món mặn, ~20 bún/phở/miến/mì, ~10 bánh mì và xôi, ~15 ăn vặt và bánh,
~15 đồ uống (trà sữa trân châu, cà phê sữa đá, nước mía, sinh tố...), ~15 trái cây và tráng miệng.
Kiểm tra: kcal xấp xỉ protein*4 + carbs*4 + fat*9 (lệch tối đa 15%); searchName không trùng.
Viết script kiểm tra nhỏ để tự kiểm, không commit script.

B. mongo/seed/achievements.json – 15 huy hiệu, đọc validator collection "achievements".
Mỗi phần tử: code (snake_case, ví dụ sessions_10), nameVi, descriptionVi (1 câu, giọng động viên),
category (sessions | streak | strength | body | buddy | nutrition | comeback), threshold (số hoặc null).
Gồm: buổi đầu tiên, 10/25/50 buổi; streak 2/4/8 tuần; kỷ lục đầu tiên; giảm 1 cm vòng eo;
ghép buddy đầu tiên; 4 tuần liền cùng buddy đạt mục tiêu; ghi bữa ăn 7 ngày liên tiếp;
quay lại sau 7 ngày nghỉ (comeback); dùng thẻ đóng băng lần đầu; check-in 7 ngày liền.

Commit: "seed: 100 món Việt và 15 huy hiệu".
```

> Số liệu dinh dưỡng do AI ước tính, để `verified: false`. Trước khi demo nên đối chiếu ít nhất
> 30 món hay dùng nhất với một bảng thành phần dinh dưỡng đáng tin cậy.

---

## Việc 2 · Backend `POST /checkins` (check-in sáng, flow F2)

```
Bạn đang ở nhánh feat/be-checkins, không chuyển nhánh. Đọc AGENTS.md trước, đặc biệt mục
"Quy tắc nghiệp vụ không được làm sai". Đọc code backend hiện có để làm theo cùng kiểu:
OnboardingService (MongoTemplate + @Transactional), PlansController, CurrentUserService,
LocalDates, ApiErrors, PlanView. Đọc validator "daily_stats" và "training_plans" trong mongo/init.js.

Chỉ được sửa trong:
  backend/src/main/java/vn/levelup/checkins/   (tạo mới)
  backend/src/test/java/vn/levelup/checkins/   (tạo mới)
  backend/src/main/java/vn/levelup/plans/TrainingPlan.java  (chỉ thêm trường adjustedReason vào Session)
  backend/src/main/java/vn/levelup/plans/PlanView.java      (chỉ thêm adjustedReason vào SessionView)
Không sửa file nào khác.

Yêu cầu POST /checkins:
- Body: { "energy": "tired" | "normal" | "energized", "sleep": "lt6" | "h6_7" | "h7_8" | "gt8" (không bắt buộc) }
  Validate bằng annotation như OnboardingRequest. Người dùng phải đã onboarding (currentUser.require()).
- localDate = LocalDates.today(user.timezone(), clock). Mỗi người chỉ check-in 1 lần mỗi ngày:
  nếu daily_stats của ngày đó đã có checkin → 409 với code "ALREADY_CHECKED_IN".
- Trong một transaction:
  1. upsert daily_stats { userId, localDate } với $set checkin: { energy, sleep, at }
  2. tìm buổi tập hôm nay: trong training_plans status "active" của user, session có
     scheduledDate == localDate và status "planned"
  3. nếu có buổi hôm nay, điều chỉnh theo bảng sau (logic để trong một class thuần
     CheckinAdjuster để unit test):
       - energy "tired" HOẶC sleep "lt6": variant "light", mỗi bài giảm targetSets 1 (tối thiểu 1),
         adjustedReason "checkin_tired"
       - energy "energized" và sleep khác "lt6": variant "advanced", giữ nguyên số hiệp,
         adjustedReason "checkin_energized"
       - còn lại: không đổi
     Cập nhật đúng session đó bằng positional update (sessions.$), không ghi đè cả plan.
- Response: { localDate, energy, sleep, adjusted (true/false), session (SessionView có nameVi, hoặc null
  nếu hôm nay không có buổi) }.

Test:
- Unit test CheckinAdjuster cho cả 3 trường hợp và trường hợp targetSets = 1 không giảm xuống 0.
- Không cần test tích hợp với MongoDB.
Chạy .\mvnw.cmd test trong backend/, tất cả test phải đạt. Commit nhỏ theo bước.
Báo cáo: các file đã đổi, kết quả test.
```
