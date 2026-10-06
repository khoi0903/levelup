# Câu nhắc tư thế theo từng bài

Nguồn phát giọng: `app/assets/content/form-cues.json`, phiên bản `1`. Bộ nội dung hiện có 20 bài, 22 cặp `(slug, code)` và 106 câu. Nội dung dựa trên `instructions`, `cues` trong `mongo/seed/exercises.json` và `formRules` thuộc `activeVersion` trong `mongo/cv-configs.json`, đối chiếu bảng trong `docs/prompts/codex-form-cues.md`.

## Hợp đồng với app

- `exercises[slug].startTip`: 1–2 mẫu mẹo đầu bài, mỗi mẫu tối đa 12 từ. Chọn một mẫu đọc sau `exercise_next`; người dùng có thể tắt mẹo đầu bài.
- `exercises[slug].issues[code].cue`: 2–3 mẫu nhắc sửa cụ thể, mỗi mẫu tối đa 8 từ. Chọn một mẫu cho mỗi lần nhắc.
- `minimal`: đúng một mẫu, tối đa 4 từ, dùng cho phong cách Tối giản. Những phong cách khác dùng `cue` và có thể thêm lời trước/sau theo phong cách.
- Tra bằng cả `slug` và `FormIssue.code`; cùng một mã có thể cần câu khác ở bài khác. Thiếu bài hoặc mã thì dùng `form_generic` trong `voice-lines.json`. Giữ giới hạn nhắc tư thế một lần mỗi 8 giây theo prompt tích hợp.
- Mỗi bài trong seed đều có `startTip` và `issues`, kể cả khi `cv.supported` đang là `false`. Bài chưa có lỗi trong cấu hình dùng `issues: {}`. Hiện cả 20 bài đều có lỗi ở cấu hình đang hoạt động.

Khai báo asset, chọn câu, cài đặt và phát giọng do phần app tích hợp riêng. Không đọc toàn bộ mảng liên tiếp. Khi có nhiều mẫu, ưu tiên tránh mẫu vừa đọc; mẫu tối giản duy nhất vẫn tuân thủ khoảng cách giữa các lần nhắc.

## Bảng nội dung

Các mẫu trong cùng ô cách nhau bằng xuống dòng; mỗi dòng là một mẫu độc lập. Tên hiển thị lấy nguyên từ seed; tiếng Anh trong tên bài hoặc mã dưới đây không nằm trong câu phát giọng.

