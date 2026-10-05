# Đối chiếu 30 món ưu tiên cho demo

Ngày đối chiếu: 2026-10-04. Dữ liệu đích: `mongo/seed/foods.json`.

## Phạm vi và cách hiểu kết quả

Repo không có thống kê lượt chọn món để xếp hạng “phổ biến nhất”. Bộ 30 món ưu tiên được chọn theo yêu cầu, trải trên cơm, phở/bún, bánh mì, xôi, món cuốn/chiên và đồ uống; không coi đây là bảng xếp hạng quốc gia.

Đã đối chiếu **mật độ dinh dưỡng nguyên liệu** với nguồn gốc bên dưới và cộng theo công thức khẩu phần được công khai. Khối lượng thành phần, dầu giữ lại, nước dùng và topping là mô hình biên soạn, chưa cân mẫu quán. Sai lệch >15% là sai lệch với **mô hình này**, không phải chứng minh mọi suất ngoài thị trường sai. Không có nguồn nào dưới đây công bố trực tiếp đủ 30 món thành phẩm theo các khẩu phần này.

21 món có ít nhất một trường kcal/protein/carbs/fat lệch >15% nên cập nhật đồng bộ bộ số liệu tính lại; 9 món giữ số cũ vì tất cả trường nằm trong ngưỡng. So sánh bằng số chưa làm tròn: `abs(mô hình - cũ) / cũ`. Cả 30 món có `sourceNote` cụ thể; 70 món ngoài phạm vi được giữ nguyên. Tổng gam mô hình khớp khẩu phần hiện có, nên không có căn cứ đổi `servingGrams`.

Chỉ **Cơm trắng** đặt `verified: true`: đối chiếu trực tiếp cơm chín FDC 168878 rồi nhân 1,5 cho phần 150g. Việc xác minh ở đây là mật độ và phép quy đổi, không phải cân một chén thực tế. 29 món tổng hợp giữ `false`, gồm cả món có nguyên liệu thay thế hoặc hiệu suất nấu chưa đo.

## Nguồn đã đọc

