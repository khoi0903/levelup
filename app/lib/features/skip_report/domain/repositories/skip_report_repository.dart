import '../../../onboarding/domain/models/plan_models.dart';
import '../models/skip_report_models.dart';

abstract class SkipReportRepository {
  Future<SkipReportResponse> reportSkip(SkipReportRequest request);
  Future<PlanView> patchSession(String sessionId, PatchSessionRequest request);
}
