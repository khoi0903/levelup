import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tỉ lệ tương phản WCAG giữa hai màu.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _blend(Color fg, Color bg) =>
    Color.alphaBlend(fg, bg.withValues(alpha: 1));

/// Màu nền gần nhất phía sau một đoạn chữ (bỏ qua lớp phủ mờ). Không có thì
/// lấy nền Scaffold của theme đang áp cho đoạn chữ đó.
Color _backgroundOf(Element e) {
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
    } else if (w is Scaffold) {
      c = w.backgroundColor;
    }
    if (c != null && c.a >= 0.5) {
      found = c;
      return false;
    }
    return true;
  });
  return found ?? Theme.of(e).scaffoldBackgroundColor;
}

bool _isEmojiOnly(String s) => s.runes.every((r) => r > 0x2000);

/// Mọi chữ đang dựng phải đọc được trên nền ngay sau nó (≥ 3:1, đủ để bắt
/// lỗi chữ trắng trên nền trắng hay chữ tối trên nền tối).
void expectReadableText(WidgetTester tester, {String where = ''}) {
  final problems = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final rich = element.widget as RichText;
    final bg = _backgroundOf(element);
    void check(InlineSpan span, Color? inherited) {
      final color = span.style?.color ?? inherited;
      if (span is TextSpan) {
        final text = span.text?.trim() ?? '';
        if (color != null && text.isNotEmpty && !_isEmojiOnly(text)) {
          final ratio = contrastRatio(_blend(color, bg), bg);
          if (ratio < 3.0) {
            problems.add(
              '$where "$text" ${ratio.toStringAsFixed(2)}:1 '
              '(chữ $color, nền $bg)',
            );
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
Future<void> scrollAndCheckReadable(
  WidgetTester tester, {
  String where = '',
}) async {
  expectReadableText(tester, where: where);
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  for (var i = 0; i < 12; i++) {
    await tester.drag(
      scrollable.first,
      const Offset(0, -500),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expectReadableText(tester, where: where);
  }
}
