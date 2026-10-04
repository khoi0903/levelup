import 'package:fitness_app/features/buddies/data/repositories/fake_buddy_repository.dart';
import 'package:fitness_app/features/buddies/presentation/controllers/buddy_controller.dart';
import 'package:fitness_app/features/buddies/presentation/screens/buddy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BuddyFlow (F5)', () {
    testWidgets('Renders paired buddy screen, displays status, and sends cheer', (tester) async {
      final fakeRepo = FakeBuddyRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            buddyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: BuddyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bạn đồng hành (Buddy)'), findsOneWidget);
      expect(find.text('Lan'), findsOneWidget);
      expect(find.text('Chờ tập'), findsOneWidget);
      expect(find.textContaining('Toàn thân 15 phút'), findsOneWidget);
      expect(find.text('Cổ vũ 🔥'), findsOneWidget);

      // Tap 'Cổ vũ 🔥'
      await tester.tap(find.text('Cổ vũ 🔥'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastActionType, 'cheer');
      expect(find.text('Đã cổ vũ'), findsOneWidget);
    });

    testWidgets('Renders unpaired view, creates invite code and joins pair', (tester) async {
      final fakeRepo = FakeBuddyRepository();
      fakeRepo.todayResponse = null;
      fakeRepo.isPairLeft = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            buddyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: BuddyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tập luyện cùng bạn bè'), findsOneWidget);
      expect(find.text('Tạo mã mời của bạn'), findsOneWidget);

      // Tap create invite
      await tester.tap(find.text('Tạo mã mời của bạn'));
      await tester.pumpAndSettle();

      expect(find.text('LV8899'), findsOneWidget);
      expect(find.text('Sao chép tin nhắn mời'), findsOneWidget);

      // Scroll to join section, enter code and join
      await tester.ensureVisible(find.text('Ghép cặp ngay'));
      await tester.enterText(find.byType(TextField), 'LV7788');
      await tester.tap(find.text('Ghép cặp ngay'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastJoinCode, 'LV7788');
    });

    testWidgets('Leave pair confirms and removes buddy', (tester) async {
      final fakeRepo = FakeBuddyRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            buddyRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: BuddyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Lan'), findsOneWidget);

      // Scroll down to find 'Rời khỏi cặp đồng hành'
      await tester.ensureVisible(find.text('Rời khỏi cặp đồng hành'));
      await tester.tap(find.text('Rời khỏi cặp đồng hành'));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Rời khỏi cặp đồng hành?'), findsOneWidget);
      await tester.tap(find.text('Rời cặp'));
      await tester.pumpAndSettle();

      expect(fakeRepo.isPairLeft, isTrue);
    });
  });
}
