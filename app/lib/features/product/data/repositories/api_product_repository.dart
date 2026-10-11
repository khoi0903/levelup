import '../../../../core/api/api_client.dart';
import '../../domain/models/product_models.dart';
import '../../domain/repositories/product_repository.dart';

class ApiProductRepository implements ProductRepository {
  final ApiClient client;
  ApiProductRepository(this.client);
  @override
  Future<ProductConfig> getConfig() async => ProductConfig.fromJson(
    (await client.get('/admin/config')).data as Map<String, dynamic>,
  );
  @override
  Future<ProductConfig> saveConfig(ProductConfig config) async =>
      ProductConfig.fromJson(
        (await client.put('/admin/config', data: config.toJson())).data
            as Map<String, dynamic>,
      );
  @override
  Future<void> grantPro(String email, int days) async {
    await client.post('/admin/grant-pro', data: {'email': email, 'days': days});
  }

  @override
  Future<ReferralView> getReferral() async => ReferralView.fromJson(
    (await client.get('/referrals/me')).data as Map<String, dynamic>,
  );
  @override
  Future<void> redeem(String code) async {
    await client.post('/referrals/redeem', data: {'code': code.trim()});
  }
}
