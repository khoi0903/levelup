import '../../body/domain/models/body_models.dart';
import 'models/onboarding_models.dart';

/// Một câu phản hồi ngắn của coach trong lúc onboarding:
/// [lead] in đậm, [rest] chữ thường ngay sau.
/// Câu cố định theo lựa chọn, không gọi AI.
class CoachLine {
  const CoachLine(this.lead, this.rest);

  final String lead;
  final String rest;

  String get text => '$lead $rest';

  @override
  bool operator ==(Object other) =>
      other is CoachLine && other.lead == lead && other.rest == rest;

  @override
  int get hashCode => Object.hash(lead, rest);

  @override
  String toString() => text;
}

CoachLine? goalReaction(UserGoal? goal) => switch (goal) {
  null => null,
  UserGoal.lose_fat => const CoachLine(
    'Giảm mỡ bền vững.',
    'Mình sẽ giữ calo vừa phải và thêm cardio nhẹ để bạn không bị đói.',
  ),
  UserGoal.build_muscle => const CoachLine(
    'Tăng cơ chắc chắn.',
    'Mình sẽ tăng dần độ khó từng tuần và nhắc bạn ăn đủ đạm.',
  ),
  UserGoal.get_healthier => const CoachLine(
    'Khỏe hơn mỗi ngày.',
    'Mình sẽ xếp bài nhẹ nhàng, đều đặn để bạn thấy khác biệt sau vài tuần.',
  ),
  UserGoal.maintain => const CoachLine(
    'Giữ phong độ.',
    'Mình sẽ giữ lịch đều và đổi bài thường xuyên để bạn không chán.',
  ),
};

/// Câu theo nhóm BMI (ngưỡng châu Á, dùng chung [bmiCategoryFor]).
CoachLine? bmiReaction(double? bmi) => switch (bmiCategoryFor(bmi)) {
  'underweight' => const CoachLine(
    'Mình sẽ giúp bạn lên cân khỏe.',
    'Ưu tiên bài sức mạnh và ăn đủ calo, không cần cardio nhiều.',
  ),
  'normal' => const CoachLine(
    'Cân nặng đang rất ổn.',
    'Mình sẽ tập trung giúp bạn săn chắc và khỏe hơn.',
  ),
  'overweight' => const CoachLine(
    'Chỉ nhỉnh hơn khoảng chuẩn một chút.',
    'Tập đều vài tuần là thấy khác ngay.',
  ),
  'obese' => const CoachLine(
    'Mình sẽ đi từng bước nhẹ nhàng.',
    'Bài ít va đập để bảo vệ khớp, mỗi tuần tiến thêm một chút.',
  ),
  _ => null,
};

CoachLine? shapeReaction(int? bodyFatPct) => bodyFatPct == null
    ? null
    : const CoachLine(
        'Cảm ơn bạn!',
        'Mình dùng vóc dáng này để ước tính calo và chỉ số sát với bạn hơn.',
      );

const Map<String, String> _muscleNames = {
  'chest': 'ngực',
  'back': 'lưng',
  'shoulders': 'vai',
  'arms': 'tay',
  'abs': 'bụng',
  'glutes': 'mông',
  'legs': 'chân',
};

CoachLine? focusReaction(List<String> muscles) {
  if (muscles.isEmpty) return null;
  if (muscles.length >= 4) {
    return const CoachLine(
      'Tập toàn thân nhé.',
      'Mình sẽ chia đều các nhóm cơ trong tuần để không nhóm nào quá tải.',
    );
  }
  final names = muscles.map((m) => _muscleNames[m] ?? m).toList();
  final joined = names.length == 1
      ? names.first
      : '${names.sublist(0, names.length - 1).join(', ')} và ${names.last}';
  if (muscles.length == 1 && muscles.first == 'abs') {
    return const CoachLine(
      'Bụng gọn cần cả tập lẫn ăn.',
      'Mình sẽ thêm bài core mỗi buổi và nhắc bạn giữ calo hợp lý.',
    );
  }
  return CoachLine(
    'Ưu tiên $joined.',
    'Mỗi buổi sẽ có ít nhất một bài cho nhóm cơ này.',
  );
}

