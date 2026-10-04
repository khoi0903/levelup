import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_checkin_repository.dart';
import '../../domain/models/checkin_models.dart';
import '../../domain/repositories/checkin_repository.dart';

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiCheckinRepository(client: client);
});

class CheckinState {
  final String energy;
  final String? sleep;
  final bool isSubmitting;
  final CheckinResponse? response;
  final dynamic error;

  const CheckinState({
    this.energy = 'normal',
    this.sleep,
    this.isSubmitting = false,
    this.response,
    this.error,
  });

  CheckinState copyWith({
    String? energy,
    String? sleep,
    bool? isSubmitting,
    CheckinResponse? response,
    dynamic error,
    bool clearError = false,
  }) {
    return CheckinState(
      energy: energy ?? this.energy,
      sleep: sleep ?? this.sleep,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      response: response ?? this.response,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CheckinNotifier extends StateNotifier<CheckinState> {
  final CheckinRepository _repository;

  CheckinNotifier(this._repository) : super(const CheckinState());

  void setEnergy(String energy) {
    state = state.copyWith(energy: energy, clearError: true);
  }

  void setSleep(String? sleep) {
    state = state.copyWith(sleep: sleep, clearError: true);
  }

  Future<CheckinResponse?> submit() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final req = CheckinRequest(
        energy: state.energy,
        sleep: state.sleep,
      );
      final res = await _repository.completeCheckin(req);
      state = state.copyWith(isSubmitting: false, response: res);
      return res;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
      return null;
    }
  }

  void reset() {
    state = const CheckinState();
  }
}

final checkinControllerProvider =
    StateNotifierProvider.autoDispose<CheckinNotifier, CheckinState>((ref) {
  final repo = ref.watch(checkinRepositoryProvider);
  return CheckinNotifier(repo);
});
