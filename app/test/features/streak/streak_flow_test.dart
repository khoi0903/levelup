import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/domain/models/streak_models.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:fitness_app/features/streak/presentation/screens/streak_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakFlow (F4)', () {
    testWidgets('Renders 8 weeks history, freezes, and this week progress', (tester) async {
      final fakeStreak = StreakView(
        currentWeeks: 5,
        bestWeeks: 8,
        freezesAvailable: 2,
        thisWeek: const StreakWeek(
          weekStart: '2026-09-28',
          targetSessions: 4,
          completedSessions: 3,
          status: 'in_progress',
        ),
        weeks: List.generate(
          8,
          (i) => StreakWeek(
            weekStart: '2026-08-${(10 + i * 7).toString().padLeft(2, '0')}',
            targetSessions: 3,
            completedSessions: 3,
            status: 'achieved',
          ),
        ),
      );

      final fakeRepo = FakeStreakRepository(initialStreak: fakeStreak);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streakRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: StreakScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chuỗi tuần (Streak)'), findsOneWidget);
      expect(find.text('5 tuần liên tiếp'), findsOneWidget);
      expect(find.text('Kỷ lục cao nhất: 8 tuần'), findsOneWidget);
      expect(find.text('Thẻ đóng băng: 2 thẻ'), findsOneWidget);
      expect(find.text('Tuần này'), findsOneWidget);
      expect(find.text('3/4 buổi'), findsOneWidget);
      expect(find.text('Lịch sử 8 tuần gần nhất'), findsOneWidget);
      expect(find.text('Còn 1 buổi để giữ vững streak tuần.'), findsOneWidget);
    });

    testWidgets('Gracefully degrades to user streak on failure without crashing', (tester) async {
      final fakeRepo = FakeStreakRepository(
        errorToThrow: Exception('Network failure'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            streakRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: StreakScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Gracefully falls back to 0 weeks without error crash
      expect(find.text('0 tuần liên tiếp'), findsOneWidget);
      expect(find.text('Thẻ đóng băng: 0 thẻ'), findsOneWidget);
    });
  });
}
