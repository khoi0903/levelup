import 'dart:math' as math;

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

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

FakeAuthRepository signedInAuth() => FakeAuthRepository(
  initialUser: const AuthUser(id: 'test-user', email: 'test@levelup.vn'),
);

Color _blend(Color fg, Color bg) => Color.alphaBlend(fg, bg.withValues(alpha: 1));

/// Màu nền gần nhất phía sau một đoạn chữ (bỏ qua lớp phủ mờ).
Color _backgroundOf(Element e, Color fallback) {
  Color? found;
  e.visitAncestorElements((a) {
    final w = a.widget;
    Color? c;
    if (w is DecoratedBox && w.decoration is BoxDecoration) {
      final d = w.decoration as BoxDecoration;
      c = d.color ?? d.gradient?.colors.first;
    } else if (w is ColoredBox) {
      c = w.color;
    } else if (w is Material && w.type != MaterialType.transparency) {
      c = w.color;
    }
    if (c != null && c.a >= 0.5) {
      found = c;
      return false;
    }
    return true;
  });
  return found ?? fallback;
}

/// Mọi chữ trên màn phải đọc được trên nền ngay sau nó (≥ 3:1, đủ để bắt
/// lỗi chữ trắng trên nền trắng hay chữ tối trên nền tối).
void _expectReadableText(WidgetTester tester, AppPalette palette) {
  final problems = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final rich = element.widget as RichText;
    final bg = _backgroundOf(element, palette.background);
    void check(InlineSpan span, Color? inherited) {
      final color = span.style?.color ?? inherited;
      if (span is TextSpan) {
        final text = span.text?.trim() ?? '';
        if (color != null && text.isNotEmpty && !_isEmojiOnly(text)) {
          final ratio = _contrast(_blend(color, bg), bg);
          if (ratio < 3.0) {
            problems.add('"$text" ${ratio.toStringAsFixed(2)}:1 '
                '(chữ $color, nền $bg)');
          }
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          check(child, color);
        }
      }
    }

    check(rich.text, null);
  }
  expect(problems, isEmpty, reason: problems.join('\n'));
}

/// Cuộn dần xuống cuối, kiểm tra chữ ở từng đoạn.
Future<void> _scrollAndCheck(WidgetTester tester, AppPalette palette) async {
  _expectReadableText(tester, palette);
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  for (var i = 0; i < 12; i++) {
    await tester.drag(scrollable.first, const Offset(0, -500), warnIfMissed: false);
    await tester.pumpAndSettle();
    _expectReadableText(tester, palette);
  }
}

bool _isEmojiOnly(String s) => s.runes.every((r) => r > 0x2000);

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
        expect(_contrast(d.textPrimary, bg), greaterThanOrEqualTo(7));
        expect(_contrast(d.textSecondary, bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(d.primary, bg), greaterThanOrEqualTo(4.5));
        expect(_contrast(d.accentLink, bg), greaterThanOrEqualTo(4.5));
      }
      expect(_contrast(d.primary, d.primaryLight), greaterThanOrEqualTo(4.5));
      expect(_contrast(Colors.white, d.buttonFill), greaterThanOrEqualTo(4.5));
      expect(_contrast(d.errorText, d.errorBg), greaterThanOrEqualTo(4.5));
      expect(_contrast(d.successText, d.successBg), greaterThanOrEqualTo(4.5));
      expect(_contrast(d.infoText, d.infoBg), greaterThanOrEqualTo(4.5));
      expect(_contrast(d.warningText, d.warningBg), greaterThanOrEqualTo(4.5));
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
      await _scrollAndCheck(tester, AppPalette.dark);
    });

    testWidgets('Hồ sơ', (tester) async {
      await _pump(tester, home: const ProfileScreen());
      await tester.scrollUntilVisible(
        find.text('Giao diện'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await _scrollAndCheck(tester, AppPalette.dark);
    });

    testWidgets('Coach', (tester) async {
      await _pump(tester, home: const CoachScreen());
      await _scrollAndCheck(tester, AppPalette.dark);
    });

    testWidgets('Huy hiệu', (tester) async {
      await _pump(tester, home: const AchievementsScreen());
      await _scrollAndCheck(tester, AppPalette.dark);
    });

    testWidgets('Dinh dưỡng', (tester) async {
      await _pump(tester, home: const NutritionScreen());
      await _scrollAndCheck(tester, AppPalette.dark);
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
    _expectReadableText(tester, AppPalette.dark);

    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    expect(Theme.of(ctx()).brightness, Brightness.light);
    expect(await loadSavedThemeMode(), ThemeMode.light);
  });
}
