import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/checkins/data/repositories/fake_checkin_repository.dart';
import 'package:fitness_app/features/checkins/presentation/controllers/checkin_controller.dart';
import 'package:fitness_app/features/checkins/presentation/screens/checkin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CheckinFlow (F2)', () {
    testWidgets('Select tired energy and sleep, submit checkin, shows adjusted session', (tester) async {
      final fakeRepo = FakeCheckinRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkinRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: CheckinScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chào buổi sáng! Hôm nay bạn cảm thấy thế nào?'), findsOneWidget);
      expect(find.text('Tràn đầy năng lượng'), findsOneWidget);
      expect(find.text('Mệt mỏi / Uể oải'), findsOneWidget);

      // Select "Mệt mỏi / Uể oải"
      await tester.tap(find.text('Mệt mỏi / Uể oải'));
      await tester.pump();

      // Select sleep "> 8 giờ"
      await tester.tap(find.text('> 8 giờ'));
      await tester.pump();

      // Tap "Xác nhận check-in"
      await tester.tap(find.text('Xác nhận check-in'));
      await tester.pumpAndSettle();

      // Result screen should be visible
      expect(find.text('Đã hoàn thành check-in!'), findsOneWidget);
      expect(find.text('Coach đã điều chỉnh buổi tập hôm nay cho bạn.'), findsOneWidget);
      expect(find.text('Toàn thân nhẹ nhàng (Đã giảm hiệp)'), findsOneWidget);
      expect(find.text('Bắt đầu tập buổi này'), findsOneWidget);
      expect(find.text('Về trang chủ'), findsOneWidget);

      expect(fakeRepo.lastRequest?.energy, 'tired');
      expect(fakeRepo.lastRequest?.sleep, 'gt8');
    });

    testWidgets('Displays friendly error when already checked in', (tester) async {
      final fakeRepo = FakeCheckinRepository(
        errorToThrow: const ApiException(code: 'ALREADY_CHECKED_IN'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkinRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: CheckinScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Xác nhận check-in'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('checkin-error-text')), findsOneWidget);
      expect(find.text('Bạn đã check-in cho ngày hôm nay rồi.'), findsOneWidget);
    });
  });
}
