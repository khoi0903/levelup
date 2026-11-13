import 'package:fitness_app/core/tutorial/tutorial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Demo extends ConsumerStatefulWidget {
  const _Demo();
  @override
  ConsumerState<_Demo> createState() => _DemoState();
}

class _DemoState extends ConsumerState<_Demo> {
  final a = GlobalKey(), b = GlobalKey(), missing = GlobalKey();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: TutorialGate(
      id: 'demo',
      steps: [
        TutorialStep(key: a, title: 'Bước A', text: 'Giải thích A'),
        TutorialStep(key: missing, title: 'Không có', text: 'Bị bỏ qua'),
        TutorialStep(key: b, title: 'Bước B', text: 'Giải thích B'),
      ],
      child: Column(
        children: [
          Text('Nút A', key: a),
          Text('Nút B', key: b),
          TextButton(
            onPressed: () => replayTutorials(ref),
            child: const Text('Xem lại hướng dẫn'),
          ),
        ],
      ),
    ),
  );
}

Future<void> pumpDemo(WidgetTester tester, {bool? enabled}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (enabled != null) tutorialEnabledProvider.overrideWithValue(enabled),
      ],
      child: const MaterialApp(home: _Demo()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const flag = '${tutorialPrefsPrefix}demo';
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('mặc định tắt trong widget test', (tester) async {
    await pumpDemo(tester);
    expect(find.text('Bước A'), findsNothing);
  });

  testWidgets('hiện từng bước, bỏ qua widget chưa dựng, chỉ hiện một lần', (
    tester,
  ) async {
    await pumpDemo(tester, enabled: true);
    expect(find.text('Bước A'), findsOneWidget);
    expect(find.text('Giải thích A'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Bước B'), findsOneWidget);
    expect(find.text('Bỏ qua'), findsNothing);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.text('Bước B'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(flag), isTrue);

    // Mở lại màn: không hiện nữa
    await tester.pumpWidget(const SizedBox());
    await pumpDemo(tester, enabled: true);
    expect(find.text('Bước A'), findsNothing);
  });

  testWidgets('"Bỏ qua" đóng hướng dẫn, replayTutorials cho hiện lại', (
    tester,
  ) async {
    await pumpDemo(tester, enabled: true);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.text('Bước A'), findsNothing);

    await tester.tap(find.text('Xem lại hướng dẫn'));
    await tester.pumpAndSettle();
    expect(find.text('Bước A'), findsOneWidget);
  });

  testWidgets('đã có cờ thì không hiện', (tester) async {
    SharedPreferences.setMockInitialValues({flag: true});
    await pumpDemo(tester, enabled: true);
    expect(find.text('Bước A'), findsNothing);
  });
}
