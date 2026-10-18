import 'package:fitness_app/features/food_review/domain/models/food_candidate.dart';
import 'package:fitness_app/features/food_review/domain/repositories/food_review_repository.dart';
import 'package:fitness_app/features/food_review/presentation/controllers/food_review_controller.dart';
import 'package:fitness_app/features/food_review/presentation/screens/food_review_screen.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../product/product_flow_test.dart' show me;

class FakeFoodReviewRepository implements FoodReviewRepository {
  List<FoodCandidate> items = [
    FoodCandidate.fromJson({
      'id': 'c1',
      'nameVi': 'Trà dâu kem cheese',
      'userCount': 6,
      'sightings': 9,
      'saves': 4,
      'readyForReview': true,
      'suggested': {'kcal': 80, 'proteinG': 1.2, 'carbsG': 12, 'fatG': 2.4},
      'typicalGrams': 500,
    }),
  ];
  final approved = <String, ApproveFood>{};
  final rejected = <String>[];

  @override
  Future<List<FoodCandidate>> pending() async => items
      .where((e) => !approved.containsKey(e.id) && !rejected.contains(e.id))
      .toList();
  @override
  Future<void> approve(String id, ApproveFood food) async => approved[id] = food;
  @override
  Future<void> reject(String id) async => rejected.add(id);
}

Future<void> mountReview(
  WidgetTester tester,
  FakeFoodReviewRepository repo, {
  bool admin = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => me(admin: admin)),
        foodReviewRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: FoodReviewScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('non-admin sees not found', (tester) async {
    await mountReview(tester, FakeFoodReviewRepository(), admin: false);
    expect(find.text('Không tìm thấy trang'), findsOneWidget);
  });

  testWidgets('approve prefills one serving from per-100 g suggestion', (
    tester,
  ) async {
    final repo = FakeFoodReviewRepository();
    await mountReview(tester, repo);
    expect(find.text('Trà dâu kem cheese'), findsOneWidget);
    expect(find.textContaining('6 người'), findsOneWidget);
    expect(find.textContaining('nên duyệt'), findsOneWidget);
    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thêm vào kho'));
    await tester.tap(find.text('Thêm vào kho'));
    await tester.pumpAndSettle();
    final food = repo.approved['c1']!;
    expect(food.servingGrams, 500);
    expect(food.kcal, 400);
    expect(food.proteinG, 6);
    expect(food.carbsG, 60);
    expect(food.fatG, 12);
    expect(food.category, 'do_uong');
    expect(find.text('Chưa có món nào chờ duyệt.'), findsOneWidget);
  });

  testWidgets('reject removes candidate', (tester) async {
    final repo = FakeFoodReviewRepository();
    await mountReview(tester, repo);
    await tester.tap(find.text('Bỏ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(repo.rejected, isEmpty);
    await tester.tap(find.text('Bỏ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ món'));
    await tester.pumpAndSettle();
    expect(repo.rejected, ['c1']);
    expect(find.text('Chưa có món nào chờ duyệt.'), findsOneWidget);
  });
}
