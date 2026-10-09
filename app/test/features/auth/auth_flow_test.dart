import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/core/constants/app_strings.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/users/presentation/screens/profile_screen.dart';

void main() {
  group('FakeAuthRepository unit tests', () {
    test('signInWithGoogle signs in demo user', () async {
      final repo = FakeAuthRepository(initialUser: null);
      expect(repo.currentUser, isNull);

      final user = await repo.signInWithGoogle();
      expect(user.id, equals('google-user-id'));
      expect(repo.currentUser, isNotNull);
    });

    test('signInWithEmailPassword validates credentials', () async {
      final repo = FakeAuthRepository(initialUser: null);
      
      expect(
        () => repo.signInWithEmailPassword(
          email: 'wrong@levelup.vn',
          password: 'wrong_password',
        ),
        throwsA(isA<Exception>()),
      );

      final user = await repo.signInWithEmailPassword(
        email: 'test@levelup.vn',
        password: 'password123',
      );
      expect(user.email, equals('test@levelup.vn'));
      expect(repo.currentUser, isNotNull);
    });

    test('signUpWithEmailPassword fails if email already exists', () async {
      final repo = FakeAuthRepository(
        initialUser: const AuthUser(
          id: 'u1',
          email: 'existing@levelup.vn',
        ),
      );

      expect(
        () => repo.signUpWithEmailPassword(
          email: 'existing@levelup.vn',
          password: 'password123',
          displayName: 'Test User',
        ),
        throwsA(isA<Exception>()),
      );

      final newUser = await repo.signUpWithEmailPassword(
        email: 'new@levelup.vn',
        password: 'password123',
        displayName: 'New User',
      );
      expect(newUser.displayName, equals('New User'));
    });

    test('sendPasswordResetEmail records requested email', () async {
      final repo = FakeAuthRepository();
      await repo.sendPasswordResetEmail('forgot@levelup.vn');
      expect(repo.lastResetEmailSent, equals('forgot@levelup.vn'));
    });

    test('signOut clears currentUser', () async {
      final repo = FakeAuthRepository(
        initialUser: const AuthUser(id: 'u1', email: 'u1@levelup.vn'),
      );
      expect(repo.currentUser, isNotNull);

      await repo.signOut();
      expect(repo.currentUser, isNull);
    });
  });

  group('LoginScreen UI & Interactions', () {
    testWidgets('renders login form with Google button and toggles to register', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(initialUser: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and buttons
      expect(find.text('LevelUp'), findsOneWidget);
      expect(find.text('Đồng hành rèn luyện & duy trì thói quen'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Chưa có tài khoản?'), findsOneWidget);
      expect(find.text('Đăng ký ngay'), findsOneWidget);

      // Toggle to register
      await tester.tap(find.byKey(const ValueKey('auth-toggle-mode')));
      await tester.pumpAndSettle();

      expect(find.text('Tên hiển thị'), findsOneWidget);
      expect(find.text('Đăng ký tài khoản'), findsOneWidget);
      expect(find.text('Đã có tài khoản?'), findsOneWidget);
    });

    testWidgets('shows validation errors on empty submission', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(initialUser: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign In button without entering fields
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập đầy đủ email và mật khẩu.'), findsOneWidget);
    });

    testWidgets('shows Vietnamese error banner when login fails', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(
        initialUser: null,
        errorToThrow: Exception('Mật khẩu không chính xác. Vui lòng thử lại.'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fill in inputs using specific keys
      await tester.enterText(
        find.byKey(const ValueKey('auth-email-field')),
        'wrong@levelup.vn',
      );
      await tester.enterText(
        find.byKey(const ValueKey('auth-password-field')),
        'wrong_password',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const ValueKey('auth-submit-button')));
      await tester.pumpAndSettle();

      // Expect Vietnamese error banner
      expect(find.text('Mật khẩu không chính xác. Vui lòng thử lại.'), findsOneWidget);
    });

    testWidgets('opens forgot password bottom sheet and submits reset email', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(initialUser: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Quên mật khẩu?
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();

      // Verify bottom sheet appears
      expect(find.text('Quên mật khẩu?'), findsNWidgets(2)); // link + sheet title

      // Enter email in bottom sheet
      await tester.enterText(
        find.byKey(const ValueKey('forgot-password-email-field')),
        'user@levelup.vn',
      );
      await tester.pumpAndSettle();

      // Tap Gửi email đặt lại mật khẩu
      await tester.tap(find.byKey(const ValueKey('forgot-password-submit-button')));
      await tester.pumpAndSettle();

      // Verify sheet closed and success banner shown
      expect(fakeAuthRepo.lastResetEmailSent, equals('user@levelup.vn'));
      expect(find.text('Đã gửi email khôi phục mật khẩu. Vui lòng kiểm tra hộp thư.'), findsOneWidget);
    });
  });

  group('Auth Navigation & Bootstrap Flow', () {
    testWidgets('Chưa đăng nhập -> Điều hướng vào màn Đăng nhập (/login)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(initialUser: null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Lands on LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('LevelUp'), findsOneWidget);
      expect(find.text('Tiếp tục với Google'), findsOneWidget);
    });

    testWidgets('Đã đăng nhập + GET /me 404 ONBOARDING_REQUIRED -> Onboarding Goal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-1', email: 'test@levelup.vn'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                errorToThrow: const ApiException(
                  code: 'ONBOARDING_REQUIRED',
                  statusCode: 404,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.goalTitle), findsOneWidget);
    });

    testWidgets('Đã đăng nhập + GET /me 200 -> Home screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-1', email: 'test@levelup.vn'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                meResponse: const MeResponse(
                  id: 'user-1',
                  displayName: 'Trần Văn B',
                  timezone: 'Asia/Ho_Chi_Minh',
                  localDate: 'Thứ Bảy, 03/10',
                  weekStart: '2026-09-28',
                  profile: UserProfile(goal: 'lose_fat'),
                  streak: UserStreak(currentWeeks: 2, bestWeeks: 3),
                ),
              ),
            ),
            planRepositoryProvider.overrideWithValue(FakePlanRepository()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(', Trần Văn B'), findsOneWidget);
    });

    testWidgets('Backend 401 Unauthorized -> Đăng xuất và điều hướng về /login', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-expired', email: 'expired@levelup.vn'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                errorToThrow: const ApiException(
                  code: 'UNAUTHORIZED',
                  statusCode: 401,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bootstrap handles 401 by calling authRepo.signOut() and navigating to /login
      expect(fakeAuthRepo.currentUser, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Đăng xuất từ màn Cài đặt (ProfileScreen) -> Đăng xuất và điều hướng về /login', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAuthRepo = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-logout', email: 'logout@levelup.vn'),
      );

      final fakeUserRepo = FakeUserRepository(
        meResponse: const MeResponse(
          id: 'user-logout',
          displayName: 'Người Dùng Test',
          timezone: 'Asia/Ho_Chi_Minh',
          localDate: '2026-10-04',
          weekStart: '2026-09-28',
          profile: UserProfile(goal: 'lose_fat'),
          streak: UserStreak(currentWeeks: 1, bestWeeks: 1),
        ),
      );

      // Setup router with /profile and /login
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to bottom to find "Đăng xuất"
      await tester.scrollUntilVisible(find.text('Đăng xuất'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      final logoutBtn = find.text('Đăng xuất');
      expect(logoutBtn, findsOneWidget);
      await tester.tap(logoutBtn);
      await tester.pumpAndSettle();

      // Verify signed out in auth repo and routed to /login
      expect(fakeAuthRepo.currentUser, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
