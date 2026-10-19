import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/workout/data/camera/rep_counting_session.dart';
import 'package:fitness_app/features/workout/data/camera/wave_skip_tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

const running = RepSnapshot(status: RepCountingStatus.running, averageConfidence: 0.9);

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<WorkoutHarness> openCamera(WidgetTester tester) async {
  final h = WorkoutHarness(
    plan: planWith(const [
      ItemView(exerciseId: squatId, nameVi: 'Squat', sets: 2, reps: 10),
      ItemView(exerciseId: gobletId, nameVi: 'Goblet squat', sets: 2, reps: 10),
    ]),
    factory: FakeRepSessionFactory(running),
  );
  await h.pump(tester, '/workout/$sessionId');
  await tapText(tester, 'Bắt đầu');
  await tapText(tester, 'Đếm bằng camera');
  await tapText(tester, 'Tôi đã sẵn sàng');
  // Đếm lùi 3.. 2.. 1.. Bắt đầu
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  return h;
}

FakeRepSession sessionOf(WorkoutHarness h) =>
    (h.factory as FakeRepSessionFactory).created.last;

Future<void> seconds(WidgetTester tester, WorkoutHarness h, int n) async {
  for (var i = 0; i < n; i++) {
    h.clock.now = h.clock.now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('vẫy tay khi đang đứng yên: đếm ngược 3 giây rồi sang bài tiếp theo', (
    tester,
  ) async {
    final h = await openCamera(tester);
    expect(find.byKey(const ValueKey('wave-hand-icon')), findsOneWidget);
    // Ba buổi đầu có câu nhắc cách vẫy tay
    expect(h.voice.spokenTexts, contains(waveSkipTipVi));

    await seconds(tester, h, 4);
    sessionOf(h).emit(
      const RepSnapshot(status: RepCountingStatus.running, handRaised: true, waveCount: 1),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('wave-skip-countdown')), findsOneWidget);
    expect(find.textContaining('Bỏ bài sau 3 giây'), findsOneWidget);
    expect(h.waveTips.spoken, WaveSkipTips.maxTips); // đã vẫy được: thôi nhắc

    await seconds(tester, h, 3);
    await tester.pumpAndSettle();
    expect(find.text('Goblet squat'), findsWidgets);
    expect(sessionOf(h).stops, greaterThan(0));
  });

  testWidgets('đang tập (vừa đếm được lần) thì vẫy tay không bỏ bài; làm thêm lần thì huỷ đếm ngược', (
    tester,
  ) async {
    final h = await openCamera(tester);
    await seconds(tester, h, 1);
    sessionOf(h).emit(const RepSnapshot(status: RepCountingStatus.running, repCount: 1));
    await tester.pump();
    await tester.pump();
    sessionOf(h).emit(
      const RepSnapshot(status: RepCountingStatus.running, repCount: 1, waveCount: 1),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('wave-skip-countdown')), findsNothing);

    await seconds(tester, h, 4);
    sessionOf(h).emit(
      const RepSnapshot(status: RepCountingStatus.running, repCount: 1, waveCount: 2),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('wave-skip-countdown')), findsOneWidget);
    sessionOf(h).emit(
      const RepSnapshot(status: RepCountingStatus.running, repCount: 2, waveCount: 2),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('wave-skip-countdown')), findsNothing);
    expect(h.voice.spokenTexts.last, 'Tiếp tục nhé.');
    await seconds(tester, h, 4);
    expect(find.text('Squat'), findsWidgets); // vẫn ở bài cũ
  });

  testWidgets('đứng yên 20 giây: coach hỏi bằng câu AI (Pro), bấm Tập tiếp thì đóng', (
    tester,
  ) async {
    final h = await openCamera(tester);
    h.voiceLines.text = 'Squat hơi khó hả? Vẫy tay nếu muốn đổi bài nhé.';
    await seconds(tester, h, 21);
    await tester.pump();
    expect(h.voiceLines.situations, ['idle_prompt']);
    expect(find.byKey(const ValueKey('wave-skip-prompt')), findsOneWidget);
    expect(find.text('Squat hơi khó hả? Vẫy tay nếu muốn đổi bài nhé.'), findsOneWidget);
    expect(h.voice.spokenTexts, contains('Squat hơi khó hả? Vẫy tay nếu muốn đổi bài nhé.'));
    await tapText(tester, 'Tập tiếp');
    expect(find.byKey(const ValueKey('wave-skip-prompt')), findsNothing);
  });

  testWidgets('không lấy được câu từ server thì dùng câu mẫu; bấm Bỏ bài này cũng đếm ngược', (
    tester,
  ) async {
    final h = await openCamera(tester);
    h.voiceLines.fail = true;
    await seconds(tester, h, 21);
    await tester.pump();
    expect(find.text(waveSkipPromptVi), findsOneWidget);
    await tester.tap(find.text('Bỏ bài này'));
    await tester.pump();
    expect(find.byKey(const ValueKey('wave-skip-countdown')), findsOneWidget);
    await tester.tap(find.text('Huỷ'));
    await tester.pump();
    expect(find.byKey(const ValueKey('wave-skip-countdown')), findsNothing);
  });
}
