# Prompt cho Codex – nội dung coach, kịch bản demo, rà số liệu món ăn

Thư mục: `D:\levelup-worktrees\codex-content`, nhánh `feat/content-demo`.

```
Bạn đang ở nhánh feat/content-demo, không chuyển nhánh. Đọc AGENTS.md trước.
Chỉ sửa: docs/content/coach-messages.json, docs/demo/** (tạo mới), mongo/seed/foods.json.
Không sửa code app/ hay backend/.

A. Mẫu tin nhắn coach (docs/content/coach-messages.json, backend đọc file này qua classpath content/):
   Thêm các khóa skip_busy, skip_tired, skip_pain, skip_bored, skip_forgot, skip_other — mỗi khóa có
   3 phong cách strict / supportive / funny, mỗi phong cách 3 câu, giữ đúng định dạng các khóa đã có.
   Biến duy nhất được dùng: {ten}. Nội dung là câu coach trả lời NGAY SAU khi người dùng báo lý do bỏ buổi
   và kế hoạch đã được đổi (bận: buổi tối nay rút còn 10 phút, buổi sau dời sang ngày trống; mệt: các buổi
   còn lại nhẹ hơn; đau: đã thay bài an toàn, nhắc đi khám nếu đau kéo dài, không chẩn đoán; chán: đã đổi bài
   cùng nhóm cơ; quên: gợi ý đặt nhắc trước giờ tập 60 phút). Giọng như các khóa có sẵn, không phán xét,
   tiếng Việt tự nhiên, emoji tối đa 1 câu/1 cái. Thêm checkin_energized nếu chưa có (giọng hào hứng vừa phải).
   Viết script kiểm tra nhỏ (không commit): JSON hợp lệ, mọi khóa đủ 3 phong cách × 3 câu, chỉ có biến {ten},
   không câu nào trùng nhau.

B. Kịch bản demo (docs/demo/kich-ban-demo.md): đọc docs/02-ke-hoach-10-tuan.html (mục Kịch bản demo,
   Công cụ demo) và docs/01-user-flows.html. Viết kịch bản 10–12 phút đi qua đủ F1–F8 trên 2 điện thoại
   (người dùng chính + buddy), từng bước: bấm gì, nói gì, màn hình mong đợi. Dùng công cụ demo backend có sẵn:
   POST /demo/{action} với action = seed (tạo 4 tuần lịch sử), skip-two (giả lập bỏ 2 buổi), close-week (chốt
   tuần ngay), review (tổng kết tuần) — chỉ chạy với uid bắt đầu bằng "demo" ở profile dev (xem
   backend/src/main/java/vn/levelup/demo/). Có mục "Chuẩn bị trước 30 phút", "Nếu mạng/AI lỗi thì làm gì"
   (AI lỗi → app vẫn chạy bằng luật dự phòng), và danh sách kiểm tra trước giờ demo.

C. Rà số liệu 30 món phổ biến nhất trong mongo/seed/foods.json (phở bò, cơm tấm, bánh mì thịt, bún bò,
   bún chả, cơm gà, xôi, trà sữa, cà phê sữa đá...). Đối chiếu với nguồn đáng tin (Bảng thành phần thực
   phẩm Việt Nam – Viện Dinh dưỡng, USDA FoodData Central cho nguyên liệu). Sửa kcal/macro/servingGrams nếu
   lệch > 15%, ghi sourceNote cụ thể (tên nguồn + cách tính). CHỈ đặt verified: true khi đã đối chiếu thật
   được với nguồn ghi trong sourceNote; không chắc thì để false. Giữ kcal ≈ protein*4 + carbs*4 + fat*9 (lệch ≤ 15%).
   Báo cáo bảng: món, cũ → mới, nguồn.

Commit nhỏ theo từng phần (A, B, C), không merge vào main. Báo cáo: các khóa đã thêm, đường dẫn kịch bản,
bảng món đã sửa.
```
