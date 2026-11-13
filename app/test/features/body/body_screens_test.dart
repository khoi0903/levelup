import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/features/body/data/repositories/fake_body_repository.dart';
import 'package:fitness_app/features/body/domain/models/body_models.dart';
import 'package:fitness_app/features/body/presentation/controllers/body_controller.dart';
import 'package:fitness_app/features/body/presentation/screens/body_stats_screen.dart';
import 'package:fitness_app/features/body/presentation/widgets/body_figure.dart';
import 'package:fitness_app/features/body/presentation/widgets/body_profile_section.dart';
import 'package:fitness_app/features/onboarding/domain/models/onboarding_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_commit_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_focus_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_shape_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_stats_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_training_screen.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/domain/models/settings_request.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Router tối giản: màn cần thử + các đích đến chỉ hiện tên đường dẫn.
GoRouter _router(String initial, Widget screen, List<String> targets) =>
    GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: initial, builder: (_, _) => screen),
        for (final t in targets)
          GoRoute(
            path: t,
            builder: (_, _) => Scaffold(body: Text('route:$t')),
          ),
      ],
    );

void main() {
  group('Onboarding: trạng thái và JSON', () {
    test('updateBodyInfo không xoá vóc dáng và nhóm cơ đã chọn', () {
      final c = OnboardingController()
        ..setBodyFatPct(24)
        ..toggleFocusMuscle('abs')
        ..toggleFocusMuscle('legs')
        ..updateBodyInfo(heightCm: 170, startWeightKg: 65);
      expect(c.state.bodyFatPct, 24);
      expect(c.state.focusMuscles, ['abs', 'legs']);
      expect(c.state.heightCm, 170);

      c
        ..toggleFocusMuscle('abs')
        ..setBodyFatPct(null);
      expect(c.state.bodyFatPct, isNull);
      expect(c.state.focusMuscles, ['legs']);
    });

    test('JSON chỉ gửi bodyFatPct/focusMuscles khi đã chọn', () {
      const base = OnboardingState(
        displayName: 'Minh',
        goal: UserGoal.lose_fat,
        heightCm: 170,
        startWeightKg: 65,
        experience: Experience.beginner,
        location: WorkoutLocation.home,
        weekdays: [1, 3],
        timeSlot: TimeSlot.evening,
        sessionMinutes: 10,
        coachStyle: CoachStyle.supportive,
      );
      final empty = base.toOnboardingRequestJson();
      expect(empty.containsKey('bodyFatPct'), isFalse);
      expect(empty.containsKey('focusMuscles'), isFalse);

      final json = base
          .copyWith(bodyFatPct: 30, focusMuscles: ['glutes', 'abs'])
          .toOnboardingRequestJson();
      expect(json['bodyFatPct'], 30);
      expect(json['focusMuscles'], ['glutes', 'abs']);
    });

    test('PATCH /me: SettingsRequest gửi số đo, vóc dáng, nhóm cơ', () {
      expect(
        const SettingsRequest(
          heightCm: 171,
          weightKg: 66.5,
          bodyFatPct: 18,
          focusMuscles: ['chest'],
        ).toJson(),
        {
          'heightCm': 171.0,
          'weightKg': 66.5,
          'bodyFatPct': 18,
          'focusMuscles': ['chest'],
        },
      );
      expect(const SettingsRequest(displayName: 'A').toJson(), {
        'displayName': 'A',
      });
    });
  });

  group('Onboarding: màn mới', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      String path,
      Widget screen,
      List<String> targets, {
      List<Override> overrides = const [],
    }) async {
      _tall(tester);
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      container.read(onboardingControllerProvider.notifier)
        ..setGender(Gender.female)
        ..updateBodyInfo(heightCm: 160, startWeightKg: 55);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: _router(path, screen, targets),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('vóc dáng: chọn hình theo mức của nữ rồi sang nhóm cơ', (
      tester,
    ) async {
      final c = await pump(tester, '/onboarding/shape', const ObShapeScreen(), [
        '/onboarding/focus',
      ]);
      expect(find.text('Vóc dáng nào giống bạn nhất?'), findsOneWidget);
      expect(find.byType(BodyFigure), findsNWidgets(5));

      await tester.tap(find.byKey(const ValueKey('body-shape-26')));
      await tester.pumpAndSettle();
      expect(c.read(onboardingControllerProvider).bodyFatPct, 26);

      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('route:/onboarding/focus'), findsOneWidget);
    });

    testWidgets('vóc dáng: bỏ qua thì không gửi bodyFatPct', (tester) async {
      final c = await pump(tester, '/onboarding/shape', const ObShapeScreen(), [
        '/onboarding/focus',
      ]);
      await tester.tap(find.byKey(const ValueKey('ob-shape-skip')));
      await tester.pumpAndSettle();
      expect(c.read(onboardingControllerProvider).bodyFatPct, isNull);
      expect(find.text('route:/onboarding/focus'), findsOneWidget);
    });

    testWidgets('nhóm cơ: chọn bằng chip, sang màn tập luyện', (tester) async {
      final c = await pump(tester, '/onboarding/focus', const ObFocusScreen(), [
        '/onboarding/training',
      ]);
      expect(find.text('Nhóm cơ bạn muốn cải thiện'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('muscle-chip-abs')));
      await tester.tap(find.byKey(const ValueKey('muscle-chip-glutes')));
      await tester.pumpAndSettle();
      expect(c.read(onboardingControllerProvider).focusMuscles, [
        'abs',
        'glutes',
      ]);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('route:/onboarding/training'), findsOneWidget);
    });

    testWidgets('tập luyện: bản đồ đau có đủ vùng, giữ payload injuries', (
      tester,
    ) async {
      final c = await pump(
        tester,
        '/onboarding/training',
        const ObTrainingScreen(),
        ['/onboarding/schedule'],
      );
      await tester.ensureVisible(find.byKey(const ValueKey('pain-chip-none')));
      for (final area in BodyArea.values) {
        expect(find.byKey(ValueKey('pain-chip-${area.name}')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('pain-chip-ankle')));
      await tester.tap(find.byKey(const ValueKey('pain-chip-neck')));
      await tester.pumpAndSettle();
      expect(c.read(onboardingControllerProvider).injuries, [
        BodyArea.ankle,
        BodyArea.neck,
      ]);

      // Chạm thẳng vào điểm gối trên hình
      final figureFinder = find.byKey(const ValueKey('pain-map-figure'));
      final figure = tester.widget<BodyFigure>(figureFinder);
      final box = tester.renderObject<RenderBox>(figureFinder);
      final knee = BodyGeometry(
        figure.shape,
        BodySide.front,
      ).painSpots['knee']!.first;
      await tester.tapAt(
        box.localToGlobal(BodyGeometry.toLocal(knee, box.size)),
      );
      await tester.pumpAndSettle();
      expect(
        c.read(onboardingControllerProvider).injuries,
        contains(BodyArea.knee),
      );

      await tester.tap(find.byKey(const ValueKey('pain-chip-none')));
      await tester.pumpAndSettle();
      expect(c.read(onboardingControllerProvider).injuries, isEmpty);
    });

    testWidgets('chỉ số sau kế hoạch: lấy GET /me/body rồi sang nhắc nhở', (
      tester,
    ) async {
      final repo = FakeBodyRepository();
      await pump(
        tester,
        '/onboarding/stats',
        const ObStatsScreen(),
        ['/onboarding/notify'],
        overrides: [bodyRepositoryProvider.overrideWithValue(repo)],
      );
      expect(find.text('Chỉ số của bạn'), findsOneWidget);
      expect(find.text('23.5'), findsOneWidget);
      expect(repo.bodyCalls, 1);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('route:/onboarding/notify'), findsOneWidget);
    });

    testWidgets('chỉ số: máy chủ lỗi vẫn hiện BMI tính từ số đo vừa nhập', (
      tester,
    ) async {
      final repo = FakeBodyRepository()..bodyError = Exception('500');
      await pump(
        tester,
        '/onboarding/stats',
        const ObStatsScreen(),
        ['/onboarding/notify'],
        overrides: [bodyRepositoryProvider.overrideWithValue(repo)],
      );
      // 55 / 1.6^2 = 21.5
      expect(find.text('21.5'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsOneWidget);
    });

    testWidgets('cam kết: tóm tắt kế hoạch và nút "Tôi sẽ kiên trì!"', (
      tester,
    ) async {
      final c = await pump(
        tester,
        '/onboarding/commit',
        const ObCommitScreen(),
        ['/onboarding/start'],
      );
      c.read(onboardingControllerProvider.notifier)
        ..selectGoal(UserGoal.build_muscle)
        ..toggleWeekday(1)
        ..toggleWeekday(3)
        ..toggleWeekday(5)
        ..setSessionMinutes(10);
      await tester.pumpAndSettle();

      expect(find.text('Kế hoạch của bạn đã sẵn sàng'), findsOneWidget);
      Text text(String key) => tester.widget<Text>(find.byKey(ValueKey(key)));
      expect(text('commit-sessions').data, '3 buổi');
      expect(text('commit-minutes').data, '10 phút');
      expect(text('commit-goal').data, 'Tăng cơ');

      await tester.tap(find.text('Tôi sẽ kiên trì!'));
      await tester.pumpAndSettle();
      expect(find.text('route:/onboarding/start'), findsOneWidget);
    });
  });

  group('Màn chỉ số và tab Tôi', () {
    testWidgets('màn chỉ số: nhãn BMI trung tính, "ước tính", giải thích ⓘ', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bodyRepositoryProvider.overrideWithValue(FakeBodyRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const BodyStatsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('23.5'), findsOneWidget);
      expect(find.text('Trong khoảng chuẩn'), findsOneWidget);
      expect(find.text('19%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('body-stats-fat-estimated')),
        findsOneWidget,
      );
      for (final m in [
        'bmi',
        'bodyFat',
        'bmr',
        'tdee',
        'targetKcal',
        'protein',
        'carbs',
        'fat',
        'water',
      ]) {
        expect(find.byKey(ValueKey('metric-info-$m')), findsOneWidget);
      }
      expect(find.textContaining('béo'), findsNWidgets(1)); // chỉ "Chất béo"
      expect(find.textContaining('gầy'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('metric-info-tdee')));
      await tester.pumpAndSettle();
      expect(find.text('TDEE – tổng năng lượng mỗi ngày'), findsOneWidget);
      expect(find.text('Cách tính'), findsOneWidget);
      expect(
        find.text('Chỉ là ước tính, không phải chẩn đoán y khoa.'),
        findsNWidgets(2),
      );
    });

    testWidgets('màn chỉ số: không có nhãn "ước tính" khi người dùng tự chọn', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bodyRepositoryProvider.overrideWithValue(
              FakeBodyRepository(
                stats: const BodyStats(bmi: 31.2, bmiCategory: 'obese'),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const BodyStatsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cao hơn khoảng chuẩn'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('body-stats-fat-estimated')),
        findsNothing,
      );
      expect(find.text('–'), findsWidgets);
    });

    testWidgets('thẻ cơ đã tập: nhóm 0 hiệp hiện "Tuần này chưa tập"', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bodyRepositoryProvider.overrideWithValue(FakeBodyRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: MusclesWeekCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Text row(String m) =>
          tester.widget<Text>(find.byKey(ValueKey('muscles-week-$m')));

      expect(find.text('Cơ đã tập tuần này'), findsOneWidget);
      expect(row('legs').data, '12 hiệp');
      expect(row('chest').data, '6 hiệp');
      expect(find.byKey(const ValueKey('muscles-week-back')), findsNothing);
      final figure = tester.widget<BodyFigure>(
        find.byKey(const ValueKey('muscles-week-figure')),
      );
      expect(figure.mode, BodyFigureMode.heat);
      expect(figure.heat['legs'], 1);
      expect(figure.heat['back'], 0);

      await tester.tap(find.byKey(const ValueKey('body-side-back')));
      await tester.pumpAndSettle();
      expect(row('back').data, 'Tuần này chưa tập');
      expect(row('glutes').data, 'Tuần này chưa tập');
      expect(find.byKey(const ValueKey('muscles-week-chest')), findsNothing);
    });

    testWidgets('cài đặt cơ thể: sửa số đo, vóc dáng, nhóm cơ gọi PATCH /me', (
      tester,
    ) async {
      _tall(tester);
      final users = FakeUserRepository();
      final body = FakeBodyRepository();
      const me = MeResponse(id: 'u1', displayName: 'Minh');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(users),
            bodyRepositoryProvider.overrideWithValue(body),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: BodySettingsCard(me: me)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Text value(String key) =>
          tester.widget<Text>(find.byKey(ValueKey('$key-value')));
      expect(value('body-edit-size').data, '170 cm · 68 kg');
      // Tỉ lệ mỡ đang là số ước tính nên coi như chưa chọn vóc dáng
      expect(value('body-edit-shape').data, 'Chưa chọn');
      expect(value('body-edit-focus').data, 'Ngực, Bụng');

      // Chiều cao, cân nặng
      await tester.tap(find.byKey(const ValueKey('body-edit-size')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('body-height-field')),
        '50',
      );
      await tester.tap(find.byKey(const ValueKey('body-size-save')));
      await tester.pumpAndSettle();
      expect(find.text('Chiều cao từ 100 tới 230 cm'), findsOneWidget);
      expect(users.lastRequest, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('body-height-field')),
        '172',
      );
      await tester.enterText(
        find.byKey(const ValueKey('body-weight-field')),
        '66,5',
      );
      await tester.tap(find.byKey(const ValueKey('body-size-save')));
      await tester.pumpAndSettle();
      expect(users.lastRequest!.toJson(), {
        'heightCm': 172.0,
        'weightKg': 66.5,
      });
      expect(body.bodyCalls, 2);

      // Vóc dáng
      await tester.tap(find.byKey(const ValueKey('body-edit-shape')));
      await tester.pumpAndSettle();
      expect(find.byType(BodyFigure), findsNWidgets(5));
      await tester.tap(find.byKey(const ValueKey('body-shape-24')));
      await tester.pumpAndSettle();
      expect(users.lastRequest!.toJson(), {'bodyFatPct': 24});

      // Nhóm cơ
      await tester.tap(find.byKey(const ValueKey('body-edit-focus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('muscle-chip-chest')));
      await tester.tap(find.byKey(const ValueKey('muscle-chip-legs')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('body-focus-save')));
      await tester.tap(find.byKey(const ValueKey('body-focus-save')));
      await tester.pumpAndSettle();
      expect(users.lastRequest!.toJson(), {
        'focusMuscles': ['abs', 'legs'],
      });

      // Xem lại hướng dẫn
      await tester.tap(find.byKey(const ValueKey('replay-tutorials')));
      await tester.pump();
      expect(
        find.text('Hướng dẫn sẽ hiện lại khi bạn mở từng màn hình.'),
        findsOneWidget,
      );
    });
  });
}
