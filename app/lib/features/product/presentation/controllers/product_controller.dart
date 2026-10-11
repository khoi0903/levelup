import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_product_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/services/billing_service.dart';
import '../../domain/models/product_models.dart';
import '../../../users/presentation/controllers/user_controller.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ApiProductRepository(ref.watch(apiClientProvider)),
);
final billingServiceProvider = Provider<BillingService>(
  (ref) => FakeBillingService(),
);
final referralViewProvider = FutureProvider.autoDispose<ReferralView>(
  (ref) => ref.watch(productRepositoryProvider).getReferral(),
);
final adminConfigProvider = FutureProvider.autoDispose<ProductConfig>(
  (ref) => ref.watch(productRepositoryProvider).getConfig(),
);

bool canRedeemReferral(WidgetRef ref) {
  final me = ref.watch(currentUserProvider);
  return me != null &&
      me.subscription.enabled &&
      me.productConfig.referralEnabled &&
      me.referralRedeemEligible;
}
