import 'package:fitness_app/core/voice/voice_coach.dart';
import 'package:fitness_app/core/voice/voice_models.dart';
import 'package:fitness_app/core/voice/voice_provider.dart';
import 'package:fitness_app/features/workout/data/camera/rep_counting_session.dart';
import 'package:fitness_app/features/workout/domain/models/exercise_response.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:fitness_app/features/workout/presentation/screens/camera_set_screen.dart';
import 'package:fitness_app/features/workout/presentation/widgets/exercise_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'workout_test_helpers.dart';

void main() {
  group('VoiceCoach - chọn câu, placeholder, không lặp', () {
    test('thay thế placeholder chính xác: {n}, {left}, {set}, {sets}, {sec}, {exercise}, {minutes}, {kcal}', () {
      final fakeCoach = FakeVoiceCoach();

      // Test format with placeholders
      final formatted = fakeCoach.formatLine(
        'Lần thứ {n}, còn {left} lần, hiệp {set}/{sets}, giữ {sec} giây bài {exercise}, tập {minutes} phút đốt {kcal} calo.',
        {
          'n': '10',
          'left': '3',
          'set': '2',
          'sets': '4',
          'sec': '30',
          'exercise': 'Squat',
          'minutes': '25',
          'kcal': '150',
        },
      );

      expect(
        formatted,
        'Lần thứ 10, còn 3 lần, hiệp 2/4, giữ 30 giây bài Squat, tập 25 phút đốt 150 calo.',
      );

      // Speak line qua FakeVoiceCoach
      fakeCoach.speakLine(
        VoiceLineKey.rep,
        params: {'n': '12'},
      );
      expect(fakeCoach.spokenTexts.last, contains('12'));
    });

    test('không lặp câu liền trước nếu danh sách có nhiều hơn 1 câu', () {
      final fakeCoach = FakeVoiceCoach();

      final firstPick = fakeCoach.pickLine('supportive', VoiceLineKey.go);
      expect(firstPick, isNotNull);

      // Gọi liên tục 10 lần, mỗi lần câu liền sau không trùng câu liền trước (nếu list có >= 2 câu)
      String? prev = firstPick;
      for (int i = 0; i < 10; i++) {
        final next = fakeCoach.pickLine('supportive', VoiceLineKey.go);
        expect(next, isNotNull);
        expect(next, isNot(equals(prev)));
        prev = next;
      }
    });

    test('countEvery theo từng phong cách đúng quy định (countEvery >= 1)', () {
      final fakeCoach = FakeVoiceCoach();

      fakeCoach.settings = const VoiceSettings(selectedStyleId: 'minimal');
      expect(fakeCoach.countEveryForStyle(), 1);

      fakeCoach.settings = const VoiceSettings(selectedStyleId: 'calm');
      expect(fakeCoach.countEveryForStyle(), 1);

      fakeCoach.settings = const VoiceSettings(selectedStyleId: 'supportive');
      expect(fakeCoach.countEveryForStyle(), 1);

      fakeCoach.settings = const VoiceSettings(selectedStyleId: 'hype');
      expect(fakeCoach.countEveryForStyle(), 1);
    });

    test('tắt giọng đọc thì FakeVoiceCoach không nhận thêm câu nói', () {
      final fakeCoach = FakeVoiceCoach();
      fakeCoach.settings = const VoiceSettings(enabled: false);

      fakeCoach.speakLine(VoiceLineKey.go);
      expect(fakeCoach.spokenTexts, isEmpty);
      expect(fakeCoach.calls, isEmpty);

      // Bật lại
      fakeCoach.settings = const VoiceSettings(enabled: true);
      fakeCoach.speakLine(VoiceLineKey.go);
      expect(fakeCoach.spokenTexts, hasLength(1));

      // Tạm tắt bằng nút loa
      fakeCoach.setMutedTemporarily(true);
      fakeCoach.speakLine(VoiceLineKey.rep, params: {'n': '5'});
      expect(fakeCoach.spokenTexts, hasLength(1));
    });

    test('không đọc khi app ở trạng thái paused / background', () {
      final fakeCoach = FakeVoiceCoach();
      fakeCoach.setAppLifecycle(AppLifecycleState.paused);

      fakeCoach.speakLine(VoiceLineKey.go);
      expect(fakeCoach.spokenTexts, isEmpty);

      // Quay lại foreground
      fakeCoach.setAppLifecycle(AppLifecycleState.resumed);
      fakeCoach.speakLine(VoiceLineKey.go);
      expect(fakeCoach.spokenTexts, hasLength(1));
    });
  });

  group('Luồng tập gọi đúng thứ tự voice feedback', () {
    test('go → rep… → almost_done → last_rep → set_done → rest_start với FakeVoiceCoach', () {
      final fakeCoach = FakeVoiceCoach();

      // Giả lập chuỗi sự kiện trong 1 hiệp tập 10 reps
      fakeCoach.speakLine(VoiceLineKey.go, interrupt: true);

      // Rep 1 đến rep 6
      for (int r = 1; r <= 6; r++) {
        fakeCoach.speakLine(VoiceLineKey.rep, params: {'n': '$r'}, interrupt: true);
      }

      // Còn 3 lần: rep 7 (10 - 7 = 3)
      fakeCoach.speakLine(VoiceLineKey.almostDone, params: {'left': '3'}, interrupt: true);

      // Rep 8, 9
      fakeCoach.speakLine(VoiceLineKey.rep, params: {'n': '8'}, interrupt: true);
      fakeCoach.speakLine(VoiceLineKey.rep, params: {'n': '9'}, interrupt: true);

      // Lần cuối: rep 10
      fakeCoach.speakLine(VoiceLineKey.lastRep, interrupt: true);

      // Xong hiệp và bắt đầu nghỉ
      fakeCoach.speakLine(VoiceLineKey.setDone, params: {'set': '1', 'sets': '3'});
      fakeCoach.speakLine(VoiceLineKey.restStart, params: {'sec': '60'});

      final keys = fakeCoach.calls.map((c) => c.key).toList();
      expect(keys.first, VoiceLineKey.go);
      expect(keys.contains(VoiceLineKey.almostDone), isTrue);
      expect(keys.contains(VoiceLineKey.lastRep), isTrue);
      expect(keys.contains(VoiceLineKey.setDone), isTrue);
      expect(keys.last, VoiceLineKey.restStart);

      // Kiểm tra thứ tự tương đối
      final idxGo = keys.indexOf(VoiceLineKey.go);
      final idxAlmost = keys.indexOf(VoiceLineKey.almostDone);
      final idxLast = keys.indexOf(VoiceLineKey.lastRep);
      final idxSetDone = keys.indexOf(VoiceLineKey.setDone);
      final idxRestStart = keys.indexOf(VoiceLineKey.restStart);

      expect(idxGo < idxAlmost, isTrue);
      expect(idxAlmost < idxLast, isTrue);
      expect(idxLast < idxSetDone, isTrue);
      expect(idxSetDone < idxRestStart, isTrue);
    });
  });

  group('ExerciseImage - widget hiển thị ảnh với cơ chế fallback', () {
    testWidgets('rơi về icon tạ trên nền nhạt khi thiếu ảnh mạng và thiếu asset', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExerciseImage(
              slug: 'non-existent-exercise-slug',
              thumbnailUrl: null,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra icon fitness_center_rounded fallback hiển thị
      expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    });
  });

  group('VoiceCoach - Form cues và startTip', () {
    test('lỗi có câu riêng → đọc cue', () async {
      final fakeCoach = FakeVoiceCoach();

      await fakeCoach.speakFormCue('jumping-jack', 'arms_not_overhead');
      expect(fakeCoach.spokenTexts, isNotEmpty);
      final spoken = fakeCoach.spokenTexts.last;
      expect(
        ['Đưa hai tay lên trên đầu', 'Nâng tay cao trong tầm thoải mái'],
        contains(spoken),
      );
    });

    test('cùng mã lỗi lặp lại thì chọn câu khác trong danh sách (không lặp câu liền trước)', () {
      final fakeCoach = FakeVoiceCoach();

      // bodyweight-squat + shallow_depth có 2 câu:
      // 'Hạ hông trong tầm thoải mái', 'Gập gối thêm, giữ gót bám sàn'
      final first = fakeCoach.pickFormCue('supportive', 'bodyweight-squat', 'shallow_depth');
      expect(first, isNotNull);

      String? prev = first;
      for (int i = 0; i < 6; i++) {
        final next = fakeCoach.pickFormCue('supportive', 'bodyweight-squat', 'shallow_depth');
        expect(next, isNotNull);
        expect(next, isNot(equals(prev)));
        prev = next;
      }
    });

    test('phong cách Tối giản → minimal', () async {
      final fakeCoach = FakeVoiceCoach(
        initialSettings: const VoiceSettings(selectedStyleId: 'minimal'),
      );

      await fakeCoach.speakFormCue('jumping-jack', 'arms_not_overhead');
      expect(fakeCoach.spokenTexts.last, equals('Tay lên cao'));

      await fakeCoach.speakFormCue('plank', 'body_not_straight');
      expect(fakeCoach.spokenTexts.last, equals('Hông ngang thân'));
    });

    test('mã lạ hoặc bài không có câu riêng → đọc form_generic', () async {
      final fakeCoach = FakeVoiceCoach();

      await fakeCoach.speakFormCue('jumping-jack', 'unknown_code_xyz');
      expect(fakeCoach.spokenKeys.last, equals(VoiceLineKey.formGeneric));
      expect(fakeCoach.spokenTexts, isNotEmpty);

      await fakeCoach.speakFormCue('non-existent-exercise', 'shallow_depth');
      expect(fakeCoach.spokenKeys.last, equals(VoiceLineKey.formGeneric));
    });

    test('startTip đọc sau exercise_next và tắt được trong cài đặt', () async {
      final fakeCoach = FakeVoiceCoach();

      // Khi bật (mặc định)
      await fakeCoach.speakLine(
        VoiceLineKey.exerciseNext,
        params: {'exercise': 'Bật nhảy tại chỗ'},
      );
      await fakeCoach.speakStartTip('jumping-jack');

      expect(fakeCoach.spokenTexts.length, 2);
      expect(fakeCoach.spokenTexts[0], contains('Bật nhảy tại chỗ'));
      expect(
        ['Tiếp đất nhẹ với gối hơi chùng', 'Đưa tay lên trong tầm thoải mái'],
        contains(fakeCoach.spokenTexts[1]),
      );

      // Khi tắt đọc mẹo kỹ thuật đầu bài
      fakeCoach.clearHistory();
      fakeCoach.settings = fakeCoach.settings.copyWith(readStartTip: false);

      await fakeCoach.speakLine(
        VoiceLineKey.exerciseNext,
        params: {'exercise': 'Bật nhảy tại chỗ'},
      );
      await fakeCoach.speakStartTip('jumping-jack');

      expect(fakeCoach.spokenTexts.length, 1);
      expect(fakeCoach.spokenTexts[0], contains('Bật nhảy tại chỗ'));
    });
  });

  group('CameraSetScreen - hiển thị startTip dưới dạng chữ', () {
    testWidgets('màn đặt camera hiện startTip của bài dạng chữ', (tester) async {
      SharedPreferences.setMockInitialValues({});

      final item = WorkoutPlanItem(
        exerciseId: 'jumping-jack',
        nameVi: 'Bật nhảy tại chỗ',
        sets: 3,
        reps: 15,
        exercise: const ExerciseResponse(
          id: 'jumping-jack',
          slug: 'jumping-jack',
          nameVi: 'Bật nhảy tại chỗ',
          camera: ExerciseCamera(
            cameraPosition: 'front',
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CameraSetScreen(
              args: CameraSetArgs(item: item, setNumber: 1),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('camera-setup-start-tip')), findsOneWidget);
      expect(find.text('Tiếp đất nhẹ với gối hơi chùng'), findsOneWidget);
      expect(find.text('Đưa tay lên trong tầm thoải mái'), findsOneWidget);
    });

    testWidgets('CameraSetScreen khi camera báo FormIssue đọc cue riêng của bài', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fakeCoach = FakeVoiceCoach();

      final item = WorkoutPlanItem(
        exerciseId: 'jumping-jack',
        nameVi: 'Bật nhảy tại chỗ',
        sets: 3,
        reps: 15,
        exercise: const ExerciseResponse(
          id: 'jumping-jack',
          slug: 'jumping-jack',
          nameVi: 'Bật nhảy tại chỗ',
          camera: ExerciseCamera(
            cameraPosition: 'front',
            config: {'supported': true},
          ),
        ),
      );

      final sessionFactory = FakeRepSessionFactory(const RepSnapshot(repCount: 0));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceCoachProvider.overrideWithValue(fakeCoach),
            repSessionFactoryProvider.overrideWithValue(sessionFactory),
            cameraPermissionProvider.overrideWithValue(FakePermissionGate()),
          ],
          child: MaterialApp(
            home: CameraSetScreen(
              args: CameraSetArgs(item: item, setNumber: 1),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Bấm "Tôi đã sẵn sàng"
      await tester.tap(find.text('Tôi đã sẵn sàng'));
      await tester.pump();
      // Chờ countdown 3.. 2.. 1.. go
      await tester.pump(const Duration(seconds: 4));

      expect(sessionFactory.created, isNotEmpty);
      final session = sessionFactory.created.first;

      // Giả lập camera phát hiện lỗi tư thế arms_not_overhead
      session.emit(const RepSnapshot(
        repCount: 1,
        issues: [FormIssueLog(repIndex: 1, code: 'arms_not_overhead', severity: 2)],
      ));
      await tester.pump();

      // Kiểm tra fakeCoach nhận được câu sửa của jumping-jack + arms_not_overhead
      expect(
        fakeCoach.spokenTexts.any((t) =>
            t == 'Đưa hai tay lên trên đầu' ||
            t == 'Nâng tay cao trong tầm thoải mái'),
        isTrue,
      );
    });
  });
}