/// Mục vừa chạm ở màn "Tập luyện", để câu coach đi theo đúng mục đó.
enum TrainingField { experience, location, equipment, injuries }

const Map<BodyArea, String> _areaNames = {
  BodyArea.lower_back: 'lưng dưới',
  BodyArea.knee: 'gối',
  BodyArea.shoulder: 'vai',
  BodyArea.neck: 'cổ',
  BodyArea.wrist: 'cổ tay',
  BodyArea.ankle: 'cổ chân',
  BodyArea.hip: 'hông',
  BodyArea.other: 'chỗ đau',
};

CoachLine? experienceReaction(Experience? e) => switch (e) {
  null => null,
  Experience.beginner => const CoachLine(
    'Bắt đầu từ cơ bản.',
    'Mỗi bài có video mẫu và mình đếm số lần giúp bạn.',
  ),
  Experience.intermediate => const CoachLine(
    'Bạn đã có nền rồi.',
    'Mình sẽ thêm biến thể khó hơn khi bạn sẵn sàng.',
  ),
  Experience.regular => const CoachLine(
    'Dân tập lâu năm!',
    'Mình sẽ tăng khối lượng tập và theo dõi kỷ lục cho bạn.',
  ),
};

CoachLine? locationReaction(
  WorkoutLocation? location,
  List<Equipment> equipment,
) {
  if (location == null) return null;
  if (location == WorkoutLocation.gym) {
    return const CoachLine(
      'Tập ở phòng gym.',
      'Mình sẽ dùng máy và tạ có sẵn, bài nào cũng có hướng dẫn.',
    );
  }
  if (equipment.isEmpty) {
    return location == WorkoutLocation.outdoor
        ? const CoachLine(
            'Tập ngoài trời.',
            'Toàn bài không cần dụng cụ, chỉ cần một khoảng trống nhỏ.',
          )
        : const CoachLine(
            'Tập tại nhà, không cần dụng cụ.',
            'Mình chọn bài dùng sức nặng cơ thể là đủ hiệu quả.',
          );
  }
  if (equipment.contains(Equipment.dumbbell)) {
    return const CoachLine(
      'Có tạ đơn là tuyệt.',
      'Mình sẽ thêm bài với tạ để bạn tăng sức mạnh nhanh hơn.',
    );
  }
  return const CoachLine(
    'Dụng cụ đã ghi nhận.',
    'Mình sẽ xen bài dùng dụng cụ của bạn vào lịch tập.',
  );
}

CoachLine? injuryReaction(List<BodyArea> injuries) {
  if (injuries.isEmpty) return null;
  if (injuries.length == 1) {
    final name = _areaNames[injuries.first]!;
    final line = injuries.first == BodyArea.other
        ? 'Mình sẽ chọn bài nhẹ và nhắc bạn dừng khi thấy đau.'
        : 'Mình sẽ tránh các bài đè lên $name.';
    return CoachLine('Đã ghi nhận $name.', line);
  }
  return const CoachLine(
    'Đã ghi nhận các chỗ đau.',
    'Mình sẽ tránh bài đè lên những vùng này và nhắc bạn khởi động kỹ.',
  );
}

/// Câu cho màn "Tập luyện": ưu tiên mục vừa chạm, nếu mục đó chưa có
/// câu thì lấy theo thứ tự chấn thương, nơi tập, kinh nghiệm.
CoachLine? trainingReaction(OnboardingState s, {TrainingField? last}) {
  CoachLine? of(TrainingField f) => switch (f) {
    TrainingField.experience => experienceReaction(s.experience),
    TrainingField.location ||
    TrainingField.equipment => locationReaction(s.location, s.equipment),
    TrainingField.injuries => injuryReaction(s.injuries),
  };
  if (last != null) {
    final line = of(last);
    if (line != null) return line;
  }
  return injuryReaction(s.injuries) ??
      locationReaction(s.location, s.equipment) ??
      experienceReaction(s.experience);
}