- [Bảng thành phần thực phẩm Việt Nam — Viện Dinh dưỡng, NXB Y học, 2007 (bản FAO)](https://www.fao.org/fileadmin/templates/food_composition/documents/pdf/VTN_FCT_2007.pdf): mã 1010 bánh đa nem (trang in 10, trang PDF 23), 1012 bánh mì (12 / PDF 25), 1013 bánh phở (13 / PDF 26), 1020 bún (20 / PDF 33). Đơn vị: 100g phần ăn được. Dấu “-” là thiếu dữ liệu, không phải 0; lipid của bún là thiếu nên dùng bộ USDA đủ macro làm proxy.
- [USDA FoodData Central — trang tải dữ liệu](https://fdc.nal.usda.gov/download-datasets/) và [SR Legacy tháng 04/2018 CSV](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip): đã tải thật, đọc `food.csv`, `food_nutrient.csv`, `nutrient.csv`. Lọc nutrient_id 1008 (kcal), 1003 (protein), 1005 (carbs), 1004 (fat). Mỗi FDC ID bên dưới có đủ bốn số; không tự điền số còn thiếu.

Không dùng bài blog calo hoặc số nhớ từ trước làm nguồn xác minh. Các nguyên liệu thay thế được ghi rõ trong công thức/hạn chế.

## Bảng kết quả — cũ → mới

P/C/F lần lượt là protein/carbs/fat, đơn vị g; kcal theo toàn khẩu phần. “Giữ” vẫn đã rà và bổ sung nguồn. Mã nguồn có thể tra ở bảng nguyên liệu và công thức phía dưới.

| Món | Gam cũ → mới | kcal cũ → mới | P cũ → mới | C cũ → mới | F cũ → mới | Lệch lớn nhất | Xử lý / verified | Nguồn |
|---|---:|---:|---:|---:|---:|---:|---|---|
| Cơm tấm sườn bì chả | 450 → 450 | 750 → 779.7 | 35 → 44.8 | 90 → 79.9 | 28 → 29.4 | 28.08% | Sửa / false | USDA SR Legacy |
| Cơm tấm sườn nướng | 350 → 350 | 580 → 580 | 28 → 28 | 75 → 75 | 19 → 19 | 10.32% | Giữ / false | USDA SR Legacy |
| Cơm gà luộc | 350 → 350 | 520 → 520 | 30 → 30 | 70 → 70 | 13 → 13 | 3.27% | Giữ / false | USDA SR Legacy |
| Cơm gà xối mỡ | 400 → 400 | 700 → 717.4 | 32 → 36.9 | 80 → 76.7 | 28 → 27.7 | 15.32% | Sửa / false | USDA SR Legacy |
| Cơm gà Hội An | 350 → 350 | 550 → 550 | 28 → 28 | 75 → 75 | 15 → 15 | 12.97% | Giữ / false | USDA SR Legacy |
| Cơm chiên trứng | 300 → 300 | 500 → 470.4 | 15 → 15.2 | 70 → 58.3 | 18 → 18.5 | 16.72% | Sửa / false | USDA SR Legacy |
| Cơm trắng | 150 → 150 | 195 → 195 | 4 → 4.04 | 43 → 42.26 | 0.5 → 0.42 | 16.00% | Sửa / true | USDA SR Legacy |
| Phở bò tái | 550 → 550 | 430 → 535.5 | 28 → 35.1 | 60 → 69.1 | 9 → 12.8 | 41.84% | Sửa / false | VDD 2007 + USDA SR Legacy |
| Phở bò chín | 550 → 550 | 450 → 581 | 30 → 32.4 | 60 → 69.1 | 10 → 19.3 | 93.09% | Sửa / false | VDD 2007 + USDA SR Legacy |
| Phở gà | 550 → 550 | 420 → 503.8 | 28 → 28.7 | 58 → 69.2 | 8 → 11.8 | 47.98% | Sửa / false | VDD 2007 + USDA SR Legacy |
| Bún bò Huế | 600 → 600 | 550 → 641.2 | 30 → 35.6 | 65 → 63.6 | 19 → 26.2 | 37.89% | Sửa / false | USDA SR Legacy; đối chiếu bún VDD 1020 |
| Bún chả Hà Nội | 450 → 450 | 580 → 680.5 | 28 → 34.8 | 70 → 69.3 | 22 → 29 | 31.95% | Sửa / false | USDA SR Legacy; đối chiếu bún VDD 1020 |
| Bún thịt nướng | 400 → 400 | 550 → 622.7 | 25 → 31.8 | 75 → 66.2 | 17 → 25 | 46.98% | Sửa / false | USDA SR Legacy; đối chiếu bún VDD 1020 |
| Bún riêu cua | 550 → 550 | 450 → 501.4 | 22 → 28.2 | 60 → 55.9 | 14 → 18.5 | 32.20% | Sửa / false | USDA SR Legacy; đối chiếu bún VDD 1020 |
| Bún đậu mắm tôm | 450 → 450 | 650 → 795.1 | 30 → 51.1 | 65 → 63.2 | 30 → 38.9 | 70.20% | Sửa / false | USDA SR Legacy; đối chiếu bún VDD 1020 |
| Hủ tiếu Nam Vang | 550 → 550 | 460 → 508.6 | 28 → 28.7 | 65 → 58.9 | 10 → 16.8 | 68.38% | Sửa / false | USDA SR Legacy; đối chiếu bún VDD 1020 |
| Hủ tiếu bò kho | 550 → 550 | 520 → 646.3 | 30 → 33.8 | 65 → 64.6 | 16 → 27.3 | 70.62% | Sửa / false | USDA SR Legacy; đối chiếu bún VDD 1020 |
| Mì Quảng | 450 → 450 | 550 → 614.9 | 28 → 32.1 | 65 → 65.2 | 20 → 24.4 | 22.00% | Sửa / false | VDD 2007 + USDA SR Legacy; đối chiếu bún VDD 1020 |
| Bánh mì thịt | 200 → 200 | 470 → 470 | 20 → 20 | 55 → 55 | 19 → 19 | 13.09% | Giữ / false | VDD 2007 + USDA SR Legacy |
| Bánh mì trứng | 200 → 200 | 440 → 440 | 18 → 18 | 50 → 50 | 19 → 19 | 3.71% | Giữ / false | VDD 2007 + USDA SR Legacy |
| Xôi đậu xanh | 200 → 200 | 380 → 428.1 | 10 → 8.2 | 70 → 84.3 | 7 → 5.6 | 20.37% | Sửa / false | USDA SR Legacy |
| Xôi gấc | 200 → 200 | 400 → 400 | 6 → 6 | 78 → 78 | 7 → 7 | 14.70% | Giữ / false | USDA SR Legacy |
| Xôi mặn | 250 → 250 | 550 → 550 | 18 → 18 | 75 → 75 | 20 → 20 | 11.66% | Giữ / false | USDA SR Legacy |
| Xôi gà | 250 → 250 | 480 → 480 | 22 → 22 | 70 → 70 | 12 → 12 | 7.63% | Giữ / false | USDA SR Legacy |
| Gỏi cuốn tôm thịt | 180 → 180 | 230 → 235 | 14 → 15.9 | 30 → 32.6 | 6 → 4.2 | 30.60% | Sửa / false | VDD 2007 + USDA SR Legacy; đối chiếu bún VDD 1020 |
| Chả giò | 150 → 150 | 350 → 372.8 | 12 → 14.7 | 30 → 27.6 | 20 → 22.9 | 22.25% | Sửa / false | VDD 2007 + USDA SR Legacy |
| Bánh xèo | 250 → 250 | 420 → 473.6 | 15 → 17.3 | 45 → 50.7 | 20 → 22.4 | 15.58% | Sửa / false | USDA SR Legacy |
| Bánh cuốn | 250 → 250 | 350 → 384.1 | 15 → 18.4 | 50 → 42 | 10 → 15.5 | 54.51% | Sửa / false | USDA SR Legacy |
| Trà sữa trân châu | 500 → 500 | 420 → 371.8 | 5 → 7.5 | 75 → 68.7 | 11 → 7.9 | 50.82% | Sửa / false | USDA SR Legacy |
| Cà phê sữa đá | 200 → 200 | 130 → 130 | 3 → 3 | 21 → 21 | 4 → 4 | 12.70% | Giữ / false | USDA SR Legacy |

## Dữ liệu nguyên liệu để tính lại

Tất cả số là trên 100g, theo đúng trạng thái khô/chín ghi trong nguồn. Không áp số gạo/bột khô trực tiếp lên gam món chín. Nước hút vào, nước pha và đá tính khối lượng nhưng không thêm năng lượng. Các biến thể “thay thế” không có nghĩa nguồn đã phân tích món Việt tương ứng.

| Ký hiệu | Nguyên liệu / trạng thái | Mã nguồn | kcal | P | C | F |
|---|---|---|---:|---:|---:|---:|
| rice | cơm chín | USDA FDC 168878 | 130 | 2.69 | 28.17 | 0.28 |
| pork | thăn heo chín cả nạc/mỡ | USDA FDC 167820 | 242 | 27.32 | 0 | 13.92 |
| ground | heo xay chín | USDA FDC 168374 | 301 | 27.14 | 0 | 21.39 |
| beef | bò chín ít mỡ | USDA FDC 168632 | 202 | 29.53 | 0 | 8.41 |
| beeffat | bò chín cả nạc/mỡ | USDA FDC 169484 | 259 | 26.11 | 0 | 16.59 |
| chicken | gà hầm có da | USDA FDC 171051 | 219 | 24.68 | 0 | 12.56 |
| chickenlean | gà hầm bỏ da | USDA FDC 171451 | 177 | 27.29 | 0 | 6.71 |
| chickenroast | gà quay có da | USDA FDC 171450 | 239 | 27.3 | 0 | 13.6 |
| egg | trứng luộc | USDA FDC 173424 | 155 | 12.58 | 1.12 | 10.61 |
| oil | dầu đậu nành giữ lại trong món | USDA FDC 171411 | 884 | 0 | 0 | 100 |
| sugar | đường | USDA FDC 169655 | 387 | 0 | 99.98 | 0 |
| fishsauce | nước mắm | USDA FDC 174531 | 35 | 5.06 | 3.64 | 0.01 |
| cucumber | dưa leo | USDA FDC 168409 | 15 | 0.65 | 3.63 | 0.11 |
| carrot | cà rốt | USDA FDC 170393 | 41 | 0.93 | 9.58 | 0.24 |
| onion | hành tây | USDA FDC 170000 | 40 | 1.1 | 9.34 | 0.1 |
| lettuce | xà lách | USDA FDC 169249 | 15 | 1.36 | 2.87 | 0.15 |
| tomato | cà chua sống | USDA FDC 170457 | 18 | 0.88 | 3.89 | 0.2 |
| beefstock | nước dùng bò | USDA FDC 172883 | 13 | 1.97 | 1.2 | 0.09 |
| chickenstock | nước dùng gà cô đặc hơn canh thông thường | USDA FDC 172884 | 36 | 2.52 | 3.53 | 1.2 |
| noodle | bún/sợi gạo chín thay thế | USDA FDC 168914 | 108 | 1.79 | 24.01 | 0.2 |
| shrimp | tôm chín | USDA FDC 171971 | 119 | 22.78 | 1.52 | 1.7 |
| crab | cua biển chín thay thế riêu cua đồng | USDA FDC 172007 | 110 | 22.32 | 0.95 | 1.24 |
| tofu | đậu hũ chiên | USDA FDC 172451 | 270 | 18.82 | 8.86 | 20.18 |
| peanut | đậu phộng rang | USDA FDC 173806 | 587 | 24.35 | 21.26 | 49.66 |
| glutinous | gạo nếp khô | USDA FDC 168883 | 370 | 6.81 | 81.68 | 0.55 |
| mung | đậu xanh chín | USDA FDC 174257 | 105 | 7.02 | 19.15 | 0.38 |
| riceflour | bột gạo khô | USDA FDC 169714 | 366 | 5.95 | 80.13 | 1.42 |
| coconut | nước cốt dừa | USDA FDC 170172 | 230 | 2.29 | 5.54 | 23.84 |
| pate | pâté gan thay thế | USDA FDC 172930 | 319 | 14.2 | 1.5 | 28 |
| ham | ham heo chín thay thế chả/lạp xưởng | USDA FDC 167872 | 178 | 22.62 | 0 | 9.02 |
| mushroom | nấm chín thay thế mộc nhĩ | USDA FDC 169252 | 28 | 2.17 | 5.29 | 0.47 |
| milk | sữa nguyên kem | USDA FDC 171265 | 61 | 3.15 | 4.8 | 3.25 |
| condensed | sữa đặc có đường | USDA FDC 171275 | 321 | 7.91 | 54.4 | 8.7 |
| tapioca | trân châu khô trước khi hút nước | USDA FDC 169717 | 358 | 0.19 | 88.69 | 0.02 |
| tea | trà đen pha | USDA FDC 173227 | 1 | 0 | 0.3 | 0 |
| coffee | cà phê pha | USDA FDC 171890 | 1 | 0.12 | 0 | 0.02 |
| pho | bánh phở | VDD 2007 1013, tr.13 | 143 | 3.2 | 31.7 | 0.4 |
| bread | bánh mì | VDD 2007 1012, tr.12 | 249 | 7.9 | 52.6 | 0.8 |
| paper | bánh đa nem khô | VDD 2007 1010, tr.10 | 333 | 4 | 78.9 | 0.2 |
| water | nước/đá hoặc nước hút vào khi nấu | không sinh năng lượng | 0 | 0 | 0 | 0 |
| pork_bi | nạc heo thay phần thịt trong bì; chưa định lượng da | USDA FDC 167820 | 242 | 27.32 | 0 | 13.92 |

## Công thức khẩu phần và giới hạn

Phép tính cho từng chất: `tổng(gam nguyên liệu / 100 × giá trị mỗi 100g)`. Tổng gam ở các công thức đều đúng `servingGrams`. Cột tính lại là **mô hình**; với 9 món giữ số cũ, cột này khác số được lưu trong seed. Số cuối làm tròn 0,1; Cơm trắng giữ 2 chữ số macro để tránh mất độ chính xác ở chất béo thấp.

| Món | Thành phần và gam / mã nguồn | Mô hình kcal / P / C / F | Giới hạn |
|---|---|---|---|
| Cơm tấm sườn bì chả | 230g cơm chín [USDA FDC 168878] + 90g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 30g trứng luộc [USDA FDC 173424] + 15g heo xay chín [USDA FDC 168374] + 20g nạc heo thay phần thịt trong bì; chưa định lượng da [USDA FDC 167820] + 4g bột gạo khô [USDA FDC 169714] + 7g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 10g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] + 39g dưa leo [USDA FDC 168409] | 779.7 / 44.8 / 79.9 / 29.4 | Bì dùng nạc heo thay thế, chả mô hình heo xay + trứng; chưa có phân tích trực tiếp bì/chả và khẩu phần chưa cân. |
| Cơm tấm sườn nướng | 220g cơm chín [USDA FDC 168878] + 90g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 10g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] + 20g dưa leo [USDA FDC 168409] | 591.5 / 30.9 / 72.9 / 18.2 | Thăn heo có mỡ thay sườn bỏ xương; dầu/sốt và phần ăn giả định. |
| Cơm gà luộc | 220g cơm chín [USDA FDC 168878] + 100g gà hầm có da [USDA FDC 171051] + 20g dưa leo [USDA FDC 168409] + 5g nước mắm [USDA FDC 174531] + 5g đường [USDA FDC 169655] | 529.1 / 31 / 67.9 / 13.2 | Gà hầm có da thay gà luộc; phần ăn giả định. |
| Cơm gà xối mỡ | 240g cơm chín [USDA FDC 168878] + 110g gà quay có da [USDA FDC 171450] + 12g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 8g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] + 25g dưa leo [USDA FDC 168409] | 717.4 / 36.9 / 76.7 / 27.7 | Gà quay có da + dầu giữ lại thay gà xối mỡ; phần ăn giả định. |
| Cơm gà Hội An | 220g cơm chín [USDA FDC 168878] + 90g gà hầm có da [USDA FDC 171051] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] + 25g hành tây [USDA FDC 170000] | 558.4 / 28.7 / 69.5 / 16.9 | Gà hầm có da và dầu mô hình hóa gà xé/cơm nấu nước gà; phần ăn giả định. |
| Cơm chiên trứng | 200g cơm chín [USDA FDC 168878] + 75g trứng luộc [USDA FDC 173424] + 10g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 10g hành tây [USDA FDC 170000] + 5g nước mắm [USDA FDC 174531] | 470.4 / 15.2 / 58.3 / 18.5 | Trứng luộc + dầu giữ lại thay trứng chiên; phần ăn giả định. |
| Cơm trắng | 150g cơm chín [USDA FDC 168878] | 195 / 4.04 / 42.26 / 0.42 | Đối chiếu trực tiếp mật độ dưỡng chất cơm chín USDA; quy đổi 150g phần ăn được, không xác minh trọng lượng chén thực tế. |
| Phở bò tái | 200g bánh phở [VDD 2007 1013, tr.13] + 80g bò chín ít mỡ [USDA FDC 168632] + 230g nước dùng bò [USDA FDC 172883] + 30g hành tây [USDA FDC 170000] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g nước mắm [USDA FDC 174531] | 535.5 / 35.1 / 69.1 / 12.8 | Bò chín ít mỡ thay bò tái đã chần; nước dùng và phần ăn giả định. |
| Phở bò chín | 200g bánh phở [VDD 2007 1013, tr.13] + 80g bò chín cả nạc/mỡ [USDA FDC 169484] + 230g nước dùng bò [USDA FDC 172883] + 30g hành tây [USDA FDC 170000] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g nước mắm [USDA FDC 174531] | 581 / 32.4 / 69.1 / 19.3 | Bò chín hỗn hợp nạc/mỡ thay nạm; nước dùng và phần ăn giả định. |
| Phở gà | 200g bánh phở [VDD 2007 1013, tr.13] + 80g gà hầm có da [USDA FDC 171051] + 80g nước dùng gà cô đặc hơn canh thông thường [USDA FDC 172884] + 155g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] + 30g hành tây [USDA FDC 170000] + 5g nước mắm [USDA FDC 174531] | 503.8 / 28.7 / 69.2 / 11.8 | Nước dùng gà được pha loãng 80g stock + 155g nước; phần ăn giả định. |
| Bún bò Huế | 220g bún/sợi gạo chín thay thế [USDA FDC 168914] + 60g bò chín cả nạc/mỡ [USDA FDC 169484] + 40g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 230g nước dùng bò [USDA FDC 172883] + 30g hành tây [USDA FDC 170000] + 10g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] | 641.2 / 35.6 / 63.6 / 26.2 | Không gồm giò nguyên xương/huyết; sợi gạo chín thay bún, thịt heo thay giò ăn được; phần ăn giả định. |
| Bún chả Hà Nội | 220g bún/sợi gạo chín thay thế [USDA FDC 168914] + 110g heo xay chín [USDA FDC 168374] + 15g đường [USDA FDC 169655] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 10g nước mắm [USDA FDC 174531] + 40g xà lách [USDA FDC 169249] + 50g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 680.5 / 34.8 / 69.3 / 29 | Heo xay chín thay hỗn hợp chả viên/chả miếng; dầu/đường nước chấm tính riêng; phần ăn giả định. |
| Bún thịt nướng | 220g bún/sợi gạo chín thay thế [USDA FDC 168914] + 90g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 10g đậu phộng rang [USDA FDC 173806] + 7g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 10g đường [USDA FDC 169655] + 8g nước mắm [USDA FDC 174531] + 35g xà lách [USDA FDC 169249] + 20g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 622.7 / 31.8 / 66.2 / 25 | Thăn heo nướng thay thịt ướp, sợi gạo chín thay bún; phần ăn giả định. |
| Bún riêu cua | 200g bún/sợi gạo chín thay thế [USDA FDC 168914] + 30g cua biển chín thay thế riêu cua đồng [USDA FDC 172007] + 20g heo xay chín [USDA FDC 168374] + 20g trứng luộc [USDA FDC 173424] + 30g đậu hũ chiên [USDA FDC 172451] + 60g cà chua sống [USDA FDC 170457] + 180g nước dùng bò [USDA FDC 172883] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g nước mắm [USDA FDC 174531] | 501.4 / 28.2 / 55.9 / 18.5 | Cua biển thay cua đồng; heo xay + trứng mô hình riêu, không suy ra món đã kiểm nghiệm; phần ăn giả định. |
| Bún đậu mắm tôm | 180g bún/sợi gạo chín thay thế [USDA FDC 168914] + 100g đậu hũ chiên [USDA FDC 172451] + 70g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 40g ham heo chín thay thế chả/lạp xưởng [USDA FDC 167872] + 10g đường [USDA FDC 169655] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 25g xà lách [USDA FDC 169249] + 10g nước mắm [USDA FDC 174531] + 10g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 795.1 / 51.1 / 63.2 / 38.9 | Ham thay chả cốm, nước mắm thay macro mắm tôm; chưa có dữ liệu đúng chả/mắm, phần ăn giả định. |
| Hủ tiếu Nam Vang | 220g bún/sợi gạo chín thay thế [USDA FDC 168914] + 40g heo xay chín [USDA FDC 168374] + 30g tôm chín [USDA FDC 171971] + 20g trứng luộc [USDA FDC 173424] + 200g nước dùng bò [USDA FDC 172883] + 30g hành tây [USDA FDC 170000] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g nước mắm [USDA FDC 174531] | 508.6 / 28.7 / 58.9 / 16.8 | Sợi gạo chín thay hủ tiếu, không gồm gan; phần ăn giả định. |
| Hủ tiếu bò kho | 220g bún/sợi gạo chín thay thế [USDA FDC 168914] + 100g bò chín cả nạc/mỡ [USDA FDC 169484] + 50g cà rốt [USDA FDC 170393] + 165g nước dùng bò [USDA FDC 172883] + 10g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] | 646.3 / 33.8 / 64.6 / 27.3 | Sợi gạo chín thay hủ tiếu; thịt/nước dùng và dầu giữ lại giả định. |
| Mì Quảng | 220g bún/sợi gạo chín thay thế [USDA FDC 168914] + 60g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 30g tôm chín [USDA FDC 171971] + 10g đậu phộng rang [USDA FDC 173806] + 10g bánh đa nem khô [VDD 2007 1010, tr.10] + 75g nước dùng bò [USDA FDC 172883] + 10g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 30g xà lách [USDA FDC 169249] + 5g nước mắm [USDA FDC 174531] | 614.9 / 32.1 / 65.2 / 24.4 | Sợi gạo chín thay mì Quảng, bánh đa nem thay bánh tráng nướng; phần ăn giả định. |
| Bánh mì thịt | 90g bánh mì [VDD 2007 1012, tr.12] + 45g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 20g pâté gan thay thế [USDA FDC 172930] + 7g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] + 20g dưa leo [USDA FDC 168409] + 10g cà rốt [USDA FDC 170393] + 3g nước mắm [USDA FDC 174531] | 486.2 / 22.6 / 54.4 / 19.6 | Thịt heo chín/pâté gan thay nhân thịt nguội/pâté quán; không thêm chả, phần ăn giả định. |
| Bánh mì trứng | 90g bánh mì [VDD 2007 1012, tr.12] + 80g trứng luộc [USDA FDC 173424] + 10g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 15g dưa leo [USDA FDC 168409] + 3g đường [USDA FDC 169655] + 2g nước mắm [USDA FDC 174531] | 451.1 / 17.4 / 51.9 / 19.2 | Trứng luộc + dầu giữ lại thay trứng chiên; phần ăn giả định. |
| Xôi đậu xanh | 90g gạo nếp khô [USDA FDC 168883] + 70g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] + 30g đậu xanh chín [USDA FDC 174257] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] | 428.1 / 8.2 / 84.3 / 5.6 | Tính từ gạo nếp KHÔ, nước hấp hút vào riêng; đậu xanh chín, dầu/đường và hiệu suất nấu giả định. |
| Xôi gấc | 90g gạo nếp khô [USDA FDC 168883] + 79g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] + 6g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 15g đường [USDA FDC 169655] + 10g cà rốt [USDA FDC 170393] | 448.2 / 6.2 / 89.5 / 6.5 | Cà rốt chỉ là proxy macro cho 10g thịt gấc; gạo nếp KHÔ và nước hút vào riêng, chưa xác minh gấc/hiệu suất nấu. |
| Xôi mặn | 85g gạo nếp khô [USDA FDC 168883] + 85g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] + 30g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 20g trứng luộc [USDA FDC 173424] + 10g ham heo chín thay thế chả/lạp xưởng [USDA FDC 167872] + 10g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] | 545.4 / 19 / 74.8 / 17.7 | Ham thay chả/lạp xưởng; gạo nếp KHÔ và nước hút vào riêng, topping/hiệu suất nấu giả định. |
| Xôi gà | 85g gạo nếp khô [USDA FDC 168883] + 85g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] + 65g gà hầm bỏ da [USDA FDC 171451] + 7g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] + 3g nước mắm [USDA FDC 174531] | 511.8 / 23.7 / 74.5 / 11.8 | Gạo nếp KHÔ và nước hút vào riêng; gà bỏ da, dầu/hiệu suất nấu giả định. |
| Gỏi cuốn tôm thịt | 18g bánh đa nem khô [VDD 2007 1010, tr.10] + 50g bún/sợi gạo chín thay thế [USDA FDC 168914] + 30g tôm chín [USDA FDC 171971] + 25g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 25g xà lách [USDA FDC 169249] + 5g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] + 22g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 235 / 15.9 / 32.6 / 4.2 | Bánh đa nem khô và nước làm mềm tách riêng; gồm nước chấm loãng, không sốt đậu phộng; phần ăn giả định. |
| Chả giò | 20g bánh đa nem khô [VDD 2007 1010, tr.10] + 35g heo xay chín [USDA FDC 168374] + 15g tôm chín [USDA FDC 171971] + 20g cà rốt [USDA FDC 170393] + 10g nấm chín thay thế mộc nhĩ [USDA FDC 169252] + 5g bột gạo khô [USDA FDC 169714] + 15g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] + 20g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 372.8 / 14.7 / 27.6 / 22.9 | Nấm thường thay mộc nhĩ, bột gạo thay phần miến; dầu là lượng giữ lại sau chiên, phần ăn giả định. |
| Bánh xèo | 50g bột gạo khô [USDA FDC 169714] + 30g nước cốt dừa [USDA FDC 170172] + 30g thăn heo chín cả nạc/mỡ [USDA FDC 167820] + 20g tôm chín [USDA FDC 171971] + 30g hành tây [USDA FDC 170000] + 10g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 25g xà lách [USDA FDC 169249] + 5g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] + 45g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 473.6 / 17.3 / 50.7 / 22.4 | Hành/rau thay một phần giá; nước bột và dầu giữ lại giả định, không đo trực tiếp bánh thành phẩm. |
| Bánh cuốn | 45g bột gạo khô [USDA FDC 169714] + 35g heo xay chín [USDA FDC 168374] + 15g nấm chín thay thế mộc nhĩ [USDA FDC 169252] + 25g ham heo chín thay thế chả/lạp xưởng [USDA FDC 167872] + 5g dầu đậu nành giữ lại trong món [USDA FDC 171411] + 5g đường [USDA FDC 169655] + 5g nước mắm [USDA FDC 174531] + 115g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 384.1 / 18.4 / 42 / 15.5 | Ham thay chả lụa, nấm thường thay mộc nhĩ; bột khô và nước hấp tách riêng, phần ăn giả định. |
| Trà sữa trân châu | 150g sữa nguyên kem [USDA FDC 171265] + 35g sữa đặc có đường [USDA FDC 171275] + 20g đường [USDA FDC 169655] + 25g trân châu khô trước khi hút nước [USDA FDC 169717] + 100g trà đen pha [USDA FDC 173227] + 170g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 371.8 / 7.5 / 68.7 / 7.9 | Trân châu 25g KHÔ + 50g nước trong 170g nước/đá thành khoảng 75g chín; dùng sữa thật, không bột béo; chưa đo ly thực tế. |
| Cà phê sữa đá | 40g sữa đặc có đường [USDA FDC 171275] + 60g cà phê pha [USDA FDC 171890] + 100g nước/đá hoặc nước hút vào khi nấu [không sinh năng lượng] | 129 / 3.2 / 21.8 / 3.5 | Sữa đặc 40g, cà phê pha 60g, đá 100g; cà phê pha USDA thay cà phê phin, ly chưa cân. |

