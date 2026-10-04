import '../models/progress_models.dart';

abstract interface class ProgressRepository {
  Future<MeasurementHistory> history({int days = 90});
  Future<MeasurementSaveResult> save(MeasurementRequest request);
}
