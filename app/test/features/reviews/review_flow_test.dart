import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/reviews/data/repositories/fake_review_repository.dart';
import 'package:fitness_app/features/reviews/presentation/controllers/review_controller.dart';
import 'package:fitness_app/features/reviews/presentation/screens/review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReviewFlow (F6)', () {
    testWidgets('Renders latest review stats, wins, and accepts plan proposal', (tester) async {
      final fakeRepo = FakeReviewRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tổng kết tuần'), findsOneWidget);
      expect(find.text('Hoàn thành 100% mục tiêu tuần đầu tiên!'), findsOneWidget);
      expect(find.text('Duy trì streak 1 tuần'), findsOneWidget);
      expect(find.text('Kỷ lục 15 lần Squat liên tục'), findsOneWidget);
      expect(find.text('Đồng ý kế hoạch đề xuất'), findsOneWidget);

      // Tap 'Đồng ý kế hoạch đề xuất'
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý kế hoạch đề xuất'));
      await tester.pumpAndSettle();

      expect(find.text('Đã xác nhận kế hoạch tuần tới!'), findsOneWidget);
      expect(fakeRepo.lastDecisionRequest?.decision, 'accepted');
    });

    testWidgets('Displays EmptyView when there is no latest review', (tester) async {
      final fakeRepo = FakeReviewRepository(
        errorToThrow: const ApiException(code: 'NO_REVIEW'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chưa có tổng kết tuần'), findsOneWidget);
      expect(
        find.text('Hệ thống sẽ tự động tổng kết sau khi bạn kết thúc tuần tập luyện.'),
        findsOneWidget,
      );
    });
  });
}
