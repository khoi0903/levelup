import '../models/me_response.dart';
import '../models/settings_request.dart';

abstract class UserRepository {
  Future<MeResponse> getMe();

  /// PATCH /me: chỉ gửi các trường cần cập nhật, nhận lại MeResponse đầy đủ.
  Future<MeResponse> updateSettings(SettingsRequest request);
}
