import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/domain/models/streak_models.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:fitness_app/features/streak/presentation/screens/streak_screen.dart';
import 'package:fitness_app/features/streak/presentation/screens/streak_week_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreakFlow (F4)', () {
    test('mapWeekStatus maps status correctly, none does not return "Đang diễn ra"', () {
      final noneStatus = mapWeekStatus('none');
      expect(noneStatus.label, 'Không có dữ liệu');
      expect(noneStatus.label, isNot(equals('Đang diễn ra')));

      final inProgressStatus = mapWeekStatus('in_progress');
      expect(inProgressStatus.label, 'Đang diễn ra');

      final achievedStatus = mapWeekStatus('achieved');
      expect(achievedStatus.label, 'Đạt');

      final completedStatus = mapWeekStatus('completed');
      expect(completedStatus.label, 'Đạt');

      final missedStatus = mapWeekStatus('missed');
      expect(missedStatus.label, 'Chưa đạt');

      final brokenStatus = mapWeekStatus('broken');
      expect(brokenStatus.label, 'Chưa đạt');

      final frozenStatus = mapWeekStatus('frozen');
      expect(frozenStatus.label, 'Dùng thẻ đóng băng');
    });

    test(
      'formatWeekRange formats date range properly as Tuần dd/MM – dd/MM',
      () {
        expect(formatWeekRange('2026-10-05'), 'Tuần 05/10 – 11/10');
        expect(formatWeekRange('2026-09-28'), 'Tuần 28/09 – 04/10');
      },
    );

    testWidgets(
      'Renders 8 weeks history, freezes, and this week progress with formatted week labels',
      (tester) async {
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
          weeks: [
            const StreakWeek(
              weekStart: '2026-08-10',
              targetSessions: 3,
              completedSessions: 3,
              status: 'achieved',
            ),
            const StreakWeek(
              weekStart: '2026-08-17',
              targetSessions: 3,
              completedSessions: 0,
              status: 'none',
            ),
            const StreakWeek(
              weekStart: '2026-08-24',
              targetSessions: 3,
              completedSessions: 0,
              status: 'frozen',
            ),
            const StreakWeek(
              weekStart: '2026-08-31',
              targetSessions: 3,
              completedSessions: 1,
              status: 'missed',
            ),
          ],
        );

        final fakeRepo = FakeStreakRepository(initialStreak: fakeStreak);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [streakRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: StreakScreen()),
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
        expect(
          find.text('Còn 1 buổi để giữ vững streak tuần.'),
          findsOneWidget,
        );

        // Verify formatted week range labels
        expect(find.text('Tuần 10/08 – 16/08'), findsOneWidget);
        expect(find.text('Tuần 17/08 – 23/08'), findsOneWidget);
        expect(find.text('Tuần 24/08 – 30/08'), findsOneWidget);
        expect(find.text('Tuần 31/08 – 06/09'), findsOneWidget);

        // Status labels check
        expect(find.text('Đạt'), findsOneWidget);
        expect(find.text('Không có dữ liệu'), findsOneWidget);
        expect(find.text('Dùng thẻ đóng băng'), findsOneWidget);
        expect(find.text('Chưa đạt'), findsOneWidget);

        // Tuần mới nhất (31/08) nằm trên tuần cũ hơn (10/08)
        final posNewest = tester.getTopLeft(find.text('Tuần 31/08 – 06/09')).dy;
        final posOldest = tester.getTopLeft(find.text('Tuần 10/08 – 16/08')).dy;
        expect(posNewest < posOldest, isTrue);
      },
    );

    testWidgets(
      'Gracefully degrades to user streak on failure without crashing',
      (tester) async {
        final fakeRepo = FakeStreakRepository(
          errorToThrow: Exception('Network failure'),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [streakRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: StreakScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Gracefully falls back to 0 weeks without error crash
        expect(find.text('0 tuần liên tiếp'), findsOneWidget);
        expect(find.text('Thẻ đóng băng: 0 thẻ'), findsOneWidget);
      },
    );

    testWidgets(
      'StreakWeekDetailScreen renders 7 days, extra workouts, rest day, and header',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final weekDetail = StreakWeekDetail(
          weekStart: '2026-10-05',
          status: 'in_progress',
          targetSessions: 3,
          completedSessions: 1,
          days: [
            const StreakDayDetail(
              date: '2026-10-05',
              weekday: 1,
              sessions: [
                StreakSessionItem(
                  id: 's1',
                  title: 'Toàn thân cơ bản',
                  scheduledTime: '18:30',
                  durationMin: 15,
                  status: 'completed',
                ),
              ],
              workouts: [
                StreakWorkoutItem(
                  id: 'w1',
                  startedAt: '2026-10-05T18:30:00Z',
                  durationMin: 16,
                  countsForStreak: true,
                  plannedSessionId: 's1',
                ),
              ],
            ),
            const StreakDayDetail(
              date: '2026-10-06',
              weekday: 2,
              sessions: [],
              workouts: [],
            ),
            const StreakDayDetail(
              date: '2026-10-07',
              weekday: 3,
              sessions: [
                StreakSessionItem(
                  id: 's2',
                  title: 'Cardio cơ bản',
                  scheduledTime: '07:00',
                  durationMin: 20,
                  status: 'skipped',
                ),
              ],
              workouts: [],
            ),
            const StreakDayDetail(
              date: '2026-10-08',
              weekday: 4,
              sessions: [],
              workouts: [
                StreakWorkoutItem(
                  id: 'w2',
                  startedAt: '2026-10-08T20:00:00Z',
                  durationMin: 4,
                  countsForStreak: false,
                  plannedSessionId: null, // Tập thêm
                ),
              ],
            ),
            const StreakDayDetail(
              date: '2026-10-09',
              weekday: 5,
              sessions: [
                StreakSessionItem(
                  id: 's3',
                  title: 'Thân trên',
                  scheduledTime: '19:00',
                  durationMin: 20,
                  status: 'planned',
                ),
              ],
              workouts: [],
            ),
            const StreakDayDetail(
              date: '2026-10-10',
              weekday: 6,
              sessions: [],
              workouts: [],
            ),
            const StreakDayDetail(
              date: '2026-10-11',
              weekday: 7,
              sessions: [],
              workouts: [],
            ),
          ],
        );

        final fakeRepo = FakeStreakRepository(
          initialWeekDetails: {'2026-10-05': weekDetail},
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [streakRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(
              home: StreakWeekDetailScreen(weekStart: '2026-10-05'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Top card
        expect(find.text('Chi tiết tuần'), findsOneWidget);
        expect(find.text('Tuần 05/10 – 11/10'), findsOneWidget);
        expect(find.text('Đang diễn ra'), findsOneWidget);
        expect(find.text('1/3 buổi'), findsOneWidget);

        // Check all 7 days headers exist
        expect(find.byKey(const ValueKey('day-header-1')), findsOneWidget);
        expect(find.byKey(const ValueKey('day-header-2')), findsOneWidget);
        expect(find.byKey(const ValueKey('day-header-3')), findsOneWidget);
        expect(find.byKey(const ValueKey('day-header-4')), findsOneWidget);
        expect(find.byKey(const ValueKey('day-header-5')), findsOneWidget);
        expect(find.byKey(const ValueKey('day-header-6')), findsOneWidget);
        expect(find.byKey(const ValueKey('day-header-7')), findsOneWidget);

        // Check session status mapping
        expect(find.text('Đã tập ✓'), findsOneWidget);
        expect(find.text('Bỏ'), findsOneWidget);
        expect(find.text('Chưa tập'), findsOneWidget);

        // Check workouts display: extra workout and under 5 minutes
        expect(find.text('Tập thêm'), findsOneWidget);
        expect(find.text('dưới 5 phút, không tính streak'), findsOneWidget);

        // Check rest days
        expect(find.text('Nghỉ'), findsWidgets);
      },
    );
  });
}
