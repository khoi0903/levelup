import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/core/utils/date_labels.dart';

void main() {
  test('viDayLabel đổi YYYY-MM-DD thành thứ và ngày/tháng', () {
    expect(viDayLabel('2026-11-13'), 'Thứ Sáu, 13/11');
    expect(viDayLabel('2026-11-15'), 'Chủ nhật, 15/11');
    expect(viDayLabel('sai'), 'sai');
  });

  test('viWeekRange hiện khoảng Thứ Hai đến Chủ nhật, qua tháng', () {
    expect(viWeekRange('2026-11-02'), '02/11 – 08/11');
    expect(viWeekRange('2026-10-26'), '26/10 – 01/11');
  });
}
