import '../models/me_response.dart';

abstract class UserRepository {
  Future<MeResponse> getMe();
}
