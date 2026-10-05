import '../../../../core/api/api_client.dart';
import '../../domain/repositories/demo_repository.dart';

class ApiDemoRepository implements DemoRepository {
  final ApiClient client;

  ApiDemoRepository({required this.client});

  @override
  Future<Map<String, dynamic>> executeAction(String action) async {
    final response = await client.post<Map<String, dynamic>>('/demo/$action');
    return response.data ?? {};
  }
}