| Bài và slug | Mẹo đầu bài (`startTip`) | Mã lỗi | Câu sửa (`cue`) | Tối giản (`minimal`) |
|---|---|---|---|---|
| Bật nhảy tại chỗ<br>`jumping-jack` | Tiếp đất nhẹ với gối hơi chùng<br>Đưa tay lên trong tầm thoải mái | `arms_not_overhead` | Đưa hai tay lên trên đầu<br>Nâng tay cao trong tầm thoải mái | Tay lên cao |
| Squat không tạ<br>`bodyweight-squat` | Giữ gót bám sàn, gối theo hướng mũi chân<br>Hạ người chậm trong tầm thoải mái | `shallow_depth` | Hạ hông trong tầm thoải mái<br>Gập gối thêm, giữ gót bám sàn | Hạ hông chậm |
| Squat ôm tạ<br>`goblet-squat` | Giữ tạ sát ngực, gối theo hướng mũi chân<br>Hạ chậm, giữ lưng tự nhiên | `shallow_depth` | Hạ hông chậm, giữ tạ sát ngực<br>Hạ người thêm trong tầm thoải mái | Hạ hông chậm |
| Plank<br>`plank` | Đặt khuỷu tay dưới vai, giữ hông ngang thân<br>Siết bụng nhẹ, giữ lưng ổn định và thở đều | `body_not_straight` | Chỉnh vai, hông, cổ chân thẳng hàng<br>Siết bụng nhẹ, đưa hông ngang thân | Hông ngang thân |
| Nâng hông<br>`glute-bridge` | Nâng hông bằng cơ mông, giữ lưng ổn định<br>Giữ hai bàn chân bám sàn | `bridge_hips_not_high_enough` | Nâng hông để vai, hông, gối thẳng hàng<br>Siết mông, nâng hông có kiểm soát | Nâng hông chậm |
| Duỗi tay chân đối bên<br>`dead-bug` | Duỗi tay chân đối bên chậm, giữ lưng dưới ổn định<br>Giữ bụng siết nhẹ và thở ra khi duỗi | `leg_not_extended` | Duỗi chân chậm, giữ lưng dưới ổn định<br>Đưa gót ra xa trong tầm kiểm soát | Duỗi chân chậm |
| Hít đất<br>`push-up` | Siết bụng nhẹ, giữ vai, hông, cổ chân thẳng hàng<br>Hạ ngực chậm, khuỷu tay chếch về sau | `body_not_straight` | Chỉnh vai, hông, cổ chân thẳng hàng<br>Siết bụng nhẹ, giữ hông ngang thân | Giữ thân thẳng |
| Hít đất<br>`push-up` | Siết bụng nhẹ, giữ vai, hông, cổ chân thẳng hàng<br>Hạ ngực chậm, khuỷu tay chếch về sau | `pushup_not_deep_enough` | Hạ ngực chậm trong tầm thoải mái<br>Gập khuỷu tay thêm có kiểm soát | Hạ ngực chậm |
| Lunge bước lùi<br>`reverse-lunge` | Bước lùi chậm, giữ gối trước theo hướng mũi chân<br>Hạ người trong tầm thoải mái, giữ chân trước bám sàn | `lunge_not_deep_enough` | Gập hai gối trong tầm thoải mái<br>Hạ gối sau chậm về phía sàn | Hạ người chậm |
| Đẩy vai tạ đơn<br>`dumbbell-shoulder-press` | Siết bụng nhẹ, giữ lưng ổn định khi đẩy tạ<br>Giữ cổ tay thẳng, hạ tạ chậm | `press_not_locked_out` | Duỗi tay lên trong tầm thoải mái<br>Đẩy tạ cao có kiểm soát | Duỗi tay lên |
| Nhón gót đứng<br>`standing-calf-raise` | Nhón gót chậm, chạm tay vào tường để giữ thăng bằng<br>Giữ cổ chân ổn định khi hạ gót | `heels_not_high_enough` | Nhón gót cao trong tầm thoải mái<br>Nâng gót chậm, giữ cổ chân ổn định | Nhón gót chậm |
| Ngồi tựa tường<br>`wall-sit` | Tựa lưng vào tường, giữ gối theo hướng mũi chân<br>Chỉnh độ gập gối chậm trong tầm thoải mái | `knee_not_at_90` | Chỉnh gối gần vuông góc, thật chậm<br>Chỉnh độ gập gối trong tầm thoải mái | Gối gần vuông góc |
| Vươn tay chân đối bên<br>`bird-dog` | Vươn tay chân đối bên chậm, giữ lưng ổn định<br>Giữ hông hướng xuống sàn, chân ngang thân | `leg_not_extended` | Vươn chân ra sau ngang thân<br>Duỗi chân chậm, giữ hông hướng xuống sàn | Vươn chân ra sau |
| Nằm nghiêng nâng chân<br>`side-lying-leg-raise` | Giữ hông và vai xếp chồng, mũi chân hướng trước<br>Nâng chân chậm trong tầm kiểm soát | `leg_not_high_enough` | Nâng chân trên trong tầm thoải mái<br>Nâng chân cao hơn, giữ hông ổn định | Nâng chân chậm |
| Hít đất vào tường<br>`wall-push-up` | Đặt tay ngang ngực, giữ thân thẳng khi nghiêng vào tường<br>Đưa ngực gần tường chậm, khuỷu tay chếch xuống | `body_not_straight` | Chỉnh vai, hông, cổ chân thẳng hàng<br>Giữ bụng chắc, đưa hông thẳng theo thân | Giữ thân thẳng |
| Hít đất vào tường<br>`wall-push-up` | Đặt tay ngang ngực, giữ thân thẳng khi nghiêng vào tường<br>Đưa ngực gần tường chậm, khuỷu tay chếch xuống | `pushup_not_deep_enough` | Đưa ngực gần tường trong tầm thoải mái<br>Gập khuỷu tay chậm, đưa ngực gần tường | Ngực gần tường |
| Đi bộ tại chỗ<br>`march-in-place` | Nâng gối vừa tầm, giữ thân thẳng và ổn định<br>Đặt chân xuống nhẹ, giữ nhịp đều | `torso_leaning` | Đưa vai về trên hông<br>Giữ thân thẳng khi nâng gối | Giữ thân thẳng |
| Bước ngang kết hợp đưa tay<br>`step-jack` | Bước ngang vừa tầm, luôn giữ một chân trên sàn<br>Đưa tay lên chậm trong tầm thoải mái | `arms_not_straight` | Duỗi tay nhẹ khi đưa lên<br>Mở khuỷu tay trong tầm thoải mái | Duỗi tay nhẹ |
| Kéo tạ đơn gập người<br>`dumbbell-bent-over-row` | Gập từ hông, giữ lưng tự nhiên và thân ổn định<br>Kéo tạ chậm về eo, khuỷu tay sát thân | `row_not_high_enough` | Kéo tạ về eo có kiểm soát<br>Đưa khuỷu tay ra sau sát thân | Kéo tạ về eo |
| Ngồi kéo dây kháng lực<br>`seated-resistance-band-row` | Giữ dây chắc quanh bàn chân, lưng thẳng tự nhiên<br>Kéo dây chậm về eo, giữ thân ổn định | `row_not_high_enough` | Kéo hai đầu dây về eo<br>Đưa khuỷu tay ra sau có kiểm soát | Kéo dây về eo |
| Cuốn tay trước với tạ đơn<br>`dumbbell-biceps-curl` | Giữ khuỷu tay sát thân và cổ tay thẳng<br>Cuốn tạ chậm, giữ thân ổn định | `curl_not_full_range` | Gập khuỷu tay thêm có kiểm soát<br>Cuốn tạ gần vai, giữ khuỷu sát thân | Cuốn tạ gần vai |
| Đẩy ngực tạ đơn trên sàn<br>`dumbbell-floor-press` | Giữ cổ tay thẳng khi đẩy tạ lên trên ngực<br>Hạ tạ chậm, để cánh tay chạm sàn nhẹ | `press_not_locked_out` | Duỗi tay lên trên ngực nhẹ nhàng<br>Đẩy tạ lên trong tầm kiểm soát | Duỗi tay lên |

