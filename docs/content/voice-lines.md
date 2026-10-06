# Câu đọc giọng nói khi tập

Nguồn nội dung: `app/assets/content/voice-lines.json`, phiên bản `1`. Bộ câu dựa trên tinh thần coach trong `docs/content/coach-messages.json`, rút ngắn cho giọng đọc khi tập. Các ID bên dưới là hợp đồng nội dung với app.

| ID | Tên | Tinh thần | rate / pitch | 3 câu ví dụ |
|---|---|---|---|---|
| `supportive` | Động viên | Ấm áp, ghi nhận từng tiến bộ nhỏ | 0.48 / 1.0 | “{n}, tốt lắm”; “Còn {left} lần nhé”; “Một mốc mới của riêng bạn!” |
| `strict` | Nghiêm khắc | Ngắn, dứt khoát, giúp tập trung | 0.56 / 0.95 | “Bắt đầu!”; “Còn {left} lần, tập trung”; “Kỷ lục cá nhân mới.” |
| `funny` | Hài hước | Đùa nhẹ bằng hình ảnh lên sóng, sân khấu | 0.5 / 1.05 | “Lên sóng nào!”; “Còn {left} lần là hạ màn”; “Bảng kỷ lục có khách mới!” |
| `calm` | Bình tĩnh | Chậm, nhẹ nhàng, nhắc thở đều | 0.4 / 0.95 | “Bắt đầu nhẹ nhàng nhé.”; “Còn {left} lần, nhẹ nhàng nhé”; “Còn {sec} giây, thở đều nhé.” |
| `hype` | Bùng nổ | Cổ vũ giàu năng lượng như bình luận thể thao | 0.6 / 1.1 | “Vào sân thôi!”; “Còn {left} lần, về đích thôi”; “Kỷ lục mới, tuyệt vời!” |
| `genz` | Bạn thân Gen Z | Thân mật, vui, mọi lứa tuổi đều hiểu | 0.52 / 1.05 | “Tập thôi bạn ơi!”; “Còn {left} lần thôi bạn ơi”; “Bạn vừa có mốc mới nè!” |
| `minimal` | Tối giản | Đủ từng số, chỉ lệnh cần thiết | 0.5 / 1.0 | “{n}”; “Lần cuối.”; “Nghỉ {sec} giây.” |

`rate` nằm trong 0.0–1.0, với 0.5 là mốc bình thường của yêu cầu nội dung; `pitch` nằm trong 0.5–2.0. Cả 7 phong cách dùng `countEvery: 1` để người đặt điện thoại xa vẫn nghe đủ số lần. Calm đọc chậm hơn, strict và hype đọc nhanh hơn mốc bình thường. Đây là giá trị khởi đầu; cần nghe thử trên thiết bị với giọng tiếng Việt trước khi điều chỉnh.

## Sự kiện và placeholder

| Khóa trong `lines` | Placeholder | Khi đọc |
|---|---|---|
| `start_countdown` | `{n}` | Số giây đếm trước hiệp |
| `go` | Không | Bắt đầu hiệp |
| `rep` | `{n}` | Số lần đã thực hiện |
| `almost_done` | `{left}` | Còn 3 lần |
| `last_rep` | Không | Lần cuối |
| `set_done` | `{set}`, `{sets}` | Hoàn tất hiệp hiện tại trên tổng số hiệp |
| `rest_start` | `{sec}` | Thời lượng nghỉ |
| `rest_ending` | `{sec}` | Còn 10 giây nghỉ |
| `hold_remaining` | `{sec}` | Bài giữ còn 30, 20, 10 giây |
| `hold_last` | `{sec}` | Đếm từng giây trong 5 giây cuối |
| `form_generic` | Không | Camera báo tư thế cần kiểm tra |
| `lost_person` | Không | Camera không thấy đủ người |
| `exercise_next` | `{exercise}` | Tên bài tiếp theo |
| `workout_done` | `{minutes}`, tùy chọn `{kcal}` | Tổng kết buổi tập |
| `personal_record` | Không | App xác nhận kỷ lục cá nhân mới |

## Quy tắc viết và chọn câu

