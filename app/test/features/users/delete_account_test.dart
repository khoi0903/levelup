import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/core/api/api_client.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/users/data/repositories/api_user_repository.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/users/presentation/screens/profile_screen.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:fitness_app/features/workout/presentation/screens/workout_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DeleteRecordingAdapter implements HttpClientAdapter {
  String? recordedMethod;
  String? recordedPath;
  Map<String, dynamic>? recordedBody;
  int statusCode = 204;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recordedMethod = options.method;
    recordedPath = options.path;
    if (options.data != null && options.data is Map<String, dynamic>) {
      recordedBody = options.data as Map<String, dynamic>;
    } else if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) {
        recordedBody = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      }
    }

    return ResponseBody.fromString(
      statusCode == 204 ? '' : jsonEncode({'status': 'ok'}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TestWorkoutController extends WorkoutController {
  _TestWorkoutController(super.ref, WorkoutSessionState? initial) {
    state = initial;
  }
}

void main() {
  group('ApiUserRepository - deleteAccount contract', () {
    test('gọi đúng DELETE /me {"confirm": true}', () async {
      final adapter = _DeleteRecordingAdapter();
      final client = ApiClient(
        baseUrl: 'http://localhost:8081',
        tokenProvider: () async => 'dev-token',
      );
      client.dio.httpClientAdapter = adapter;

      final repo = ApiUserRepository(client);
      await repo.deleteAccount();

      expect(adapter.recordedMethod, equals('DELETE'));
      expect(adapter.recordedPath, equals('/me'));
      expect(adapter.recordedBody, equals({'confirm': true}));
    });
  });

  group('Xoá tài khoản UI (Tab Tôi - ProfileScreen)', () {
    late FakeAuthRepository fakeAuthRepo;
    late FakeUserRepository fakeUserRepo;
    late GoRouter router;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeAuthRepo = FakeAuthRepository(
        initialUser: const AuthUser(
          id: 'user-delete-test',
          email: 'delete-test@levelup.vn',
          displayName: 'Test User',
        ),
      );

      fakeUserRepo = FakeUserRepository(
        meResponse: const MeResponse(
          id: 'user-delete-test',
          displayName: 'Test User',
          timezone: 'Asia/Ho_Chi_Minh',
          localDate: '2026-10-09',
          weekStart: '2026-10-05',
          profile: UserProfile(goal: 'lose_fat'),
          streak: UserStreak(currentWeeks: 3, bestWeeks: 3),
        ),
      );

      router = GoRouter(
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
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          userRepositoryProvider.overrideWithValue(fakeUserRepo),
        ],
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
        ),
      );
    }

    testWidgets(
      'luồng xoá đủ 2 bước gọi đúng DELETE /me {"confirm": true} rồi về màn đăng nhập',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Cuộn xuống tìm mục "Xoá tài khoản"
        final deleteBtn = find.byKey(const ValueKey('delete-account-button'));
        await tester.scrollUntilVisible(
          deleteBtn,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(deleteBtn, findsOneWidget);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Dialog 1 xuất hiện
        expect(find.text('Xoá tài khoản?'), findsOneWidget);
        expect(find.textContaining('Không thể hoàn tác'), findsOneWidget);

        // Bấm "Tiếp tục" trong Dialog 1
        final continueBtn = find.byKey(const ValueKey('delete-dialog1-continue'));
        expect(continueBtn, findsOneWidget);
        await tester.tap(continueBtn);
        await tester.pumpAndSettle();

        // Dialog 2 xuất hiện
        expect(find.text('Xác nhận xoá vĩnh viễn'), findsOneWidget);
        final confirmBtn = find.byKey(const ValueKey('delete-account-confirm-btn'));
        expect(confirmBtn, findsOneWidget);

        // Nút xoá lúc đầu bị khóa (chưa gõ XOÁ)
        expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull);

        // Gõ chữ "XOÁ"
        final inputField = find.byKey(const ValueKey('delete-account-input'));
        await tester.enterText(inputField, 'XOÁ');
        await tester.pumpAndSettle();

        // Nút xoá đã được bật
        expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNotNull);

        // Bấm "Xoá vĩnh viễn"
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Kiểm tra deleteAccount đã được gọi
        expect(fakeUserRepo.deleteAccountCalled, isTrue);

        // Kiểm tra đăng xuất và về màn login
        expect(fakeAuthRepo.currentUser, isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Đã xoá tài khoản'), findsOneWidget);
      },
    );

    testWidgets(
      'gõ sai chữ thì nút bị khoá, chấp nhận cả xoa thường',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final deleteBtn = find.byKey(const ValueKey('delete-account-button'));
        await tester.scrollUntilVisible(
          deleteBtn,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        // Sang Dialog 2
        await tester.tap(find.byKey(const ValueKey('delete-dialog1-continue')));
        await tester.pumpAndSettle();

        final confirmBtn = find.byKey(const ValueKey('delete-account-confirm-btn'));
        final inputField = find.byKey(const ValueKey('delete-account-input'));

        // Gõ sai
        await tester.enterText(inputField, 'KHONG');
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull);

        await tester.enterText(inputField, 'xoa123');
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNull);

        // Gõ đúng bằng chữ thường không dấu 'xoa'
        await tester.enterText(inputField, 'xoa');
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNotNull);

        // Gõ đúng bằng chữ thường có dấu 'xóa'
        await tester.enterText(inputField, 'xóa');
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(confirmBtn).onPressed, isNotNull);
      },
    );

    testWidgets(
      'lỗi API giữ đăng nhập và hiện SnackBar lỗi',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Thiết lập lỗi cho deleteAccount
        fakeUserRepo.deleteErrorToThrow = const ApiException(
          code: 'NETWORK_ERROR',
          statusCode: 500,
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final deleteBtn = find.byKey(const ValueKey('delete-account-button'));
        await tester.scrollUntilVisible(
          deleteBtn,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('delete-dialog1-continue')));
        await tester.pumpAndSettle();

        final inputField = find.byKey(const ValueKey('delete-account-input'));
        await tester.enterText(inputField, 'XOÁ');
        await tester.pumpAndSettle();

        final confirmBtn = find.byKey(const ValueKey('delete-account-confirm-btn'));
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Kiểm tra deleteAccount đã được gọi
        expect(fakeUserRepo.deleteAccountCalled, isTrue);

        // Vẫn giữ đăng nhập và không sang LoginScreen
        expect(fakeAuthRepo.currentUser, isNotNull);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(ProfileScreen), findsOneWidget);

        // Hiển thị thông báo lỗi thân thiện qua mapErrorMessage
        expect(
          find.text('Không kết nối được máy chủ. Vui lòng kiểm tra kết nối mạng.'),
          findsOneWidget,
        );
      },
    );
  });

  group('Màn kết quả buổi tập (WorkoutResultScreen) - Báo gửi trễ', () {
    testWidgets(
      'countsForStreak == false VÀ durationSec >= 300 (≥ 5 phút) hiện thông báo gửi trễ quá 24 giờ',
      (tester) async {
        final dummySession = SessionView(
          id: 'session-late',
          title: 'Toàn thân',
          durationMin: 15,
          scheduledDate: '2026-10-08',
          scheduledTime: '07:00',
          status: 'completed',
        );

        final dummyResult = WorkoutResult(
          workoutId: 'w-late',
          localDate: '2026-10-08',
          durationSec: 360, // 6 phút (≥ 300s)
          countsForStreak: false,
          personalRecords: const [],
          newAchievements: const [],
        );

        final dummyState = WorkoutSessionState(
          session: dummySession,
          items: const [],
          clientId: 'client-late-1234',
          startedAt: DateTime.now().subtract(const Duration(minutes: 6)),
          endedAt: DateTime.now(),
          result: dummyResult,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeWorkoutProvider.overrideWith(
                (ref) => _TestWorkoutController(ref, dummyState),
              ),
            ],
            child: const MaterialApp(home: WorkoutResultScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Buổi tập đã lưu nhưng không tính vào chỉ tiêu tuần vì gửi lên quá 24 giờ sau khi tập',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Buổi dưới 5 phút không tính streak. Lần sau cố thêm chút nhé!'),
          findsNothing,
        );
        expect(
          find.text('Buổi này được tính vào streak tuần.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'countsForStreak == false VÀ durationSec < 300 (< 5 phút) giữ thông báo buổi dưới 5 phút',
      (tester) async {
        final dummySession = SessionView(
          id: 'session-short',
          title: 'Khởi động',
          durationMin: 5,
          scheduledDate: '2026-10-09',
          scheduledTime: '07:00',
          status: 'completed',
        );

        final dummyResult = WorkoutResult(
          workoutId: 'w-short',
          localDate: '2026-10-09',
          durationSec: 180, // 3 phút (< 300s)
          countsForStreak: false,
          personalRecords: const [],
          newAchievements: const [],
        );

        final dummyState = WorkoutSessionState(
          session: dummySession,
          items: const [],
          clientId: 'client-short-1234',
          startedAt: DateTime.now().subtract(const Duration(minutes: 3)),
          endedAt: DateTime.now(),
          result: dummyResult,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeWorkoutProvider.overrideWith(
                (ref) => _TestWorkoutController(ref, dummyState),
              ),
            ],
            child: const MaterialApp(home: WorkoutResultScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Buổi dưới 5 phút không tính streak. Lần sau cố thêm chút nữa nhé!'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Buổi tập đã lưu nhưng không tính vào chỉ tiêu tuần vì gửi lên quá 24 giờ sau khi tập',
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'countsForStreak == true hiện thông báo được tính vào streak tuần',
      (tester) async {
        final dummySession = SessionView(
          id: 'session-normal',
          title: 'Toàn thân',
          durationMin: 15,
          scheduledDate: '2026-10-09',
          scheduledTime: '07:00',
          status: 'completed',
        );

        final dummyResult = WorkoutResult(
          workoutId: 'w-normal',
          localDate: '2026-10-09',
          durationSec: 600, // 10 phút
          countsForStreak: true,
          personalRecords: const [],
          newAchievements: const [],
        );

        final dummyState = WorkoutSessionState(
          session: dummySession,
          items: const [],
          clientId: 'client-normal-1234',
          startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          endedAt: DateTime.now(),
          result: dummyResult,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeWorkoutProvider.overrideWith(
                (ref) => _TestWorkoutController(ref, dummyState),
              ),
            ],
            child: const MaterialApp(home: WorkoutResultScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Buổi này được tính vào streak tuần.'),
          findsOneWidget,
        );
      },
    );
  });
}
