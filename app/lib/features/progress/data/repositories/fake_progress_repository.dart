import '../../../../core/api/api_exceptions.dart';
import '../../domain/models/progress_models.dart';
import '../../domain/repositories/progress_repository.dart';

class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({
    this.current = const MeasurementHistory(),
    this.today = '2026-10-04',
  });
  MeasurementHistory current;
  final String today;
  Object? historyError, saveError;
  int? requestedDays;
  int saveCalls = 0;
  MeasurementRequest? savedRequest;
  List<ProgressAchievement> achievements = [];
  @override
  Future<MeasurementHistory> history({int days = 90}) async {
    requestedDays = days;
    if (historyError != null) throw historyError!;
    return current;
  }

  @override
  Future<MeasurementSaveResult> save(MeasurementRequest request) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    if (!request.hasValue) {
      throw const ApiException(code: 'MEASUREMENT_EMPTY', statusCode: 400);
    }
    savedRequest = request;
    final previous = current.items
        .where((e) => e.measuredOn == today)
        .firstOrNull;
    final measurement = Measurement(
      measuredOn: today,
      weightKg: request.weightKg ?? previous?.weightKg,
      waistCm: request.waistCm ?? previous?.waistCm,
      hipCm: request.hipCm ?? previous?.hipCm,
      chestCm: request.chestCm ?? previous?.chestCm,
      armCm: request.armCm ?? previous?.armCm,
    );
    current = MeasurementHistory(
      days: current.days,
      items: [...current.items.where((e) => e.measuredOn != today), measurement]
        ..sort((a, b) => a.measuredOn.compareTo(b.measuredOn)),
    );
    return MeasurementSaveResult(
      measurement: measurement,
      newAchievements: achievements,
    );
  }
}
