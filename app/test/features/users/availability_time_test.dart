import 'package:fitness_app/core/widgets/day_times_editor.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/domain/models/settings_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserAvailabilitySlot đọc/ghi giờ riêng, null thì không gửi', () {
    final withTime = UserAvailabilitySlot.fromJson({
      'weekday': 2,
      'slot': 'noon',
      'time': '12:45',
    });
    expect(withTime.time, '12:45');
    expect(withTime.toJson(), {'weekday': 2, 'slot': 'noon', 'time': '12:45'});

    final noTime = UserAvailabilitySlot.fromJson({
      'weekday': 4,
      'slot': 'evening',
      'time': null,
    });
    expect(noTime.time, isNull);
    expect(noTime.toJson(), {'weekday': 4, 'slot': 'evening'});

    final req = SettingsRequest(availability: [withTime, noTime]).toJson();
    expect(req['availability'], [
      {'weekday': 2, 'slot': 'noon', 'time': '12:45'},
      {'weekday': 4, 'slot': 'evening'},
    ]);
  });

  test('giờ mặc định theo khung và đọc HH:mm', () {
    expect(slotDefaultTime('early_morning'), '06:00');
    expect(slotDefaultTime('noon'), '12:00');
    expect(slotDefaultTime('evening'), '18:30');
    expect(slotDefaultTime('late_evening'), '20:30');
    expect(parseHhMm('07:05'), const TimeOfDay(hour: 7, minute: 5));
    expect(parseHhMm('24:00'), isNull);
    expect(parseHhMm('abc'), isNull);
    expect(formatHhMm(const TimeOfDay(hour: 6, minute: 0)), '06:00');
  });
}