## Quy tắc viết

- Viết tiếng Việt tự nhiên, có dấu, UTF-8 không BOM và Unicode NFC. Không dùng tiếng Anh, viết tắt, emoji, chữ số, ký hiệu hay placeholder trong câu đọc. Dấu phẩy và dấu chấm thông thường giúp ngắt nhịp.
- Đếm từ theo khoảng trắng như bộ câu giọng nói hiện có: `startTip` tối đa 12, `cue` tối đa 8, `minimal` tối đa 4. Mảng giữ đúng số mẫu; không tạo biến thể bằng việc chỉ đổi dấu câu.
- Mỗi mẫu nói việc cần làm bằng câu khẳng định: nêu bộ phận và động tác hoặc vị trí cần hướng tới. Giữ giọng trung tính, không thêm lời khen, xưng hô, chê bai hay phán xét để ghép được với mọi phong cách.
- Bám hướng dẫn bài và ý nghĩa của `formRule`, không suy ra lỗi khác. Ví dụ, `curl_not_full_range` hiện kiểm tra mức gập khuỷu ở đỉnh cuốn tạ nên nhắc cuốn gần vai; `row_not_high_enough` nhắc kéo về eo hoặc đưa khuỷu ra sau.
- Với lỗi dải góc (`band`) như `body_not_straight` và `knee_not_at_90`, mã không cho biết lệch hướng nào. Nhắc chỉnh về thẳng hàng hoặc gần vuông góc; không mặc định hạ/nâng hông hay ngồi sâu hơn. Với `press_not_locked_out`, nhắc duỗi tay có kiểm soát, tránh yêu cầu khóa cứng khuỷu tay.
- Ưu tiên nhắc chậm, ổn định và tầm thoải mái cho động tác liên quan gối/lưng. Không ép đạt ngưỡng camera, giật tạ, nảy người, quá tầm hay cố thêm khi đau; không hứa hẹn chữa bệnh. Ngưỡng cấu hình không thay thế giới hạn vận động của người tập.
- Mẹo đầu bài và câu đầy đủ giữ bối cảnh kiểm soát; bản tối giản ưu tiên động tác ngắn, không thêm yêu cầu cố sức. Nếu đau, người tập cần dừng bài và kiểm tra hướng dẫn; câu sửa tư thế không phải lời khuyên tiếp tục tập qua đau.
- Review thủ công để xác nhận ý nghĩa, an toàn và tiếng Việt; nghe thử trên thiết bị để kiểm tra ngắt nhịp và phát âm. Script không đánh giá được nội dung y khoa, nhận diện đầy đủ tiếng Anh/viết tắt hoặc chất lượng giọng máy.

