# Prompt cho ChatGPT Plus – Sprint 1 (nội dung và hình ảnh)

Mỗi prompt dán vào **một cuộc chat riêng**. Kết quả lưu vào đúng file ghi ở cuối mỗi prompt,
rồi báo Claude Code để kiểm tra và nạp vào database.

---

## Prompt 1 · 20 bài tập cho thư viện

Lưu kết quả vào: `mongo/seed/exercises.json`

```
Bạn là huấn luyện viên thể hình có chứng chỉ, viết nội dung cho một app tập luyện tiếng Việt
dành cho người mới bắt đầu, tập ở nhà hoặc ở phòng gym.

Hãy tạo đúng 20 bài tập. Bắt buộc có các bài sau (vì đã có trong thiết kế app):
Bật nhảy tại chỗ (jumping jack), Squat không tạ, Squat ôm tạ (goblet squat), Plank,
Glute bridge, Dead bug, Hít đất, Lunge, Đẩy vai tạ đơn.
11 bài còn lại bạn tự chọn để đủ các nhóm cơ: chân, mông, ngực, lưng, vai, tay, core, cardio.
Ít nhất 10 bài không cần dụng cụ.

Trả về DUY NHẤT một mảng JSON hợp lệ, không giải thích thêm. Mỗi phần tử đúng các trường sau:
{
  "slug": "goblet-squat",                 // chữ thường, gạch nối, không dấu, duy nhất
  "nameVi": "Squat ôm tạ",
  "nameEn": "Goblet squat",
  "instructions": "3-5 câu hướng dẫn từng bước, tiếng Việt, câu ngắn",
  "cues": ["Giữ lưng thẳng", "..."],      // 2-4 lời nhắc ngắn khi đang tập
  "primaryMuscle": "legs",                // một trong: legs, glutes, chest, back, shoulders, arms, core, full_body, cardio
  "difficulty": 2,                        // số nguyên 1-5
  "tracking": "reps_weight",              // một trong: reps, reps_weight, duration
  "met": 5.0,                             // chỉ số MET tham khảo để ước tính kcal
  "equipment": ["dumbbell"],              // [] nếu không cần dụng cụ; chỉ dùng: dumbbell, mat, resistance_band, pullup_bar
  "contraindications": ["knee"],          // vùng cơ thể nên tránh bài này khi đang đau; chỉ dùng: lower_back, knee, shoulder, neck, wrist, ankle, hip
  "isActive": true
}

Yêu cầu:
- Tiếng Việt tự nhiên, dễ hiểu, không dịch máy móc.
- Chống chỉ định phải thận trọng: bài nào gây áp lực lên khớp nào thì ghi khớp đó.
- Không đưa lời khuyên y tế.
```

> Nhớ nhờ một huấn luyện viên thật đọc lại phần hướng dẫn và chống chỉ định trước khi dùng.

---

## Prompt 2 · Mẫu tin nhắn AI coach theo 3 phong cách

Lưu kết quả vào: `docs/content/coach-messages.json`

```
Bạn viết nội dung cho "AI coach" trong một app tập luyện tiếng Việt. Vấn đề của sản phẩm:
60% người dùng bỏ app vì mất động lực, nên giọng coach phải giữ chân người dùng, không làm họ thấy tội lỗi.

Coach có 3 phong cách:
- strict (nghiêm khắc): ngắn, thẳng, thúc đẩy, nhưng không chê bai
- supportive (động viên): ấm áp, thấu hiểu
- funny (hài hước): dí dỏm, nhẹ nhàng, không châm chọc người dùng

Viết mẫu tin cho các tình huống sau, mỗi tình huống × mỗi phong cách 3 biến thể:
1. checkin_morning: hỏi hôm nay người dùng thấy thế nào
2. pre_workout: nhắc 30 phút trước giờ tập
3. missed_1: tối nay chưa tập, gợi ý bản 5 phút
4. missed_2: đã bỏ 2 buổi, hỏi điều gì đang cản trở (người dùng sẽ chọn: Bận, Mệt, Đau, Chán, Quên)
5. lapsed_7: 7 ngày không tập, mời quay lại với tuần khởi động nhẹ, nhắc lại lý do của họ
6. workout_done: vừa tập xong, khen cụ thể bằng số liệu
7. new_pr: vừa đạt kỷ lục mới
8. weekly_win: mở đầu bản tổng kết tuần
9. checkin_tired: người dùng chọn "Mệt", coach đã giảm nhẹ buổi tập

Dùng biến trong ngoặc nhọn để app thay vào: {ten}, {ly_do}, {so_buoi}, {bai_tap}, {so_lieu}, {thoi_luong}.

Quy tắc bắt buộc:
- Tối đa 2 câu, dưới 160 ký tự.
- Mỗi tin chỉ kêu gọi MỘT hành động.
- Không trách móc, không so sánh với người khác, không nói về cân nặng hay ngoại hình theo kiểu tiêu cực.
- Không đưa lời khuyên y tế. Tình huống đau thì khuyên nghỉ hoặc đi khám.
- Không dùng emoji trong phong cách strict. Hai phong cách còn lại tối đa 1 emoji.

Trả về DUY NHẤT JSON hợp lệ dạng:
{ "checkin_morning": { "strict": ["...","...","..."], "supportive": [...], "funny": [...] }, ... }
```

---

## Prompt 3 · Tên app và icon

Kết quả: chọn tên, lưu icon PNG 1024×1024 vào `docs/brand/`

```
Tôi đang làm một app tập luyện cho người Việt 20-35 tuổi, có AI coach giúp giữ động lực,
tập ngắn 10-15 phút, chụp món ăn Việt để tính calo. Tinh thần: thân thiện, kiên trì, không áp lực.

Bước 1: Đề xuất 10 tên app. Tiêu chí: ngắn (1-2 từ), dễ đọc với cả người Việt và người nước ngoài,
không trùng tên app fitness nổi tiếng. Mỗi tên kèm một câu giải thích.

Bước 2: Sau khi tôi chọn tên, vẽ icon app 1024×1024:
- Hình đơn giản, nhận ra được khi thu nhỏ 48px
- Màu chính cam đất #C4461F, màu phụ xanh rêu #1E7465, nền sáng
- Không chữ, không ảnh người thật, không gradient cầu vồng
- Vẽ 3 phương án khác nhau
```

> Trước khi chốt tên, tự kiểm tra trên Google Play và App Store xem đã có app trùng tên chưa.
