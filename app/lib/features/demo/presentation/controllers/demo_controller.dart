import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../buddies/presentation/controllers/buddy_controller.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../nutrition/presentation/controllers/nutrition_controller.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../../streak/presentation/controllers/streak_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../data/repositories/api_demo_repository.dart';
import '../../domain/repositories/demo_repository.dart';

final demoRepositoryProvider = Provider<DemoRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiDemoRepository(client: client);
});

class DemoState {
  final String? runningAction;
  final String? message;
  final bool isError;
  final bool isSuccess;

  const DemoState({
    this.runningAction,
    this.message,
    this.isError = false,
    this.isSuccess = false,
  });

  DemoState copyWith({
    String? runningAction,
    String? message,
    bool? isError,
    bool? isSuccess,
    bool clearRunningAction = false,
  }) {
    return DemoState(
      runningAction: clearRunningAction
          ? null
          : (runningAction ?? this.runningAction),
      message: message ?? this.message,
      isError: isError ?? this.isError,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class DemoNotifier extends StateNotifier<DemoState> {
  final DemoRepository _repo;
  final Ref _ref;

  DemoNotifier(this._repo, this._ref) : super(const DemoState());

  Future<void> runAction(String action) async {
    state = state.copyWith(
      runningAction: action,
      message: null,
      isError: false,
      isSuccess: false,
    );

    try {
      final res = await _repo.executeAction(action);
      final resultData = res['result'];

      String message = '';
      if (action == 'checkin' || action == 'push-test') {
        final pushResult = resultData is Map
            ? resultData['result']?.toString()
            : resultData?.toString();
        switch (pushResult) {
          case 'SENT':
            message = 'Đã gửi, xem thanh thông báo';
            break;
          case 'STORED_ONLY':
            message = 'Máy này chưa đăng ký nhận thông báo';
            break;
          case 'QUIET_HOURS':
            message = 'Đang giờ yên lặng, sẽ gửi lúc 07:00';
            break;
          case 'DAILY_LIMIT':
            message = 'Hết lượt thông báo hôm nay';
            break;
          default:
            message = 'Đã thực hiện: ${pushResult ?? "thành công"}';
        }
      } else if (action == 'seed') {
        message = 'Nạp dữ liệu demo thành công (9 buổi tập, streak 3 tuần, cân nặng 4 tuần, 21 bữa ăn).';
      } else if (action == 'skip-two') {
        message = 'Đã giả lập bỏ 2 buổi gần nhất. Coach đã gửi nhắc nhở.';
      } else if (action == 'close-week') {
        final status = resultData is Map
            ? resultData['status']?.toString()
            : null;
        message = status != null
            ? 'Đã chốt tuần ngay thành công (trạng thái: $status).'
            : 'Đã chốt tuần ngay thành công.';
      } else if (action == 'review') {
        message = 'Đã tạo tổng kết tuần thành công.';
      } else {
        message = 'Thao tác $action đã hoàn tất thành công.';
      }

      // Invalidate relevant providers to refresh data across tabs
      _ref.invalidate(streakFutureProvider);
      _ref.invalidate(homePlanProvider);
      _ref.invalidate(userStatusFutureProvider);
      _ref.invalidate(nutritionTodayProvider);
      _ref.invalidate(measurementHistoryProvider);
      _ref.invalidate(buddyTodayFutureProvider);

      state = DemoState(
        runningAction: null,
        message: message,
        isSuccess: true,
        isError: false,
      );
    } catch (e) {
      if (_isNotFound(e)) {
        state = const DemoState(
          runningAction: null,
          message: 'Tài khoản này chưa bật chế độ demo',
          isError: true,
          isSuccess: false,
        );
      } else {
        state = DemoState(
          runningAction: null,
          message: mapErrorMessage(e),
          isError: true,
          isSuccess: false,
        );
      }
    }
  }

  bool _isNotFound(dynamic e) {
    if (e is ApiException) {
      return e.statusCode == 404 || e.code == 'NOT_FOUND';
    }
    if (e is DioException) {
      if (e.response?.statusCode == 404) return true;
      if (e.error is ApiException) {
        final apiEx = e.error as ApiException;
        return apiEx.statusCode == 404 || apiEx.code == 'NOT_FOUND';
      }
    }
    final str = e.toString().toLowerCase();
    return str.contains('404') || str.contains('not found');
  }
}

final demoControllerProvider =
    StateNotifierProvider.autoDispose<DemoNotifier, DemoState>((ref) {
      final repo = ref.watch(demoRepositoryProvider);
      return DemoNotifier(repo, ref);
    });
