import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lưu trên máy: đã hỏi đánh giá chưa, và đã xong bao nhiêu buổi được tính.
abstract class ReviewPromptStore {
  Future<bool> wasAsked();
  Future<void> markAsked();
  Future<int> countedWorkouts();
  Future<void> setCountedWorkouts(int value);
}

class SharedPrefsReviewPromptStore implements ReviewPromptStore {
  static const askedKey = 'review_prompt_asked';
  static const countKey = 'review_prompt_counted_workouts';

  @override
  Future<bool> wasAsked() async =>
      (await SharedPreferences.getInstance()).getBool(askedKey) ?? false;

  @override
  Future<void> markAsked() async =>
      (await SharedPreferences.getInstance()).setBool(askedKey, true);

  @override
  Future<int> countedWorkouts() async =>
      (await SharedPreferences.getInstance()).getInt(countKey) ?? 0;

  @override
  Future<void> setCountedWorkouts(int value) async =>
      (await SharedPreferences.getInstance()).setInt(countKey, value);
}

/// Bọc InAppReview để thay được trong test.
abstract class ReviewRequester {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class PlayReviewRequester implements ReviewRequester {
  @override
  Future<bool> isAvailable() => InAppReview.instance.isAvailable();

  @override
  Future<void> requestReview() => InAppReview.instance.requestReview();
}

/// Buổi thứ mấy được tính thì hỏi đánh giá.
const int kReviewAfterCountedWorkouts = 3;

/// Quyết định thuần: hỏi khi chưa từng hỏi và (đây là buổi được tính thứ 3,
/// hoặc buổi này vừa làm đạt mục tiêu tuần). Dùng `>=` để máy chưa sẵn sàng
/// Google Play ở buổi thứ 3 thì buổi được tính sau đó vẫn được hỏi một lần.
bool shouldAskForReview({
  required bool alreadyAsked,
  required bool countsForStreak,
  required int countedWorkoutsIncludingThis,
  required bool weekGoalJustReached,
}) {
  if (alreadyAsked || !countsForStreak) return false;
  return countedWorkoutsIncludingThis >= kReviewAfterCountedWorkouts ||
      weekGoalJustReached;
}

/// Mời đánh giá trên Google Play vào lúc vui: tối đa một lần mỗi lần cài.
/// Mọi lỗi (không có Play, chưa có plugin) đều bị nuốt, không bao giờ chặn UI.
class ReviewPrompt {
  ReviewPrompt({required this.store, required this.requester});

  final ReviewPromptStore store;
  final ReviewRequester requester;

  /// Gọi một lần sau khi màn kết quả buổi tập hiện ra.
  /// [weekCompleted]/[weekTarget]/[weekAchieved] lấy từ tiến độ tuần trả về.
  /// Trả về true nếu đã mời đánh giá.
  Future<bool> onWorkoutFinished({
    required bool countsForStreak,
    bool duplicate = false,
    int? weekCompleted,
    int? weekTarget,
    bool weekAchieved = false,
  }) async {
    try {
      if (duplicate) return false;
      var count = await store.countedWorkouts();
      if (countsForStreak) {
        count += 1;
        await store.setCountedWorkouts(count);
      }
      final justReached =
          weekAchieved &&
          weekTarget != null &&
          weekTarget > 0 &&
          weekCompleted == weekTarget;
      final ask = shouldAskForReview(
        alreadyAsked: await store.wasAsked(),
        countsForStreak: countsForStreak,
        countedWorkoutsIncludingThis: count,
        weekGoalJustReached: justReached,
      );
      if (!ask) return false;
      if (!await requester.isAvailable()) return false;
      // Đánh dấu trước khi gọi để không bao giờ hỏi lần hai.
      await store.markAsked();
      await requester.requestReview();
      return true;
    } catch (e) {
      debugPrint('ReviewPrompt: $e');
      return false;
    }
  }
}

final reviewPromptProvider = Provider<ReviewPrompt>(
  (ref) => ReviewPrompt(
    store: SharedPrefsReviewPromptStore(),
    requester: PlayReviewRequester(),
  ),
);
