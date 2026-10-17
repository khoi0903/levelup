import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../auth/domain/models/auth_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/repositories/api_product_repository.dart';
import '../../domain/models/product_models.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/services/billing_service.dart';
import '../../domain/services/revenue_cat_billing_service.dart';
import '../../../users/presentation/controllers/user_controller.dart';

import '../../../../core/utils/cache_for_extension.dart';

const revenueCatAndroidKey =
    String.fromEnvironment('REVENUECAT_ANDROID_KEY');

bool isRevenueCatSupported({
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
  String key = revenueCatAndroidKey,
}) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  return !isWeb &&
      targetPlatform == TargetPlatform.android &&
      key.isNotEmpty;
}

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ApiProductRepository(ref.watch(apiClientProvider)),
);

final billingServiceProvider = Provider<BillingService>((ref) {
  if (isRevenueCatSupported()) {
    final service = RevenueCatBillingService(ref, apiKey: revenueCatAndroidKey);
    ref.listen<AsyncValue<AuthUser?>>(
      authStateChangesProvider,
      (previous, next) {
        final uid = next.valueOrNull?.id;
        service.onAuthChanged(uid);
      },
      fireImmediately: true,
    );
    return service;
  }
  return FakeBillingService();
});

final proPricesProvider =
    FutureProvider.autoDispose<Map<BillingPeriod, String>>((ref) {
  final billing = ref.watch(billingServiceProvider);
  return billing.getPrices();
});

final referralViewProvider = FutureProvider.autoDispose<ReferralView>(
  (ref) {
    ref.cacheFor(const Duration(minutes: 5));
    return ref.watch(productRepositoryProvider).getReferral();
  },
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
