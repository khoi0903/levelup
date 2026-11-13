/// Định dạng ngày "YYYY-MM-DD" của máy chủ thành chữ tiếng Việt để hiển thị.
/// Chỉ dùng cho giao diện; nghiệp vụ vẫn dùng chuỗi localDate gốc.
library;

const _weekdayNames = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// "2026-11-13" -> "Thứ Sáu, 13/11". Chuỗi không hợp lệ thì trả nguyên văn.
String viDayLabel(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return isoDate;
  return '${_weekdayNames[d.weekday - 1]}, ${_dm(d)}';
}

/// Ngày đầu tuần "2026-11-02" -> "02/11 – 08/11".
String viWeekRange(String weekStart) {
  final d = DateTime.tryParse(weekStart);
  if (d == null) return weekStart;
  final end = DateTime(d.year, d.month, d.day + 6);
  return '${_dm(d)} – ${_dm(end)}';
}