- Viết tiếng Việt có dấu, UTF-8 không BOM. Không emoji, viết tắt khó đọc, từ tục, chế giễu cơ thể hoặc hứa hẹn y khoa. Strict nhắc rõ nhưng không ép tập vượt sức; hype tăng năng lượng bằng lời cổ vũ. Gen Z dùng “bạn”, “nha”, “nè”, tránh tiếng lóng khó hiểu.
- Mỗi sự kiện có 3–6 câu khác nhau; minimal có 1–2 câu. Riêng `hold_last` chỉ có một mẫu `"{sec}"` ở mọi phong cách để tuân thủ yêu cầu chỉ đọc số, tránh tạo biến thể giả bằng dấu câu. `minimal.rep` cũng chỉ có `"{n}"`.
- `rep` tối đa 4 từ, `almost_done` tối đa 8 từ. Trình kiểm tra đếm theo khoảng trắng, coi mỗi placeholder là một từ; số sau khi giọng máy đọc ra có thể dài hơn. Các câu khác cũng ưu tiên ngắn. Khi nghe thử, kiểm tra số nhiều chữ và tên bài dài để tránh giọng đọc chồng lên động tác tiếp theo.
- Dùng nguyên tên placeholder trong bảng, không tự viết số đếm bằng chữ, không dùng cú pháp định dạng hoặc placeholder từ bộ coach cũ. App thay bằng chữ số; giọng máy tự đọc số. Tên bài thay vào `{exercise}` là tên hiển thị tiếng Việt.
- Viết “hiệp {set} trên {sets}” để đọc rõ, tránh dấu `/`. Viết “ki lô calo” trong câu đọc thay cho ký hiệu `kcal`; tên placeholder vẫn là `{kcal}`. Calo được mô tả là ước tính.
- `form_generic` chỉ yêu cầu chậm lại, kiểm tra hướng dẫn hoặc tạm dừng chỉnh tư thế; không đoán bộ phận sai khi sự kiện chưa cung cấp chi tiết. `lost_person` hướng dẫn đưa cả người vào khung hình.
- Khi chọn câu, lọc trước các mẫu có đủ dữ liệu placeholder, rồi chọn ngẫu nhiên. Nếu thiếu `kcal`, loại mọi mẫu chứa `{kcal}`; mỗi phong cách có ít nhất một mẫu tổng kết chỉ dùng `{minutes}`. Không đọc placeholder chưa thay, `null` hoặc giá trị calo tự suy đoán.
- Với danh sách có nhiều mẫu đủ dữ liệu, bỏ mẫu vừa đọc cho cùng phong cách và sự kiện trước khi chọn. Với mẫu số duy nhất, số thay vào thay đổi theo lần/giây; không phát lại cùng sự kiện có cùng giá trị. Những lệnh chỉ có một mẫu ở minimal được đọc một lần cho mỗi lần sự kiện xảy ra, không thể đổi câu chữ để tránh lặp.
- `countEvery` áp dụng cho số lần; các mốc báo sắp xong, nghỉ và bài giữ theo bảng. Tránh phát hai câu đồng thời khi mốc đếm trùng sự kiện nhắc khác. Nội dung và kiểm tra trong thay đổi này; khai báo asset và cơ chế phát giọng do phần app tích hợp riêng.

## Kiểm tra

Từ thư mục gốc repo, chạy Python 3 (chỉ thư viện chuẩn):

```powershell
python docs/content/validate_voice_lines.py
```

Có thể kiểm tra một bản nội dung khác:

```powershell
python docs/content/validate_voice_lines.py --json path/to/voice-lines.json
```

Script trả mã 0 khi hợp lệ, mã 1 khi có lỗi. Nó kiểm tra UTF-8, JSON và khóa trùng, phiên bản, đúng 7 ID và 15 sự kiện, metadata, miền rate/pitch/countEvery, số mẫu và câu trùng, placeholder theo từng sự kiện, giới hạn từ, mẫu chỉ số và tổng kết dự phòng khi thiếu calo. Một mẫu `hold_last` là ngoại lệ được kiểm tra tường minh ở trên. Văn phong và chất lượng giọng đọc cần review nội dung và nghe thử thực tế.

## Thêm phong cách mới

1. Thống nhất ID mới với bên app trước khi đổi hợp đồng hiện tại gồm đúng 7 ID; không đổi ID đang dùng. Sao chép đầy đủ 15 khóa từ một phong cách phù hợp.
2. Viết `nameVi`, `descriptionVi` một câu cho màn chọn, chọn rate/pitch trong miền hợp lệ và số nguyên dương `countEvery`. Ưu tiên đếm mỗi lần để giữ khả năng theo dõi bằng âm thanh.
3. Viết 3–6 mẫu mỗi sự kiện, giữ `hold_last: ["{sec}"]`, có tổng kết không dùng `{kcal}`. Nếu thêm một chế độ tối giản mới, thống nhất và cập nhật quy tắc kiểm tra số mẫu/chỉ số cho ID đó.
4. Cập nhật `STYLE_IDS` cùng quy tắc có liên quan trong script, bảng phong cách và phiên bản JSON theo thỏa thuận tích hợp. Chạy lại trình kiểm tra, nghe thử các mốc đếm/nghỉ/giữ và trường hợp thiếu calo trên thiết bị.
5. Gửi Claude Code review nội dung; bên app thực hiện thay đổi tích hợp trong PR của mình.
