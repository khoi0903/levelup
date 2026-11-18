import 'package:fitness_app/features/body/domain/models/body_models.dart';
import 'package:fitness_app/features/onboarding/domain/coach_reactions.dart';
import 'package:fitness_app/features/onboarding/domain/models/onboarding_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goalReaction', () {
    test('mỗi mục tiêu có câu riêng, chưa chọn thì null', () {
      expect(goalReaction(null), isNull);
      expect(goalReaction(UserGoal.lose_fat)!.lead, 'Giảm mỡ bền vững.');
      expect(goalReaction(UserGoal.lose_fat)!.rest, contains('cardio nhẹ'));
      final all = UserGoal.values.map(goalReaction).toSet();
      expect(all.length, UserGoal.values.length);
    });
  });

  group('BMI', () {
    test('bmiCategoryFor dùng ngưỡng châu Á 18.5 / 23 / 25', () {
      expect(bmiCategoryFor(null), isNull);
      expect(bmiCategoryFor(18.4), 'underweight');
      expect(bmiCategoryFor(18.5), 'normal');
      expect(bmiCategoryFor(22.9), 'normal');
      expect(bmiCategoryFor(23), 'overweight');
      expect(bmiCategoryFor(24.9), 'overweight');
      expect(bmiCategoryFor(25), 'obese');
    });

    test('bmiReaction đổi theo nhóm', () {
      expect(bmiReaction(null), isNull);
      final lines = [17.0, 21.0, 24.0, 28.0].map(bmiReaction).toSet();
      expect(lines.length, 4);
      expect(bmiReaction(21)!.lead, 'Cân nặng đang rất ổn.');
    });
  });

  group('trainingReaction', () {
    const base = OnboardingState();

    test('chấn thương gối: tránh bài đè lên gối', () {
      final line = injuryReaction(const [BodyArea.knee])!;
      expect(line.rest, 'Mình sẽ tránh các bài đè lên gối.');
      expect(injuryReaction(const []), isNull);
      expect(
        injuryReaction(const [BodyArea.knee, BodyArea.wrist])!.lead,
        'Đã ghi nhận các chỗ đau.',
      );
    });

    test('đi theo mục vừa chạm, có dự phòng', () {
      final s = base.copyWith(
        experience: Experience.beginner,
        location: WorkoutLocation.home,
        injuries: const [BodyArea.knee],
      );
      expect(
        trainingReaction(s, last: TrainingField.experience),
        experienceReaction(Experience.beginner),
      );
      expect(
        trainingReaction(s, last: TrainingField.location)!.lead,
        'Tập tại nhà, không cần dụng cụ.',
      );
      // Không có mục vừa chạm: ưu tiên chấn thương.
      expect(trainingReaction(s)!.rest, contains('gối'));
      expect(trainingReaction(base), isNull);
    });

    test('nơi tập và dụng cụ', () {
      expect(
        locationReaction(WorkoutLocation.gym, const [])!.lead,
        'Tập ở phòng gym.',
      );
      expect(
        locationReaction(WorkoutLocation.home, const [
          Equipment.dumbbell,
        ])!.lead,
        'Có tạ đơn là tuyệt.',
      );
      expect(
        locationReaction(WorkoutLocation.home, const [Equipment.mat])!.lead,
        'Dụng cụ đã ghi nhận.',
      );
    });
  });

  group('scheduleReaction', () {
    test('số ngày 2/3/4/5+ có câu khác nhau', () {
      final lines = [2, 3, 4, 5, 6].map(daysReaction).toList();
      expect(lines.take(4).toSet().length, 4);
      expect(lines[3], lines[4]);
      expect(daysReaction(0), isNull);
    });

    test('thời lượng và khung giờ', () {
      expect(minutesReaction(null), isNull);
      expect({15, 20, 30, 45}.map(minutesReaction).toSet().length, 4);
      expect(TimeSlot.values.map(slotReaction).toSet().length, 4);
    });

    test('ưu tiên mục vừa chạm', () {
      final s = const OnboardingState().copyWith(
        weekdays: const [1, 3, 5],
        timeSlot: TimeSlot.evening,
        sessionMinutes: 20,
      );
      expect(scheduleReaction(s, last: ScheduleField.days), daysReaction(3));
      expect(
        scheduleReaction(s, last: ScheduleField.slot),
        slotReaction(TimeSlot.evening),
      );
      expect(scheduleReaction(s), minutesReaction(20));
    });
  });

  group('các bước khác', () {
    test('nhóm cơ', () {
      expect(focusReaction(const []), isNull);
      expect(focusReaction(const ['chest'])!.lead, 'Ưu tiên ngực.');
      expect(
        focusReaction(const ['chest', 'back', 'legs'])!.lead,
        'Ưu tiên ngực, lưng và chân.',
      );
      expect(
        focusReaction(const ['chest', 'back', 'legs', 'arms'])!.lead,
        'Tập toàn thân nhé.',
      );
      expect(focusReaction(const ['abs'])!.lead, contains('Bụng'));
    });

    test('vóc dáng, lý do, phong cách coach', () {
      expect(shapeReaction(null), isNull);
      expect(shapeReaction(20), isNotNull);
      expect(whyReaction(const [], ' '), isNull);
      expect(whyReaction(const ['x'], ''), isNotNull);
      expect(coachStyleReaction(null), isNull);
      expect(CoachStyle.values.map(coachStyleReaction).toSet().length, 3);
    });
  });

  group('giờ riêng từng ngày', () {
    test('chỉ gửi time cho ngày đã đổi, bỏ ngày thì xoá giờ', () {
      final c = OnboardingController();
      c.setDisplayName('Minh');
      c.selectGoal(UserGoal.lose_fat);
      c.updateBodyInfo(heightCm: 170, startWeightKg: 70);
      c.updateTraining(
        experience: Experience.beginner,
        location: WorkoutLocation.home,
      );
      c.toggleWeekday(1);
      c.toggleWeekday(3);
      c.toggleWeekday(5);
      c.setTimeSlot(TimeSlot.evening);
      c.setSessionMinutes(20);
      c.setCoachStyle(CoachStyle.supportive);
      c.setDayTime(3, '07:15');
      c.setDayTime(5, '19:00');
      c.toggleWeekday(5); // bỏ T6 thì giờ riêng của T6 cũng mất
      c.updateBodyInfo(heightCm: 171, startWeightKg: 70); // giữ giờ riêng

      final json = c.state.toOnboardingRequestJson();
      expect(json['availability'], [
        {'weekday': 1, 'slot': 'evening'},
        {'weekday': 3, 'slot': 'evening', 'time': '07:15'},
      ]);

      c.setDayTime(3, null);
      expect(c.state.dayTimes, isEmpty);
    });
  });
}
