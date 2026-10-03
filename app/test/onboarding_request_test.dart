import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/onboarding/domain/models/onboarding_models.dart';

void main() {
  group('OnboardingState toOnboardingRequestJson conversion', () {
    test('chuyển OnboardingState thành JSON đúng tên trường và giá trị enum', () {
      const state = OnboardingState(
        displayName: 'Trần Văn Minh',
        goal: UserGoal.lose_fat,
        gender: Gender.male,
        birthYear: 1995,
        heightCm: 175,
        startWeightKg: 72,
        goalWeightKg: 68,
        experience: Experience.beginner,
        location: WorkoutLocation.home,
        equipment: [Equipment.dumbbell, Equipment.mat],
        injuries: [BodyArea.lower_back, BodyArea.knee],
        weekdays: [1, 3, 5],
        timeSlot: TimeSlot.early_morning,
        sessionMinutes: 15,
        motivationReasons: ['Tự tin hơn khi soi gương', 'Mặc vừa đồ cũ'],
        motivationText: 'Muốn cải thiện sức khỏe trước Tết',
        coachStyle: CoachStyle.supportive,
      );

      final json = state.toOnboardingRequestJson();

      // Kiểm tra tên trường
      expect(json['displayName'], 'Trần Văn Minh');
      expect(json['goal'], 'lose_fat');
      expect(json['gender'], 'male');
      expect(json['birthYear'], 1995);
      expect(json['heightCm'], 175.0);
      expect(json['weightKg'], 72.0); // lấy từ startWeightKg
      expect(json['goalWeightKg'], 68.0);
      expect(json['experience'], 'beginner');
      expect(json['location'], 'home');
      expect(json['sessionMinutes'], 15);
      expect(json['coachStyle'], 'supportive');
      expect(json['timezone'], 'Asia/Ho_Chi_Minh');

      // Kiểm tra enum equipment
      expect(json['equipment'], ['dumbbell', 'mat']);

      // Kiểm tra enum injuries
      expect(json['injuries'], ['lower_back', 'knee']);

      // Kiểm tra availability: mỗi ngày đã chọn kèm khung giờ
      expect(json['availability'], [
        {'weekday': 1, 'slot': 'early_morning'},
        {'weekday': 3, 'slot': 'early_morning'},
        {'weekday': 5, 'slot': 'early_morning'},
      ]);

      // Kiểm tra motivation
      expect(json['motivationReasons'],
          ['Tự tin hơn khi soi gương', 'Mặc vừa đồ cũ']);
      expect(json['motivationText'], 'Muốn cải thiện sức khỏe trước Tết');
    });

    test('displayName mặc định Minh nếu người dùng không nhập', () {
      const state = OnboardingState(
        goal: UserGoal.build_muscle,
        heightCm: 180,
        startWeightKg: 75,
        experience: Experience.regular,
        location: WorkoutLocation.gym,
        weekdays: [2, 4],
        timeSlot: TimeSlot.evening,
        sessionMinutes: 30,
        coachStyle: CoachStyle.strict,
      );

      final json = state.toOnboardingRequestJson();

      expect(json['displayName'], 'Minh');
      expect(json['goal'], 'build_muscle');
      expect(json['experience'], 'regular');
      expect(json['location'], 'gym');
      expect(json['coachStyle'], 'strict');
      expect(json['availability'], [
        {'weekday': 2, 'slot': 'evening'},
        {'weekday': 4, 'slot': 'evening'},
      ]);
    });
  });
}
