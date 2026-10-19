enum HealthConnectStatus {
  initial,
  notSupported,
  needsInstall,
  notAuthorized,
  authorized,
  loading,
  error,
}

/// steps/caloriesBurned: đọc từ Health Connect trên máy này. serverSteps/serverActiveKcal: số máy chủ đã lưu
/// (lớn nhất giữa các điện thoại của tài khoản). Hiển thị số lớn hơn để Trang chủ khớp với Dinh dưỡng.
class HealthDataSummary {
  final int steps;
  final double caloriesBurned;
  final int serverSteps;
  final int serverActiveKcal;
  final DateTime lastUpdated;

  const HealthDataSummary({
    this.steps = 0,
    this.caloriesBurned = 0.0,
    this.serverSteps = 0,
    this.serverActiveKcal = 0,
    required this.lastUpdated,
  });

  int get displaySteps => steps > serverSteps ? steps : serverSteps;
  int get displayActiveKcal => caloriesBurned.round() > serverActiveKcal
      ? caloriesBurned.round()
      : serverActiveKcal;

  HealthDataSummary copyWith({
    int? steps,
    double? caloriesBurned,
    int? serverSteps,
    int? serverActiveKcal,
    DateTime? lastUpdated,
  }) {
    return HealthDataSummary(
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      serverSteps: serverSteps ?? this.serverSteps,
      serverActiveKcal: serverActiveKcal ?? this.serverActiveKcal,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class HealthConnectState {
  final HealthConnectStatus status;
  final HealthDataSummary? data;
  final String? errorMessage;

  const HealthConnectState({
    this.status = HealthConnectStatus.initial,
    this.data,
    this.errorMessage,
  });

  bool get isAuthorized => status == HealthConnectStatus.authorized;
  bool get isLoading => status == HealthConnectStatus.loading;

  HealthConnectState copyWith({
    HealthConnectStatus? status,
    HealthDataSummary? data,
    String? errorMessage,
  }) {
    return HealthConnectState(
      status: status ?? this.status,
      data: data ?? this.data,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