CoachLine? daysReaction(int days) {
  if (days <= 0) return null;
  if (days == 1) {
    return const CoachLine(
      'Một buổi cũng là khởi đầu.',
      'Khi quen rồi mình sẽ gợi ý thêm buổi thứ hai.',
    );
  }
  if (days == 2) {
    return const CoachLine(
      '2 buổi một tuần là vừa sức.',
      'Mỗi buổi mình sẽ tập toàn thân để không bỏ sót nhóm cơ nào.',
    );
  }
  if (days == 3) {
    return const CoachLine(
      '3 buổi là nhịp lý tưởng.',
      'Đủ để thấy tiến bộ mà vẫn có ngày nghỉ hồi phục.',
    );
  }
  if (days == 4) {
    return const CoachLine(
      '4 buổi, rất quyết tâm!',
      'Mình sẽ chia buổi thân trên và thân dưới xen kẽ.',
    );
  }
  return const CoachLine(
    'Lịch dày đấy!',
    'Mình sẽ xếp ngày tập nhẹ xen giữa để bạn không bị quá sức.',
  );
}

CoachLine? slotReaction(TimeSlot? slot) => switch (slot) {
  null => null,
  TimeSlot.early_morning => const CoachLine(
    'Tập sáng sớm.',
    'Mình sẽ nhắc trước giờ tập và chọn bài khởi động kỹ hơn.',
  ),
  TimeSlot.noon => const CoachLine(
    'Tập buổi trưa.',
    'Mình sẽ ưu tiên bài gọn để bạn kịp nghỉ ngơi.',
  ),
  TimeSlot.evening => const CoachLine(
    'Tập buổi tối.',
    'Khung giờ phổ biến nhất, mình sẽ nhắc ngay khi bạn tan làm.',
  ),
  TimeSlot.late_evening => const CoachLine(
    'Tập tối muộn.',
    'Mình sẽ tránh bài quá mạnh để bạn vẫn ngủ ngon.',
  ),
};

CoachLine? minutesReaction(int? minutes) {
  if (minutes == null) return null;
  if (minutes <= 15) {
    return const CoachLine(
      'Ngắn mà chất.',
      'Bài 10–15 phút dễ duy trì nhất, bận mấy cũng tập được.',
    );
  }
  if (minutes <= 20) {
    return const CoachLine(
      '20 phút là vừa đẹp.',
      'Đủ khởi động, tập chính và giãn cơ.',
    );
  }
  if (minutes <= 30) {
    return const CoachLine(
      '30 phút mỗi buổi.',
      'Mình sẽ thêm hiệp để bạn tiến bộ nhanh hơn.',
    );
  }
  return const CoachLine(
    'Buổi tập dài.',
    'Mình sẽ chia rõ phần sức mạnh và cardio để bạn không đuối sức.',
  );
}

/// Mục vừa chạm ở màn "Lịch tập".
enum ScheduleField { days, slot, minutes }

CoachLine? scheduleReaction(OnboardingState s, {ScheduleField? last}) {
  CoachLine? of(ScheduleField f) => switch (f) {
    ScheduleField.days => daysReaction(s.weekdays.length),
    ScheduleField.slot => slotReaction(s.timeSlot),
    ScheduleField.minutes => minutesReaction(s.sessionMinutes),
  };
  if (last != null) {
    final line = of(last);
    if (line != null) return line;
  }
  return minutesReaction(s.sessionMinutes) ??
      slotReaction(s.timeSlot) ??
      daysReaction(s.weekdays.length);
}

CoachLine? whyReaction(List<String> reasons, String text) {
  if (reasons.isEmpty && text.trim().isEmpty) return null;
  return const CoachLine(
    'Mình sẽ nhắc lại lý do này',
    'vào những hôm bạn thấy uể oải.',
  );
}

CoachLine? coachStyleReaction(CoachStyle? style) => switch (style) {
  null => null,
  CoachStyle.strict => const CoachLine(
    'Được, mình sẽ nghiêm.',
    'Bỏ buổi là mình nhắc thẳng, không nương tay đâu.',
  ),
  CoachStyle.supportive => const CoachLine(
    'Mình luôn ở đây.',
    'Hôm nào mệt cứ nói, mình sẽ gợi ý bài nhẹ hơn.',
  ),
  CoachStyle.funny => const CoachLine(
    'Chơi vui mà tập thật!',
    'Chuẩn bị nghe mình chọc vài câu mỗi khi bạn lười nhé.',
  ),
};
