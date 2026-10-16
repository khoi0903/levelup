enum HealthConnectStatus {
  initial,
  notSupported,
  needsInstall,
  notAuthorized,
  authorized,
  loading,
  error,
}

class HealthDataSummary {
  final int steps;
  final double caloriesBurned;
  final DateTime lastUpdated;

  const HealthDataSummary({
    this.steps = 0,
    this.caloriesBurned = 0.0,
    required this.lastUpdated,
  });

  HealthDataSummary copyWith({
    int? steps,
    double? caloriesBurned,
    DateTime? lastUpdated,
  }) {
    return HealthDataSummary(
      steps: steps ?? this.steps,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
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
