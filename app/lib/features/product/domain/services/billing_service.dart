enum BillingPeriod { monthly, yearly }

abstract class BillingService {
  Future<String> purchase(BillingPeriod period);
}

class FakeBillingService implements BillingService {
  @override
  Future<String> purchase(BillingPeriod period) async => 'Sắp ra mắt';
}
