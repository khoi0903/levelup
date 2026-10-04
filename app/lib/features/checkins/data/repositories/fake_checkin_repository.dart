import '../../domain/models/checkin_models.dart';
import '../../domain/repositories/checkin_repository.dart';
import '../../../onboarding/domain/models/plan_models.dart';

class FakeCheckinRepository implements CheckinRepository {
  CheckinResponse? customResponse;
  Exception? errorToThrow;
  CheckinRequest? lastRequest;

  FakeCheckinRepository({
    this.customResponse,
    this.errorToThrow,
  });

  @override
  Future<CheckinResponse> completeCheckin(CheckinRequest request) async {
    lastRequest = request;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (customResponse != null) {
      return customResponse!;
    }

    final isTired = request.energy == 'tired';
    return CheckinResponse(
      localDate: '2026-10-04',
      energy: request.energy,
      sleep: request.sleep,
      adjusted: isTired,
      session: SessionView(
        id: 'session-today',
        scheduledDate: '2026-10-04',
        scheduledTime: '18:30',
        title: isTired ? 'Toàn thân nhẹ nhàng (Đã giảm hiệp)' : 'Toàn thân + giãn cơ',
        durationMin: isTired ? 10 : 15,
        variant: isTired ? 'checkin_tired' : null,
        status: 'planned',
        adjustedReason: isTired ? 'checkin_tired' : null,
        items: const [
          ItemView(exerciseId: 'squat', nameVi: 'Squat', sets: 2, reps: 10),
          ItemView(exerciseId: 'plank', nameVi: 'Plank', sets: 2, durationSec: 20),
        ],
      ),
    );
  }
}
