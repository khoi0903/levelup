import '../models/product_models.dart';

abstract class ProductRepository {
  Future<ProductConfig> getConfig();
  Future<ProductConfig> saveConfig(ProductConfig config);
  Future<void> grantPro(String email, int days);
  Future<ReferralView> getReferral();
  Future<void> redeem(String code);
}
