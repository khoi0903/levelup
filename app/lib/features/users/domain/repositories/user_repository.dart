import '../models/me_response.dart';
import '../models/settings_request.dart';

abstract class UserRepository {
  Future<MeResponse> getMe();

  /// PATCH /me: chỉ gửi các trường cần cập nhật, nhận lại MeResponse đầy đủ.
  Future<MeResponse> updateSettings(SettingsRequest request);

  /// DELETE /me {"confirm": true}: xoá vĩnh viễn tài khoản và toàn bộ dữ liệu.
  Future<void> deleteAccount();

  /// POST /pain-followups/{bodyArea} {"answer": "gone|better|same|worse"}
  Future<PainFollowUpResponse> answerPainFollowUp(
    String bodyArea,
    String answer,
  );
}