## Kiểm tra

Từ thư mục gốc repo, dùng Python 3 và thư viện chuẩn:

```powershell
python docs/content/validate_form_cues.py
```

Kiểm tra một bản JSON khác bằng cùng nguồn seed/cấu hình trong repo:

```powershell
python docs/content/validate_form_cues.py --json path/to/form-cues.json
```

Script trả mã `0` khi hợp lệ, mã `1` khi lỗi. Nó đọc trực tiếp seed và cấu hình CV, không sao chép danh sách mã lỗi vào script. Nó kiểm tra:

- Đúng 20 slug trong seed; không thiếu, thừa hoặc trùng slug. Không lọc theo `cv.supported`.
- Đúng 22 cặp bài/mã lỗi và khớp từng bài với `formRules` của `activeVersion`. Nếu có nhiều góc camera cùng phiên bản hoạt động, lấy hợp các mã. Bỏ qua các phiên bản cũ; lỗi nếu không tìm thấy phiên bản hoạt động.
- JSON UTF-8 không BOM, không khóa trùng, không giá trị số ngoài chuẩn JSON; đúng phiên bản số nguyên `1` và đúng các trường dữ liệu.
- Số mẫu 1–2 / 2–3 / 1 và giới hạn từ 12 / 8 / 4; chuỗi không rỗng, chuẩn NFC, không ký tự điều khiển, emoji, chữ số, placeholder hoặc ký hiệu khó đọc. Không cho mẫu trùng trong cùng mảng, kể cả chỉ khác hoa/thường, khoảng trắng hoặc dấu câu cuối.

## Thêm bài hoặc mã lỗi

1. Đọc thay đổi `formRules` trong phiên bản CV sẽ hoạt động và hướng dẫn/câu gợi ý của bài trong seed. Xác định chính xác điều kiện lỗi, động tác sửa và mã `code`; không đổi mã chỉ để hợp với câu có sẵn. Cấu hình CV được sửa trong công việc riêng của bên phụ trách.
2. Khi phiên bản đó được kích hoạt, thêm `issues[code]` cho đúng `slug`, gồm 2–3 câu `cue` và một câu `minimal`. Giữ các mã còn hoạt động ở mọi góc camera; bỏ mã đã ngừng hoạt động khi không còn trong hợp đồng. Không thêm mã chỉ có ở cấu hình cũ hoặc chưa hoạt động vào bộ nội dung hiện tại.
3. Bài mới luôn có 1–2 mẫu `startTip`; nếu chưa có `formRule`, để `issues: {}`. Không bỏ bài chỉ vì camera chưa hỗ trợ trong seed.
4. Cập nhật bảng tài liệu và bảng hợp đồng trong prompt qua công việc được phép. Khi tổng số bài/cặp đổi, cập nhật `EXPECTED_EXERCISES` và `EXPECTED_PAIRS` trong script sau khi thống nhất hợp đồng; giữ phép đối chiếu từng slug/mã với các file nguồn. Không nới số đếm chỉ để che thiếu câu nhắc.
5. Chạy script, review câu sửa theo đúng điều kiện lỗi và nghe thử giọng tiếng Việt. Thay đổi cấu trúc/phiên bản nội dung cần thống nhất với app; thêm mã vẫn giữ phiên bản `1` nếu cấu trúc không đổi.
6. Gửi Claude Code review nội dung và script trước khi merge. Bên app tích hợp trong nhánh riêng.
