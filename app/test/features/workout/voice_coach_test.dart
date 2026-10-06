import 'package:fitness_app/core/voice/voice_coach.dart';
import 'package:fitness_app/core/voice/voice_models.dart';
import 'package:fitness_app/features/workout/presentation/widgets/exercise_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