Ví dụ kiểm toán trực tiếp: Cơm trắng dùng 150g cơm chín FDC 168878: kcal `130 × 1,5 = 195`; P `2,69 × 1,5 = 4,035`; C `28,17 × 1,5 = 42,255`; F `0,28 × 1,5 = 0,42`. Chất béo cũ 0,5g lệch 16%, nên cập nhật bộ macro.

## Kiểm tra dữ liệu

- JSON hợp lệ, còn đủ 100 món và thứ tự/tên/alias/category/source không đổi.
- Có đúng 30 món được bổ sung nguồn; 21 bộ số liệu cập nhật, 9 bộ giữ nguyên; khẩu phần không đổi.
- Tính lại từ bảng nguyên liệu cho mỗi công thức và kiểm tra tổng gam; số lưu ở món sửa khớp phép tính sau làm tròn.
- Kiểm tra toàn bộ 100 món: `abs(kcal - (4*P + 4*C + 9*F)) / kcal <= 0,15`; đã đạt, sai lệch lớn nhất 11,03%.
- Chỉ Cơm trắng đổi sang verified true; mọi món tổng hợp và 70 món chưa rà vẫn false.
- Không chạy nạp seed vào MongoDB trong tác vụ này; backend/app giữ nguyên.

## Dấu vết đối chiếu

