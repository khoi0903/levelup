import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/nutrition/presentation/screens/meal_editor_screen.dart';

import '../nutrition/nutrition_flow_test.dart' show FakePhotoPicker;

import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/coach/data/repositories/fake_coach_repository.dart';
import 'package:fitness_app/features/coach/presentation/controllers/coach_controller.dart';
import 'package:fitness_app/features/coach/presentation/screens/coach_screen.dart';
import 'package:fitness_app/features/product/domain/models/product_models.dart';
import 'package:fitness_app/features/product/domain/repositories/product_repository.dart';
import 'package:fitness_app/features/product/domain/services/billing_service.dart';
import 'package:fitness_app/features/product/presentation/controllers/product_controller.dart';
import 'package:fitness_app/features/product/presentation/screens/admin_screen.dart';
import 'package:fitness_app/features/product/presentation/screens/pro_screen.dart';
import 'package:fitness_app/features/product/presentation/screens/referral_screen.dart';
import 'package:fitness_app/features/product/presentation/widgets/product_widgets.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeProductRepository implements ProductRepository {
  ProductConfig config = const ProductConfig();
  Map<String, dynamic>? saved;
  Object? redeemError;
  String? redeemed;
  int configReads = 0, referralReads = 0;
  @override
  Future<ProductConfig> getConfig() async {
    configReads++;
    return config;
  }

  @override
  Future<ProductConfig> saveConfig(ProductConfig config) async {
    saved = config.toJson();
    this.config = ProductConfig.fromJson({
      ...saved!,
      'version': config.version + 1,
    });
    return this.config;
  }

  @override
  Future<void> grantPro(String email, int days) async {}
  @override
  Future<ReferralView> getReferral() async {
    referralReads++;
    return const ReferralView(
      code: 'FRIEND77',
      link: 'https://levelup.vn/referral?code=FRIEND77',
      successfulCount: 1,
      nextMilestone: ReferralMilestone(3, 30),
      milestones: [
        ReferralMilestone(1, 7),
        ReferralMilestone(3, 30),
        ReferralMilestone(10, 90),
      ],
      rewardsEarned: [ReferralMilestone(1, 7)],
    );
  }

  @override
  Future<void> redeem(String code) async {
    redeemed = code;
    if (redeemError != null) throw redeemError!;
  }
}

class TestProBillingService implements BillingService {
  final Future<String> Function(BillingPeriod period) onPurchase;
  bool restoreCalled = false;
  BillingPeriod? lastPurchasedPeriod;

  TestProBillingService({required this.onPurchase});

  @override
  Future<String> purchase(BillingPeriod period) {
    lastPurchasedPeriod = period;
    return onPurchase(period);
  }

  @override
  Future<String> restore() async {
    restoreCalled = true;
    return 'Đã khôi phục giao dịch';
  }

  @override
  Future<Map<BillingPeriod, String>> getPrices() async => const {};

  @override
  Future<void> logOut() async {}
}

MeResponse me({
  bool enabled = false,
  bool referral = false,
  bool admin = false,
  int age = 1,
}) => MeResponse(
  id: 'u1',
  displayName: 'Khôi',
  localDate: '2026-10-11',
  referralRedeemEligible: age <= 7,
  createdAt: DateTime.utc(2026, 10, 11).subtract(Duration(days: age)),
  isAdmin: admin,
  subscription: Subscription(enabled: enabled),
  productConfig: ProductConfig(proEnabled: enabled, referralEnabled: referral),
);

