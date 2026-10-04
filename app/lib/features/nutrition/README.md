# Nutrition / F8 — bàn giao

- `/nutrition`: ngày do backend trả về, target/consumed/remaining, macro, nước +250 ml, 4 nhóm bữa, gợi ý bữa tối nếu có.
- `/nutrition/photo`: camera hoặc thư viện → nhận diện → sửa gram từng món → chọn bữa → lưu. Món không khớp bắt buộc tìm món thay thế hoặc xóa. 503 tự chuyển sang giao diện thủ công; 413/415/429/502 có hướng dẫn và lối tìm thủ công.
- `/nutrition/add?meal=dinner`: thêm từ kho; `extra: List<Food>` có thể dùng để kiểm tra gợi ý trước khi lưu. Tìm kiếm là màn `FoodSearchScreen` mở bằng Navigator, không cần route shell riêng.
- Repository production luôn dùng `ApiClient`, Fake dùng cho test qua override Riverpod.
- Không ghi ảnh vào bộ nhớ bền vững. `image_picker` dùng file tạm của plugin; app chỉ đọc byte, nén JPEG trong isolate/bộ nhớ, bỏ EXIF, giới hạn 2 MiB rồi base64 + SHA-256 đúng byte nén. Ảnh và bản nháp chỉ giữ trong RAM trong vòng đời màn.
- Package mới: `image_picker` (camera/thư viện), `image` (nén trong bộ nhớ), `crypto` (SHA-256). Biểu đồ progress dùng CustomPainter nên không thêm fl_chart.
- API đã có đủ; JSON đọc theo MealDtos/RecognitionDtos/MeasurementDtos. Không gửi userId/localDate từ thiết bị.

## Tích hợp nền tảng ngoài phạm vi nhánh

TODO(app-shell): trước khi chạy chọn ảnh trên iOS, thêm `NSPhotoLibraryUsageDescription` vào `app/ios/Runner/Info.plist`. Hiện file chỉ có `NSCameraUsageDescription` dành cho đếm rep; cần cập nhật lời giải thích camera để bao gồm ảnh món ăn. Nhánh này không sửa iOS theo phạm vi được giao. Kiểm thử camera/thư viện trên thiết bị thật, gồm quyền bị từ chối và Android khôi phục picker sau khi hệ điều hành hủy Activity, vẫn cần ở bước tích hợp.

## Kiểm tra

`flutter analyze`

`flutter test`

Test mới trong `app/test/features/nutrition/` và `app/test/features/progress/`: luồng Fake repository, lỗi và retry, khẩu phần, fallback AI, xác thực số đo, JSON API, giới hạn ảnh/nén/hash, dữ liệu biểu đồ thưa và huy hiệu mới.

Tổng cộng 38 test mới (Nutrition và layout: 29; Progress: 9). Layout kiểm tra 390/320 px với chữ phóng 1.3 lần. Có thể xuất PNG từ `feature_layout_test.dart` bằng `--dart-define=FEATURE_PREVIEW_DIR=<thư mục đã tồn tại>`; `PREVIEW_FONT_PATH` tùy chọn trỏ tới Roboto-Regular.ttf trong material_fonts của SDK để preview có font thật.
