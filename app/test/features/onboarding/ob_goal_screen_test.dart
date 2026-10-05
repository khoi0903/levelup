import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/auth/presentation/screens/login_screen.dart';
import 'package:fitness_app/features/notifications/data/services/fake_push_service.dart';
import 'package:fitness_app/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObGoalScreen account info and switch account', () {
    testWidgets(
      'Displays current user email and tapping "Đổi tài khoản" calls signOut',
      (tester) async {
        final fakeAuth = FakeAuthRepository(
          initialUser: const AuthUser(
            id: 'user-123',
            email: 'khoi@levelup.vn',
            displayName: 'Dinh Khoi',
          ),
        );
        final fakePush = FakePushService();

        final router = createAppRouter(initialLocation: '/onboarding/goal');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeAuth),
              pushServiceProvider.overrideWithValue(fakePush),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Check current email displayed
        expect(
          find.byKey(const ValueKey('ob-logged-in-email-text')),
          findsOneWidget,
        );
        expect(find.textContaining('khoi@levelup.vn'), findsOneWidget);

        // Check change account button
        final changeBtn = find.byKey(
          const ValueKey('ob-change-account-button'),
        );
        expect(changeBtn, findsOneWidget);
        expect(find.text('Đổi tài khoản'), findsOneWidget);

        // Tap change account
        await tester.tap(changeBtn);
        await tester.pumpAndSettle();

        // Verify signOut was called
        expect(fakeAuth.signOutCalled, isTrue);

        // Verify navigated to login screen
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.text('Đồng hành rèn luyện & duy trì thói quen'),
          findsOneWidget,
        );
      },
    );
  });
}
