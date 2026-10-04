import '../models/checkin_models.dart';

abstract class CheckinRepository {
  Future<CheckinResponse> completeCheckin(CheckinRequest request);
}
