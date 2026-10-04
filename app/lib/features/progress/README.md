# Tiến độ — bàn giao

- `/progress`: GET `/measurements?days=90`, biểu đồ cân nặng/vòng eo, dữ liệu từng lần đo có thể mở xem, trạng thái trống/lỗi/thử lại, huy hiệu mới từ POST.
- `/progress/measurements`: nhập cân nặng, eo, hông, ngực, tay. Chấp nhận dấu phẩy thập phân; kiểm tra mức min/max đúng MeasurementDtos; ít nhất một chỉ số. Không gửi `measuredOn` để backend tính ngày theo `users.timezone` và gộp trong ngày.
- Điểm biểu đồ sắp theo ngày thật, bỏ trường null, không thay bằng 0; khoảng cách ngang theo số ngày. Hỗ trợ 0 hoặc 1 điểm, chuỗi số đo phẳng và cân/eo ghi ở các ngày khác nhau.
- Huy hiệu lấy từ `newAchievements`, không tự suy ra đã nhận thưởng. Giữ trong provider của phiên app, tên/miêu tả null có fallback mã huy hiệu.
- Có `ApiProgressRepository`, `FakeProgressRepository` và override provider cho test. Không có API thiếu cho phạm vi này.
