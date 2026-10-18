import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_food_review_repository.dart';
import '../../domain/models/food_candidate.dart';
import '../../domain/repositories/food_review_repository.dart';

final foodReviewRepositoryProvider = Provider<FoodReviewRepository>(
  (ref) => ApiFoodReviewRepository(ref.watch(apiClientProvider)),
);

final pendingFoodsProvider = FutureProvider.autoDispose<List<FoodCandidate>>(
  (ref) => ref.watch(foodReviewRepositoryProvider).pending(),
);