SHA-256 gói USDA đã tải: `b80817294b8850530aaedf2e515c02593b1824f763a0ff356e5c2081643e6fd0`.

Có thể tải lại gói chính thức, tra FDC ID và bốn nutrient_id phía trên để tái tính. Công thức/hạn chế có trong báo cáo này và `sourceNote` từng món; script kiểm tra chỉ lưu tạm, không commit.

## Đối chiếu Phở bò tái với test backend (2026-10-05)

**Giữ `kcal: 535.5` cho khẩu phần 550 g trong `foods.json`; API nhận diện trả `kcal=536`, `kcalMin=455`, `kcalMax=616`.** Số 430 kcal trong `NutritionFlowTest` là kỳ vọng theo seed ước tính cũ, không khớp mô hình khẩu phần đã công khai ở trên. Kết luận này áp dụng cho mô hình của repo, không khẳng định mọi tô phở ngoài quán đều có cùng năng lượng; `verified=false` giữ nguyên.

Đã đọc lại [PDF Viện Dinh dưỡng 2007](https://www.fao.org/fileadmin/templates/food_composition/documents/pdf/VTN_FCT_2007.pdf), mã 1013, trang in 13/trang PDF 26: bánh phở 143 kcal/100 g. Đã tải lại [CSV USDA SR Legacy 04/2018](https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip), tra `food.csv` và `food_nutrient.csv` với nutrient_id 1008; SHA-256 khớp dấu vết trên. Có thể tìm bản tải tại [trang dữ liệu chính thức USDA](https://fdc.nal.usda.gov/download-datasets/).

| Thành phần mô hình | Gam | Nguồn / mã | kcal/100 g | kcal đóng góp |
|---|---:|---|---:|---:|
| Bánh phở | 200 | VDD 2007, 1013 | 143 | 286 |
| Bò chín ít mỡ, thay bò tái đã chần | 80 | USDA FDC 168632 | 202 | 161,6 |
| Nước dùng bò | 230 | USDA FDC 172883 | 13 | 29,9 |
| Hành tây | 30 | USDA FDC 170000 | 40 | 12 |
| Dầu đậu nành giữ lại | 5 | USDA FDC 171411 | 884 | 44,2 |
| Nước mắm | 5 | USDA FDC 174531 | 35 | 1,75 |
| **Tổng** | **550** | | | **535,45** |

Tổng mô hình làm tròn 1 chữ số thành **535,5**, lưu trong JSON; macro giữ **P 35,1 / C 69,1 / F 12,8 g**. Không đổi cấu trúc, khẩu phần, tên/alias hoặc dữ liệu món khác; chỉ bổ sung lý do vào `sourceNote` của Phở bò tái.

Theo `NutritionRules.portion`, tính khoảng từ **535,5 trước khi làm tròn sang số nguyên**:

- `kcal = Math.round(535.5) = 536`.
- `kcalMin = Math.round(535.5 × 0.85) = Math.round(455.175) = 455`.
- `kcalMax = Math.round(535.5 × 1.15) = Math.round(615.825) = 616`.

### Báo Claude Code cập nhật test

Không sửa hoặc chạy test backend trong tác vụ tài liệu này. Sau khi nạp seed mới vào MongoDB dev **cổng 27018**, Claude Code cập nhật `backend/src/test/java/vn/levelup/nutrition/NutritionFlowTest.java` và chạy lại flow test:

| Kỳ vọng trong flow hiện tại | Cũ | Đúng với seed hiện tại |
|---|---:|---:|
| `first.items[0].kcal` (dòng 170) | 430 | **536** |
| `first.items[0].kcalMin` (dòng 171) | 366 | **455** |
| `first.items[0].kcalMax` (dòng 172) | 494 | **616** |
| `afterSnack.consumed.kcal`, `today.consumed.kcal` (thêm sữa chua 120 kcal) | 550 | **656** |
| `today.consumed.proteinG` (thêm 5 g đạm) | 33,0 | **40,1** |
| `today.remaining.kcal` (mục tiêu 1790) | 1240 | **1134** |
| `today.remaining.proteinG` (mục tiêu 112 g) | 79,0 | **71,9** |
| `today.meals[0].kcal` (dòng 214) | 430 | **536** |
| `today.meals[0].kcalMin` (dòng 215) | 366 | **456** |
| Tiền tố thông điệp gợi ý đạm | 79 g | **72 g** |

**Phân biệt khoảng nhận diện và khoảng bữa đã lưu:** `NutritionService` cộng kcal của item đã làm tròn (536), rồi tính khoảng của bữa: `Math.round(536 × 0.85)=456`, `Math.round(536 × 1.15)=616`. Vì vậy min của `today.meals[0]` là **456**, còn min của item nhận diện là **455** theo code hiện tại; không thay đồng loạt mọi 366 bằng 455. `NutritionRulesTest` có fixture riêng 430 kcal, không dùng seed, nên không cần đổi fixture chỉ vì cập nhật dữ liệu món.

Đã tính lại công thức từ nguồn, kiểm tra JSON và phép làm tròn phù hợp Java; chưa nạp dữ liệu vào Atlas/dev và chưa xác nhận một lần chạy backend thực tế.
