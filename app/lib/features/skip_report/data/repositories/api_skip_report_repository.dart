import '../../../../core/api/api_client.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../domain/models/skip_report_models.dart';
import '../../domain/repositories/skip_report_repository.dart';

class ApiSkipReportRepository implements SkipReportRepository {
  final ApiClient client;

  ApiSkipReportRepository({required this.client});

  @override
  Future<SkipReportResponse> reportSkip(SkipReportRequest request) async {
    final response = await client.post<Map<String, dynamic>>(
      '/skip-reports',
      data: request.toJson(),
    );
    return SkipReportResponse.fromJson(response.data!);
  }

  @override
  Future<PlanView> patchSession(String sessionId, PatchSessionRequest request) async {
    final response = await client.patch<Map<String, dynamic>>(
      '/plans/sessions/$sessionId',
      data: request.toJson(),
    );
    return PlanView.fromJson(response.data!);
  }
}
