import 'package:fitness_app/features/skip_report/data/repositories/fake_skip_report_repository.dart';
import 'package:fitness_app/features/skip_report/presentation/controllers/skip_report_controller.dart';
import 'package:fitness_app/features/skip_report/presentation/screens/skip_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkipReportFlow (F3)', () {
    testWidgets('Selects pain reason, chooses knee area, submits and displays coach reply', (tester) async {
      final fakeRepo = FakeSkipReportRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            skipReportRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SkipReportScreen(sessionId: 'sess-123'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Không tập được hôm nay'), findsOneWidget);
      expect(find.text('Đau / Khó chịu vùng cơ thể'), findsOneWidget);

      // Scroll and select 'Đau / Khó chịu vùng cơ thể'
      await tester.ensureVisible(find.text('Đau / Khó chịu vùng cơ thể'));
      await tester.tap(find.text('Đau / Khó chịu vùng cơ thể'));
      await tester.pumpAndSettle();

      // Pain areas should appear
      expect(find.text('Chọn vùng bị đau / khó chịu'), findsOneWidget);
      expect(find.text('Khớp gối'), findsOneWidget);

      // Select 'Khớp gối'
      await tester.ensureVisible(find.text('Khớp gối'));
      await tester.tap(find.text('Khớp gối'));
      await tester.pumpAndSettle();

      // Tap submit button
      await tester.ensureVisible(find.text('Gửi cho Coach & Điều chỉnh kế hoạch'));
      await tester.tap(find.text('Gửi cho Coach & Điều chỉnh kế hoạch'));
      await tester.pumpAndSettle();

      // Check results
      expect(find.text('Coach đã tiếp nhận!'), findsOneWidget);
      expect(
        find.text('Mình đã đổi sang bài an toàn cho vùng đau. Nếu đau kéo dài, bạn nên đi khám nhé.'),
        findsOneWidget,
      );
      expect(find.text('Về trang chủ'), findsOneWidget);

      expect(fakeRepo.lastSkipRequest?.reason, 'pain');
      expect(fakeRepo.lastSkipRequest?.bodyArea, 'knee');
      expect(fakeRepo.lastSkipRequest?.plannedSessionId, 'sess-123');
    });

    testWidgets('Quick action: Nghỉ hôm nay triggers patchSession with rest action', (tester) async {
      final fakeRepo = FakeSkipReportRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            skipReportRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: SkipReportScreen(sessionId: 'sess-456'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nghỉ hôm nay'), findsOneWidget);

      // Tap 'Nghỉ hôm nay'
      await tester.tap(find.text('Nghỉ hôm nay'));
      await tester.pumpAndSettle();

      expect(find.text('Coach đã tiếp nhận!'), findsOneWidget);
      expect(find.text('Kế hoạch buổi tập đã được cập nhật thành công!'), findsOneWidget);

      expect(fakeRepo.lastPatchRequest?.action, 'rest');
    });
  });
}
