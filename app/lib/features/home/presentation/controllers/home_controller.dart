import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';

final homePlanProvider = FutureProvider.autoDispose<PlanView>((ref) async {
  final repo = ref.watch(planRepositoryProvider);
  return repo.getCurrentPlan();
});
