enum BillingPeriod { monthly, yearly }

abstract class BillingService {
  Future<String> purchase(BillingPeriod period);
  Future<String> restore();
  Future<Map<BillingPeriod, String>> getPrices();
  Future<void> logOut();
}

class FakeBillingService implements BillingService {
  String purchaseResult;
  String restoreResult;
  Map<BillingPeriod, String> prices;
  bool restoreCalled = false;
  BillingPeriod? lastPurchasedPeriod;

  FakeBillingService({
    this.purchaseResult = 'Sắp ra mắt',
    this.restoreResult = 'Đã khôi phục giao dịch',
    this.prices = const {},
  });

  @override
  Future<String> purchase(BillingPeriod period) async {
    lastPurchasedPeriod = period;
    return purchaseResult;
  }

  @override
  Future<String> restore() async {
    restoreCalled = true;
    return restoreResult;
  }

  @override
  Future<Map<BillingPeriod, String>> getPrices() async => prices;

  @override
  Future<void> logOut() async {}
}
