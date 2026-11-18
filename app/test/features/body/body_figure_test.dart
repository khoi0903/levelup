import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/features/body/domain/models/body_models.dart';
import 'package:fitness_app/features/body/domain/models/body_shape.dart';
import 'package:fitness_app/features/body/presentation/widgets/body_figure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<double> _dims(BodyShape s) => [
  s.shoulder,
  s.chest,
  s.waist,
  s.hip,
  s.thigh,
  s.arm,
];

void main() {
  group('BodyShape', () {
    test('mọi số đo tăng đều theo BMI (giữ nguyên tỉ lệ mỡ)', () {
      for (final female in [false, true]) {
        var prev = _dims(
          BodyShape.from(bmi: 14, bodyFatPct: 20, female: female),
        );
        for (var bmi = 15.0; bmi <= 42; bmi += 1) {
          final cur = _dims(
            BodyShape.from(bmi: bmi, bodyFatPct: 20, female: female),
          );
          for (var i = 0; i < cur.length; i++) {
            expect(
              cur[i],
              greaterThanOrEqualTo(prev[i]),
              reason: 'bmi=$bmi i=$i',
            );
          }
          prev = cur;
        }
        expect(
          BodyShape.from(bmi: 30, bodyFatPct: 20, female: female).waist,
          greaterThan(
            BodyShape.from(bmi: 20, bodyFatPct: 20, female: female).waist,
          ),
        );
      }
    });

    test('mọi số đo tăng đều theo tỉ lệ mỡ (giữ nguyên BMI)', () {
      var prev = _dims(BodyShape.from(bmi: 23, bodyFatPct: 3));
      for (var fat = 4; fat <= 55; fat++) {
        final cur = _dims(BodyShape.from(bmi: 23, bodyFatPct: fat));
        for (var i = 0; i < cur.length; i++) {
          expect(
            cur[i],
            greaterThanOrEqualTo(prev[i]),
            reason: 'fat=$fat i=$i',
          );
        }
        prev = cur;
      }
      expect(
        BodyShape.from(bmi: 23, bodyFatPct: 36).waist,
        greaterThan(BodyShape.from(bmi: 23, bodyFatPct: 12).waist),
      );
    });

    test('giá trị ngoài khoảng bị chặn, thiếu dữ liệu vẫn vẽ được', () {
      expect(
        _dims(BodyShape.from(bmi: 80, bodyFatPct: 90)),
        _dims(BodyShape.from(bmi: 38, bodyFatPct: 50)),
      );
      expect(
        _dims(BodyShape.from(bmi: 5, bodyFatPct: 0)),
        _dims(BodyShape.from(bmi: 16, bodyFatPct: 5)),
      );
      final unknown = BodyShape.from();
      expect(unknown.waist, greaterThan(0));
      // Hình to nhất vẫn nằm gọn trong khung vẽ
      final widest = BodyGeometry(
        BodyShape.from(bmi: 38, bodyFatPct: 50),
        BodySide.front,
      );
      for (final part in widest.silhouette) {
        final b = part.getBounds();
        expect(b.left, greaterThan(-BodyGeometry.aspect / 2));
        expect(b.right, lessThan(BodyGeometry.aspect / 2));
        expect(b.top, greaterThanOrEqualTo(0));
        expect(b.bottom, lessThanOrEqualTo(1));
      }
    });

    test('mức vóc dáng gợi ý theo giới tính', () {
      expect(bodyFatPresets(female: false), [12, 18, 24, 30, 36]);
      expect(bodyFatPresets(female: true), [20, 26, 32, 38, 44]);
      expect(nearestBodyFatPreset(19, female: false), 18);
      expect(nearestBodyFatPreset(null, female: false), isNull);
      expect(computeBmi(170, 68)!, closeTo(23.53, 0.01));
      expect(computeBmi(null, 68), isNull);
    });
  });

  group('BodyGeometry bắt chạm', () {
    for (final shape in [
      BodyShape.from(bmi: 18, bodyFatPct: 12),
      BodyShape.from(bmi: 24, bodyFatPct: 26, female: true),
      BodyShape.from(bmi: 36, bodyFatPct: 44, female: true),
    ]) {
      test('mặt trước/sau trả đúng nhóm cơ (eo ${shape.waist})', () {
        final front = BodyGeometry(shape, BodySide.front);
        final back = BodyGeometry(shape, BodySide.back);

        expect(front.muscles.keys.toSet(), BodyGeometry.frontMuscles.toSet());
        expect(back.muscles.keys.toSet(), BodyGeometry.backMuscles.toSet());

        expect(front.muscleAt(const Offset(0.03, 0.23)), 'chest');
        expect(front.muscleAt(const Offset(-0.03, 0.23)), 'chest');
        expect(front.muscleAt(const Offset(0, 0.37)), 'abs');
        expect(back.muscleAt(const Offset(0, 0.28)), 'back');
        expect(back.muscleAt(const Offset(0.03, 0.48)), 'glutes');
        expect(back.muscleAt(const Offset(-0.03, 0.48)), 'glutes');

        for (final g in [front, back]) {
          final knee = g.painSpots['knee']!.first;
          expect(g.muscleAt(Offset(knee.dx, 0.62)), 'legs');
          expect(g.muscleAt(Offset(-knee.dx, 0.62)), 'legs');
          final shoulder = g.painSpots['shoulder']!.first;
          expect(g.muscleAt(shoulder), 'shoulders');
          final wrist = g.painSpots['wrist']!.first;
          expect(g.muscleAt(Offset(wrist.dx, wrist.dy - 0.04)), 'arms');
          // Ngoài hình, đầu: không trúng nhóm cơ nào
          expect(g.muscleAt(const Offset(0.24, 0.8)), isNull);
          expect(g.muscleAt(const Offset(0, 0.06)), isNull);
          expect(g.muscleAt(const Offset(0, 0.99)), isNull);
        }
      });

      test('điểm đau: trúng đúng vùng, cả hai bên (eo ${shape.waist})', () {
        final g = BodyGeometry(shape, BodySide.front);
        expect(g.painSpots.keys.toSet(), kPainAreas.toSet());
        g.painSpots.forEach((id, centers) {
          for (final c in centers) {
            expect(g.painAt(c), id);
            expect(g.painAt(c + const Offset(0.01, 0.008)), id);
          }
        });
        expect(g.painAt(const Offset(0, 0.60)), isNull);
        expect(g.painAt(const Offset(0.25, 0.05)), isNull);
      });
    }

    test('đổi toạ độ màn hình <-> chuẩn hoá khớp nhau', () {
      const size = Size(208, 400);
      const p = Offset(0.05, 0.37);
      final local = BodyGeometry.toLocal(p, size);
      final back = BodyGeometry.toNormalized(local, size);
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
      expect(BodyGeometry.toLocal(Offset.zero, size).dx, 104);
    });
  });

  group('BodyFigure widget', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(child: SizedBox(height: 400, child: child)),
        ),
      ),
    );

    Offset at(WidgetTester tester, Finder figure, Offset normalized) {
      final box = tester.renderObject<RenderBox>(figure);
      return box.localToGlobal(BodyGeometry.toLocal(normalized, box.size));
    }

    testWidgets('chọn nhóm cơ: chạm vào bụng và chân báo đúng tên', (
      tester,
    ) async {
      final taps = <String>[];
      await pump(
        tester,
        BodyFigure(
          shape: BodyShape.from(bmi: 23, bodyFatPct: 20),
          mode: BodyFigureMode.selectMuscles,
          onToggle: taps.add,
        ),
      );
      final figure = find.byType(BodyFigure);
      await tester.tapAt(at(tester, figure, const Offset(0, 0.37)));
      await tester.tapAt(at(tester, figure, const Offset(0.03, 0.23)));
      await tester.tapAt(at(tester, figure, const Offset(0.24, 0.9)));
      expect(taps, ['abs', 'chest']);
    });

    testWidgets('chọn vùng đau: chạm vào gối và cổ', (tester) async {
      final taps = <String>[];
      final shape = BodyShape.from(bmi: 23, bodyFatPct: 20);
      await pump(
        tester,
        BodyFigure(
          shape: shape,
          mode: BodyFigureMode.selectPain,
          selected: const {'knee'},
          onToggle: taps.add,
        ),
      );
      final g = BodyGeometry(shape, BodySide.front);
      final figure = find.byType(BodyFigure);
      await tester.tapAt(at(tester, figure, g.painSpots['knee']!.last));
      await tester.tapAt(at(tester, figure, g.painSpots['neck']!.first));
      expect(taps, ['knee', 'neck']);
    });

    testWidgets('chế độ hiển thị và heat không nhận chạm, vẽ không lỗi', (
      tester,
    ) async {
      final taps = <String>[];
      for (final mode in [BodyFigureMode.display, BodyFigureMode.heat]) {
        for (final side in BodySide.values) {
          await pump(
            tester,
            BodyFigure(
              shape: BodyShape.from(bmi: 30, bodyFatPct: 38, female: true),
              side: side,
              mode: mode,
              heat: const {'legs': 1, 'abs': 0.4},
              onToggle: taps.add,
            ),
          );
          await tester.tapAt(tester.getCenter(find.byType(BodyFigure)));
          expect(tester.takeException(), isNull);
        }
      }
      expect(taps, isEmpty);
    });

    testWidgets('MuscleMapPicker: đổi mặt trước/sau, chip chọn được mọi nhóm', (
      tester,
    ) async {
      final selected = <String>{};
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: MuscleMapPicker(
                  shape: BodyShape.from(),
                  selected: selected,
                  onToggle: (m) => setState(() {
                    if (!selected.remove(m)) selected.add(m);
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      AnatomyMap figure() => tester.widget<AnatomyMap>(
        find.byKey(const ValueKey('muscle-map-figure')),
      );
      expect(figure().side, BodySide.front);

      await tester.tap(find.byKey(const ValueKey('body-side-back')));
      await tester.pump();
      expect(figure().side, BodySide.back);

      // Chạm vào lưng trên hình mặt sau
      final box = tester.renderObject<RenderBox>(
        find.byKey(const ValueKey('muscle-map-figure')),
      );
      await tester.tapAt(
        box.localToGlobal(
          BodyGeometry.toLocal(const Offset(0, 0.28), box.size),
        ),
      );
      await tester.pump();
      expect(selected, {'back'});

      await tester.tap(find.byKey(const ValueKey('body-side-front')));
      await tester.pump();
      expect(figure().side, BodySide.front);
      expect(figure().selected, {'back'});

      await tester.tap(find.byKey(const ValueKey('muscle-chip-glutes')));
      await tester.tap(find.byKey(const ValueKey('muscle-chip-back')));
      await tester.pump();
      expect(selected, {'glutes'});
    });

    testWidgets('PainMapPicker: "Không đau chỗ nào" xoá hết lựa chọn', (
      tester,
    ) async {
      final selected = <String>{'knee'};
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: PainMapPicker(
                  shape: BodyShape.from(),
                  selected: selected,
                  onToggle: (m) => setState(() {
                    if (!selected.remove(m)) selected.add(m);
                  }),
                  onClear: () => setState(selected.clear),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pain-chip-other')));
      await tester.tap(find.byKey(const ValueKey('pain-chip-wrist')));
      await tester.pump();
      expect(selected, {'knee', 'other', 'wrist'});
      await tester.tap(find.byKey(const ValueKey('pain-chip-none')));
      await tester.pump();
      expect(selected, isEmpty);
    });

    testWidgets('BodyShapePicker: 5 hình, chạm trả về mức đã chọn', (
      tester,
    ) async {
      int? picked;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: BodyShapePicker(
              bmi: 22,
              female: true,
              selectedPct: null,
              onSelected: (v) => picked = v,
            ),
          ),
        ),
      );
      expect(find.byType(BodyFigure), findsNWidgets(5));
      await tester.tap(find.byKey(const ValueKey('body-shape-32')));
      expect(picked, 32);
    });
  });

  group('AnatomyMap (bản đồ cơ chi tiết)', () {
    test('mỗi mặt có đủ nhóm cơ, chạm cơ con nào cũng ra đúng nhóm', () {
      for (final female in [false, true]) {
        final front = AnatomyArt.of(female: female, side: BodySide.front);
        final back = AnatomyArt.of(female: female, side: BodySide.back);
        expect(front.groups, {'chest', 'shoulders', 'arms', 'abs', 'legs'});
        expect(back.groups, {'back', 'shoulders', 'arms', 'glutes', 'legs'});
        expect(
          identical(front, AnatomyArt.of(female: female, side: BodySide.front)),
          isTrue,
          reason: 'hình chỉ dựng một lần',
        );
        for (final art in [front, back]) {
          for (final part in art.parts) {
            final b = part.bounds;
            expect(b.top, greaterThanOrEqualTo(0));
            expect(b.bottom, lessThanOrEqualTo(1));
            expect(b.left, greaterThanOrEqualTo(-AnatomyArt.aspect / 2));
            expect(b.right, lessThanOrEqualTo(AnatomyArt.aspect / 2));
          }
          final ob = art.outline.getBounds();
          expect(ob.left, greaterThanOrEqualTo(-AnatomyArt.aspect / 2));
          expect(ob.right, lessThanOrEqualTo(AnatomyArt.aspect / 2));
          for (final area in kPainAreas) {
            final spots = art.painSpots[area]!;
            expect(spots, isNotEmpty, reason: area);
            for (final s in spots) {
              expect(art.painAt(s), area);
            }
          }
          expect(art.painAt(const Offset(0.25, 0.02)), isNull);
          expect(art.muscleAt(const Offset(0.25, 0.02)), isNull);
        }
        // Tâm của từng cơ gốc thuộc về nhóm của nó.
        String? at(AnatomyArt art, String slug) => art.muscleAt(
          art.parts.firstWhere((p) => p.slug == slug).bounds.center,
        );
        expect(at(front, 'abs'), 'abs');
        expect(at(back, 'gluteal'), 'glutes');
        // Khe giữa hai bên vẫn bắt được nhóm gần nhất.
        expect(front.muscleAt(const Offset(0, 0.26)), 'chest');
        expect(front.muscleAt(const Offset(0, 0.36)), 'abs');
        expect(back.muscleAt(const Offset(0, 0.28)), 'back');
      }
    });

    testWidgets('chạm vào ngực chọn nhóm ngực, heat không nhận chạm', (
      tester,
    ) async {
      final taps = <String>[];
      for (final mode in [BodyFigureMode.selectMuscles, BodyFigureMode.heat]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  height: 400,
                  child: AnatomyMap(
                    female: false,
                    mode: mode,
                    selected: const {'legs'},
                    heat: const {'legs': 1, 'abs': 0.4},
                    onToggle: taps.add,
                  ),
                ),
              ),
            ),
          ),
        );
        final box = tester.renderObject<RenderBox>(find.byType(AnatomyMap));
        final art = AnatomyArt.of(female: false, side: BodySide.front);
        final chest = art.parts.firstWhere((p) => p.slug == 'chest');
        // Mảng ngực gồm hai bên; lấy điểm giữa nửa trái.
        final p = Offset(
          chest.bounds.left + chest.bounds.width * 0.25,
          chest.bounds.center.dy,
        );
        await tester.tapAt(box.localToGlobal(AnatomyArt.toLocal(p, box.size)));
        expect(tester.takeException(), isNull);
      }
      expect(taps, ['chest']);
    });
  });

  group('Mô hình dữ liệu', () {
    test('BodyStats.fromJson chịu được trường null', () {
      final s = BodyStats.fromJson({
        'gender': 'female',
        'heightCm': 160,
        'weightKg': 52.5,
        'bmi': 20.5,
        'bmiCategory': 'normal',
        'bodyFatPct': 26,
        'bodyFatEstimated': true,
        'bmr': 1250.4,
        'tdee': null,
        'focusMuscles': ['glutes', 'abs', 'khong_co'],
      });
      expect(s.female, isTrue);
      expect(s.weightKg, 52.5);
      expect(s.bmr, 1250);
      expect(s.tdee, isNull);
      expect(s.bodyFatEstimated, isTrue);
      expect(s.focusMuscles, ['glutes', 'abs']);
      expect(BodyStats.fromJson(const {}).shape.waist, greaterThan(0));
    });

    test('MuscleWeek: heat chia theo nhóm tập nhiều nhất', () {
      final w = MuscleWeek.fromJson({
        'weekStart': '2026-11-09',
        'muscles': {'legs': 12, 'abs': 6, 'chest': 0},
      });
      expect(w.heat['legs'], 1);
      expect(w.heat['abs'], 0.5);
      expect(w.heat['chest'], 0);
      expect(w.heat['back'], 0);
      expect(w.isEmpty, isFalse);
      expect(MuscleWeek.fromJson(const {}).isEmpty, isTrue);
      expect(MuscleWeek.fromJson(const {}).heat['legs'], 0);
    });
  });
}
