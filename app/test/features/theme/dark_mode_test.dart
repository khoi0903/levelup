import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/app/theme_mode.dart';
import 'package:fitness_app/core/constants/app_palette.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/coach/data/repositories/fake_coach_repository.dart';
import 'package:fitness_app/features/coach/presentation/controllers/coach_controller.dart';
import 'package:fitness_app/features/coach/presentation/screens/coach_screen.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/users/presentation/screens/achievements_screen.dart';
import 'package:fitness_app/features/users/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'readability.dart';

FakeAuthRepository signedInAuth() => FakeAuthRepository(
  initialUser: const AuthUser(id: 'test-user', email: 'test@levelup.vn'),
);

/// App thu gọn: dùng đúng theme/darkTheme/themeMode như main.dart.
class _ThemedApp extends ConsumerWidget {
  const _ThemedApp({this.home, this.router});
  final Widget? home;
  final RouterConfig<Object>? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    if (router != null) {
      return MaterialApp.router(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        routerConfig: router,
      );
    }
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      home: home,
    );
  }
}

const _me = MeResponse(
  id: 'u-1',
  displayName: 'Minh Khôi',
  localDate: '2026-10-20',
  streak: UserStreak(currentWeeks: 3, bestWeeks: 5, freezesAvailable: 1),
);

Future<void> _pump(
  WidgetTester tester, {
  Widget? home,
  RouterConfig<Object>? router,
  ThemeMode mode = ThemeMode.dark,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => ThemeModeNotifier(mode)),
        authRepositoryProvider.overrideWithValue(signedInAuth()),
        userRepositoryProvider.overrideWithValue(
          FakeUserRepository(meResponse: _me),
        ),
        coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
        nutritionRepositoryProvider.overrideWithValue(FakeNutritionRepository()),
      ],
      child: _ThemedApp(home: home, router: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Bảng màu tối', () {
    const d = AppPalette.dark;
    test('chữ đạt WCAG AA trên nền và thẻ', () {
      for (final bg in [d.background, d.surface, d.cardNormalBg]) {
        expect(contrastRatio(d.textPrimary, bg), greaterThanOrEqualTo(7));
        expect(contrastRatio(d.textSecondary, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(d.primary, bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(d.accentLink, bg), greaterThanOrEqualTo(4.5));
      }
      expect(contrastRatio(d.primary, d.primaryLight), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(Colors.white, d.buttonFill), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(d.errorText, d.errorBg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(d.successText, d.successBg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(d.infoText, d.infoBg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(d.warningText, d.warningBg), greaterThanOrEqualTo(4.5));
    });

    testWidgets('theme tối gắn đúng bảng màu', (tester) async {
      final t = AppTheme.darkTheme;
      expect(t.brightness, Brightness.dark);
      expect(t.extension<AppPalette>(), same(AppPalette.dark));
      expect(AppTheme.lightTheme.extension<AppPalette>(), same(AppPalette.light));
    });
  });

  group('Màn chính ở chế độ tối', () {
    testWidgets('Home', (tester) async {
      await _pump(
        tester,
        router: createAppRouter(initialLocation: '/home'),
      );
      expect(find.textContaining('Minh Khôi'), findsWidgets);
      await scrollAndCheckReadable(tester);
    });

    testWidgets('Hồ sơ', (tester) async {
      await _pump(tester, home: const ProfileScreen());
      await tester.scrollUntilVisible(
        find.text('Giao diện'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await scrollAndCheckReadable(tester);
    });

    testWidgets('Coach', (tester) async {
      await _pump(tester, home: const CoachScreen());
      await scrollAndCheckReadable(tester);
    });

    testWidgets('Huy hiệu', (tester) async {
      await _pump(tester, home: const AchievementsScreen());
      await scrollAndCheckReadable(tester);
    });

    testWidgets('Dinh dưỡng', (tester) async {
      await _pump(tester, home: const NutritionScreen());
      await scrollAndCheckReadable(tester);
    });
  });

  testWidgets('Hồ sơ → Giao diện: chọn Tối rồi Sáng, lưu lại trên máy', (
    tester,
  ) async {
    await _pump(tester, home: const ProfileScreen(), mode: ThemeMode.system);
    BuildContext ctx() => tester.element(find.byType(ProfileScreen));
    expect(Theme.of(ctx()).brightness, Brightness.light);

    final dark = find.byKey(const ValueKey('theme-dark'));
    await tester.scrollUntilVisible(
      dark,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(dark);
    await tester.pumpAndSettle();
    await tester.tap(dark);
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.dark);
    expect(ctx().colors.isDark, isTrue);
    expect(await loadSavedThemeMode(), ThemeMode.dark);
    expectReadableText(tester);

    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.light);
    expect(await loadSavedThemeMode(), ThemeMode.light);
  });
}
