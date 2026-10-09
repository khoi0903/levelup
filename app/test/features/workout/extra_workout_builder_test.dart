import 'package:fitness_app/features/workout/domain/models/exercise_response.dart';
import 'package:fitness_app/features/workout/domain/models/extra_workout_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtraWorkoutBuilder - filterExercisesForUser', () {
    const activePushup = ExerciseResponse(
      id: 'ex-pushup',
      slug: 'push-up',
      nameVi: 'Hít đất',
      primaryMuscle: 'chest',
      difficulty: 2,
      tracking: 'reps',
      equipment: [],
      contraindications: ['wrist', 'shoulder'],
      isActive: true,
    );

    const inactiveSquat = ExerciseResponse(
      id: 'ex-squat-inactive',
      slug: 'squat',
      nameVi: 'Squat',
      primaryMuscle: 'legs',
      difficulty: 3,
      tracking: 'reps',
      equipment: [],
      contraindications: ['knee'],
      isActive: false, // inactive!
    );

    const pullupWithBar = ExerciseResponse(
      id: 'ex-pullup',
      slug: 'pull-up',
      nameVi: 'Kéo xà đơn',
      primaryMuscle: 'back',
      difficulty: 4,
      tracking: 'reps',
      equipment: ['pullup_bar'],
      contraindications: ['shoulder'],
      isActive: true,
    );

    const plankWithMat = ExerciseResponse(
      id: 'ex-plank',
      slug: 'plank',
      nameVi: 'Plank',
      primaryMuscle: 'core',
      difficulty: 2,
      tracking: 'duration',
      equipment: ['mat'], // mat is optional
      contraindications: ['lower_back'],
      isActive: true,
    );

    const dumbbellLunge = ExerciseResponse(
      id: 'ex-lunge',
      slug: 'dumbbell-lunge',
      nameVi: 'Lunge với tạ',
      primaryMuscle: 'legs',
      difficulty: 3,
      tracking: 'reps_weight',
      equipment: ['dumbbell'],
      contraindications: ['knee'],
      isActive: true,
    );

    final all = [
      activePushup,
      inactiveSquat,
      pullupWithBar,
      plankWithMat,
      dumbbellLunge,
    ];

    test('Bỏ bài isActive == false', () {
      final res = filterExercisesForUser(exercises: all);
      expect(res.any((e) => e.id == 'ex-squat-inactive'), isFalse);
    });

    test('Bỏ bài có contraindications trùng chấn thương đang đau', () {
      final res = filterExercisesForUser(
        exercises: all,
        activeInjuries: ['wrist'],
      );
      // Hít đất có contraindication: wrist -> phải bị loại
      expect(res.any((e) => e.id == 'ex-pushup'), isFalse);
      // Plank không có wrist -> được giữ
      expect(res.any((e) => e.id == 'ex-plank'), isTrue);
    });

    test('Tập ở gym: coi như có đủ dụng cụ (dumbbell, pullup_bar)', () {
      final res = filterExercisesForUser(
        exercises: all,
        location: 'gym',
        userEquipment: [], // dù không khai báo dụng cụ ở nhà
      );
      expect(res.any((e) => e.id == 'ex-pullup'), isTrue);
      expect(res.any((e) => e.id == 'ex-lunge'), isTrue);
    });

    test('Tập ở home: chỉ bài không cần dụng cụ hoặc dụng cụ có sẵn; thảm (mat) là tùy chọn', () {
      final resWithoutDumbbell = filterExercisesForUser(
        exercises: all,
        location: 'home',
        userEquipment: ['pullup_bar'],
      );
      expect(resWithoutDumbbell.any((e) => e.id == 'ex-pullup'), isTrue);
      expect(resWithoutDumbbell.any((e) => e.id == 'ex-lunge'), isFalse);
      // mat không bắt buộc -> plank vẫn được giữ dù không có mat
      expect(resWithoutDumbbell.any((e) => e.id == 'ex-plank'), isTrue);
    });
  });

  group('ExtraWorkoutBuilder - buildSuggestedExercises', () {
    final mockLibrary = [
      const ExerciseResponse(
        id: 'c1',
        slug: 'jumping-jack',
        nameVi: 'Bật nhảy',
        primaryMuscle: 'cardio',
        difficulty: 2,
        tracking: 'reps',
      ),
      const ExerciseResponse(
        id: 'l1',
        slug: 'squat',
        nameVi: 'Squat',
        primaryMuscle: 'legs',
        difficulty: 3,
        tracking: 'reps',
      ),
      const ExerciseResponse(
        id: 'l2',
        slug: 'lunge',
        nameVi: 'Lunge',
        primaryMuscle: 'legs',
        difficulty: 3,
        tracking: 'reps',
      ),
      const ExerciseResponse(
        id: 'g1',
        slug: 'glute-bridge',
        nameVi: 'Cầu mông',
        primaryMuscle: 'glutes',
        difficulty: 2,
        tracking: 'reps',
      ),
      const ExerciseResponse(
        id: 'ch1',
        slug: 'push-up',
        nameVi: 'Hít đất',
        primaryMuscle: 'chest',
        difficulty: 3,
        tracking: 'reps',
      ),
      const ExerciseResponse(
        id: 'sh1',
        slug: 'pike-push-up',
        nameVi: 'Chống đẩy Pike',
        primaryMuscle: 'shoulders',
        difficulty: 4,
        tracking: 'reps',
      ),
      const ExerciseResponse(
        id: 'bk1',
        slug: 'pull-up',
        nameVi: 'Kéo xà',
        primaryMuscle: 'back',
        difficulty: 4,
        tracking: 'reps',
      ),
      const ExerciseResponse(
        id: 'ar1',
        slug: 'chair-dip',
        nameVi: 'Dip ghế',
        primaryMuscle: 'arms',
        difficulty: 2,
        tracking: 'reps',
      ),
      const ExerciseResponse(
        id: 'cr1',
        slug: 'plank',
        nameVi: 'Plank',
        primaryMuscle: 'core',
        difficulty: 2,
        tracking: 'duration',
      ),
      const ExerciseResponse(
        id: 'cr2',
        slug: 'crunch',
        nameVi: 'Gập bụng',
        primaryMuscle: 'core',
        difficulty: 2,
        tracking: 'reps',
      ),
    ];

    test('quick5 tạo 3 bài tập nhanh, mỗi bài 2 hiệp', () {
      final items = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.quick5,
      );
      expect(items.length, 3);
      for (final item in items) {
        expect(item.sets, 2);
        expect(item.restSec, 20);
      }
    });

    test('isLowCheckin == true: bớt 1 hiệp mỗi bài (tối thiểu 1) và ưu tiên bài difficulty thấp', () {
      final itemsNormal = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.quick5,
        isLowCheckin: false,
      );
      for (final item in itemsNormal) {
        expect(item.sets, 2);
      }

      final itemsLow = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.quick5,
        isLowCheckin: true,
      );
      for (final item in itemsLow) {
        expect(item.sets, 1);
      }

      final fullBodyLow = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.fullBody,
        isLowCheckin: true,
      );
      for (final item in fullBodyLow) {
        expect(item.sets, inInclusiveRange(1, 2));
      }
    });

    test('legsGlutes tạo 3-5 bài chỉ thuộc legs hoặc glutes', () {
      final items = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.legsGlutes,
      );
      expect(items.length, inInclusiveRange(3, 5));
      for (final item in items) {
        expect(
          item.exercise!.primaryMuscle == 'legs' ||
              item.exercise!.primaryMuscle == 'glutes',
          isTrue,
        );
        expect(item.sets, inInclusiveRange(2, 3));
      }
    });

    test('armsShoulders tạo 3-5 bài thuộc tay & vai & ngực', () {
      final items = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.armsShoulders,
      );
      expect(items.length, inInclusiveRange(3, 5));
      final validMuscles = {'arms', 'shoulders', 'chest', 'back'};
      for (final item in items) {
        expect(validMuscles.contains(item.exercise!.primaryMuscle), isTrue);
      }
    });

    test('coreAbs tạo 3-5 bài bụng (core)', () {
      final items = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.coreAbs,
      );
      expect(items.length, inInclusiveRange(3, 5));
      // Ít nhất 2 bài core trong mockLibrary được chọn đầu tiên
      expect(items.first.exercise!.primaryMuscle, 'core');
    });

    test('fullBody tạo 3-5 bài kết hợp đa dạng nhóm cơ', () {
      final items = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.fullBody,
      );
      expect(items.length, inInclusiveRange(3, 5));
      final muscles = items.map((i) => i.exercise!.primaryMuscle).toSet();
      expect(muscles.length, greaterThanOrEqualTo(3));
    });

    test('Tính số lần theo difficulty cho bài reps và giây cho duration', () {
      final items = buildSuggestedExercises(
        exercises: mockLibrary,
        type: SuggestedWorkoutType.fullBody,
      );
      for (final item in items) {
        if (item.exercise!.tracking == 'duration') {
          expect(item.durationSec, isNotNull);
          expect(item.reps, isNull);
        } else {
          expect(item.reps, isNotNull);
          expect(item.durationSec, isNull);
        }
      }
    });
  });

  group('ExtraWorkoutBuilder - removeVietnameseDiacritics', () {
    test('Xóa dấu tiếng Việt chính xác để tìm kiếm', () {
      expect(removeVietnameseDiacritics('Hít đất'), 'hit dat');
      expect(removeVietnameseDiacritics('Gập bụng'), 'gap bung');
      expect(removeVietnameseDiacritics('Đá lừa'), 'da lua');
      expect(removeVietnameseDiacritics('Kéo xà đơn'), 'keo xa don');
      expect(removeVietnameseDiacritics('Chống đẩy bắp tay sau'), 'chong day bap tay sau');
    });
  });
}