Future<void> mount(
  WidgetTester tester,
  MeResponse user,
  FakeProductRepository repo, {
  String route = '/',
  FakeCoachRepository? coach,
  FakeNutritionRepository? nutrition,
  BillingService? billingService,
  FakeUserRepository? userRepo,
}) async {
  final router = GoRouter(
    initialLocation: route,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: SingleChildScrollView(child: ProductProfileCards()),
        ),
      ),
      GoRoute(path: '/pro', builder: (_, _) => const ProScreen()),
      GoRoute(path: '/referrals', builder: (_, _) => const ReferralScreen()),
      GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
      GoRoute(
        path: '/photo',
        builder: (_, _) => const MealEditorScreen(photoMode: true),
      ),
      GoRoute(path: '/coach', builder: (_, _) => const CoachScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => user),
        userRepositoryProvider.overrideWithValue(
          userRepo ?? FakeUserRepository(meResponse: user),
        ),
        productRepositoryProvider.overrideWithValue(repo),
        if (billingService != null)
          billingServiceProvider.overrideWithValue(billingService),
        if (nutrition != null)
          nutritionRepositoryProvider.overrideWithValue(nutrition),
        if (nutrition != null)
          mealPhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
        if (coach != null) coachRepositoryProvider.overrideWithValue(coach),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('MeResponse reads and preserves flags, plan and configuration', () {
    final original = me(enabled: true, referral: true, admin: true);
    final result = MeResponse.fromJson(original.toJson());
    expect(result.subscription.enabled, isTrue);
    expect(result.subscription.coachPerDay, 30);
    expect(result.isAdmin, isTrue);
    expect(result.productConfig.referralEnabled, isTrue);
    expect(result.createdAt, original.createdAt);
    expect(
      MeResponse.fromJson({'id': 'u', 'displayName': 'U'}).subscription.enabled,
      isFalse,
    );
  });
  testWidgets('disabled product hides all Pro and referral entries', (
    tester,
  ) async {
    await mount(tester, me(), FakeProductRepository());
    expect(find.text('LevelUp Pro'), findsNothing);
    expect(find.text('Mời bạn, nhận Pro'), findsNothing);
    expect(find.text('Nhập mã giới thiệu'), findsNothing);
  });
  testWidgets('enabled card opens /pro and fake purchase shows coming soon', (
    tester,
  ) async {
    await mount(tester, me(enabled: true), FakeProductRepository());
    await tester.tap(find.text('LevelUp Pro'));
    await tester.pumpAndSettle();
    expect(find.text('Miễn phí'), findsOneWidget);
    expect(find.text('10 tin/ngày'), findsOneWidget);
    expect(find.text('100 tin/ngày'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Dùng thử 7 ngày'), 300);
    await tester.tap(find.text('Dùng thử 7 ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Sắp ra mắt'), findsOneWidget);
  });
  testWidgets('direct /pro is hidden while disabled', (tester) async {
    await mount(tester, me(), FakeProductRepository(), route: '/pro');
    expect(find.text('LevelUp Pro'), findsNothing);
    expect(find.text('Không tìm thấy trang'), findsOneWidget);
  });
  testWidgets('coach quota error shows Pro action only when enabled', (
    tester,
  ) async {
    final coach = FakeCoachRepository(
      errorToThrow: const ApiException(code: 'COACH_LIMIT'),
    );
    await mount(
      tester,
      me(enabled: true),
      FakeProductRepository(),
      route: '/coach',
      coach: coach,
    );
    expect(find.text('Xem gói Pro'), findsOneWidget);
    await tester.tap(find.text('Xem gói Pro'));
    await tester.pumpAndSettle();
    expect(find.text('LevelUp Pro'), findsOneWidget);
  });
  testWidgets('disabled coach quota never advertises Pro', (tester) async {
    await mount(
      tester,
      me(),
      FakeProductRepository(),
      route: '/coach',
      coach: FakeCoachRepository(
        errorToThrow: const ApiException(code: 'COACH_LIMIT'),
      ),
    );
    expect(find.text('Xem gói Pro'), findsNothing);
  });
  for (final enabled in [false, true]) {
    testWidgets('photo quota action follows enabled=$enabled', (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final nutrition = FakeNutritionRepository()
        ..recognitionError = const ApiException(
          code: 'PHOTO_LIMIT_REACHED',
          statusCode: 429,
        );
      await mount(
        tester,
        me(enabled: enabled),
        FakeProductRepository(),
        route: '/photo',
        nutrition: nutrition,
      );
      await tester.tap(find.text('Chụp ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Xem gói Pro'), enabled ? findsOneWidget : findsNothing);
    });
  }
  testWidgets('referral flag hides entry and direct route without fetching', (
    tester,
  ) async {
    final repo = FakeProductRepository();
    await mount(tester, me(enabled: true), repo, route: '/referrals');
    expect(find.text('Mời bạn, nhận Pro'), findsNothing);
    expect(repo.referralReads, 0);
  });
  testWidgets('referral flag shows entry, code, progress and earned reward', (
    tester,
  ) async {
    final repo = FakeProductRepository();
    await mount(tester, me(enabled: true, referral: true), repo);
    await tester.tap(find.text('Mời bạn, nhận Pro'));
    await tester.pumpAndSettle();
    expect(find.text('FRIEND77'), findsOneWidget);
    expect(find.text('Thêm 2 bạn để nhận 30 ngày Pro'), findsOneWidget);
    expect(repo.referralReads, 1);
  });
  testWidgets('invalid referral code displays Vietnamese API error', (
    tester,
  ) async {
    final repo = FakeProductRepository()
      ..redeemError = const ApiException(code: 'INVALID_CODE');
    await mount(tester, me(enabled: true, referral: true), repo);
    await tester.enterText(
      find.byKey(const ValueKey('referral-code-input')),
      'BADCODE',
    );
    await tester.tap(find.text('Áp dụng mã'));
    await tester.pumpAndSettle();
    expect(repo.redeemed, 'BADCODE');
    expect(find.text('Mã giới thiệu không hợp lệ.'), findsOneWidget);
  });
  testWidgets('referral input hidden after seven days', (tester) async {
    await mount(
      tester,
      me(enabled: true, referral: true, age: 8),
      FakeProductRepository(),
    );
    expect(find.text('Nhập mã giới thiệu'), findsNothing);
  });
  testWidgets('ordinary user cannot open Admin or load its configuration', (
    tester,
  ) async {
    final repo = FakeProductRepository();
    await mount(tester, me(), repo, route: '/admin');
    expect(find.text('Admin'), findsNothing);
    expect(repo.configReads, 0);
  });
  testWidgets('admin edits a milestone and saves exact configuration body', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final repo = FakeProductRepository();
    await mount(tester, me(admin: true), repo, route: '/admin');
    await tester.tap(find.text('1 bạn → 7 ngày'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('milestone-days')), '14');
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu cấu hình'));
    await tester.pumpAndSettle();
    expect(repo.saved?['referralMilestones'], [
      {'friends': 1, 'days': 14},
      {'friends': 3, 'days': 30},
      {'friends': 10, 'days': 90},
    ]);
    expect(repo.saved?['coachFreePerDay'], 10);
    expect(repo.saved?['version'], 0);
    expect(repo.saved?['proEnabled'], isFalse);
    expect(find.text('Các nút demo'), findsNothing);
  });

  test('empty key uses FakeBillingService', () {
    expect(isRevenueCatSupported(key: ''), isFalse);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final billing = container.read(billingServiceProvider);
    expect(billing, isA<FakeBillingService>());
  });

  testWidgets('cancelling purchase shows no error or snackbar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fakeBilling = FakeBillingService(purchaseResult: '');
    await mount(
      tester,
      me(enabled: true),
      FakeProductRepository(),
      route: '/pro',
      billingService: fakeBilling,
    );
    await tester.tap(find.text('Dùng thử 7 ngày'));
    await tester.pumpAndSettle();
    expect(fakeBilling.lastPurchasedPeriod, BillingPeriod.yearly);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('restore purchases calls restore method and shows feedback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fakeBilling = FakeBillingService();
    await mount(
      tester,
      me(enabled: true),
      FakeProductRepository(),
      route: '/pro',
      billingService: fakeBilling,
    );
    await tester.tap(find.text('Khôi phục giao dịch'));
    await tester.pumpAndSettle();
    expect(fakeBilling.restoreCalled, isTrue);
    expect(find.text('Đã khôi phục giao dịch'), findsOneWidget);
  });

  testWidgets('successful purchase reloads /me and displays Pro status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final initialUser = me(enabled: true);
    final proUser = MeResponse(
      id: initialUser.id,
      displayName: initialUser.displayName,
      localDate: initialUser.localDate,
      subscription: Subscription(
        enabled: true,
        tier: 'pro',
        expiresAt: DateTime.utc(2026, 11, 17),
      ),
      productConfig: initialUser.productConfig,
    );

    final router = GoRouter(
      initialLocation: '/pro',
      routes: [
        GoRoute(path: '/pro', builder: (_, _) => const ProScreen()),
      ],
    );
    addTearDown(router.dispose);

    late final ProviderContainer container;
    final testBilling = TestProBillingService(
      onPurchase: (period) async {
        container.read(currentUserProvider.notifier).state = proUser;
        return 'Đã kích hoạt Pro';
      },
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            currentUserProvider.overrideWith((ref) => initialUser),
            billingServiceProvider.overrideWithValue(testBilling),
          ],
        ),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dùng thử 7 ngày'), findsOneWidget);
    await tester.tap(find.text('Dùng thử 7 ngày'));
    await tester.pumpAndSettle();

    expect(find.text('Đã kích hoạt Pro'), findsOneWidget);
    expect(find.text('Pro đến 2026-11-17'), findsOneWidget);
    expect(find.text('Quản lý gói'), findsOneWidget);
    expect(find.text('Dùng thử 7 ngày'), findsNothing);
  });

  testWidgets('proEnabled == false hides buy button and shows coming soon notice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final user = MeResponse(
      id: 'u1',
      displayName: 'Khôi',
      localDate: '2026-10-11',
      subscription: const Subscription(enabled: true),
      productConfig: const ProductConfig(proEnabled: false),
    );
    await mount(tester, user, FakeProductRepository(), route: '/pro');
    expect(find.text('Dùng thử 7 ngày'), findsNothing);
    expect(
      find.text('Giá dự kiến. Chức năng mua đang được chuẩn bị.'),
      findsOneWidget,
    );
  });
}
