import 'package:fitness_app/core/review/review_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStore implements ReviewPromptStore {
  bool asked = false;
  int count = 0;

  @override
  Future<int> countedWorkouts() async => count;

  @override
  Future<void> markAsked() async => asked = true;

  @override
  Future<void> setCountedWorkouts(int value) async => count = value;

  @override
  Future<bool> wasAsked() async => asked;
}

class _FakeRequester implements ReviewRequester {
  bool available = true;
  int requests = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;
}

class _ThrowingRequester implements ReviewRequester {
  @override
  Future<bool> isAvailable() => throw StateError('no plugin');

  @override
  Future<void> requestReview() => throw StateError('no plugin');
}

void main() {
  group('shouldAskForReview', () {
    test('buổi được tính thứ 3 hoặc vừa đạt mục tiêu tuần', () {
      bool ask({
        bool asked = false,
        bool counts = true,
        int n = 1,
        bool week = false,
      }) => shouldAskForReview(
        alreadyAsked: asked,
        countsForStreak: counts,
        countedWorkoutsIncludingThis: n,
        weekGoalJustReached: week,
      );
      expect(ask(n: 1), isFalse);
      expect(ask(n: 2), isFalse);
      expect(ask(n: 3), isTrue);
      expect(ask(n: 1, week: true), isTrue);
      expect(ask(n: 3, asked: true), isFalse);
      expect(ask(n: 3, counts: false), isFalse);
    });
  });

  group('ReviewPrompt', () {
    late _MemoryStore store;
    late _FakeRequester requester;
    late ReviewPrompt prompt;

    setUp(() {
      store = _MemoryStore();
      requester = _FakeRequester();
      prompt = ReviewPrompt(store: store, requester: requester);
    });

    test('hỏi đúng ở buổi được tính thứ 3, chỉ một lần', () async {
      expect(await prompt.onWorkoutFinished(countsForStreak: true), isFalse);
      // Buổi dưới 5 phút không cộng.
      expect(await prompt.onWorkoutFinished(countsForStreak: false), isFalse);
      // Buổi gửi trùng không cộng.
      expect(
        await prompt.onWorkoutFinished(countsForStreak: true, duplicate: true),
        isFalse,
      );
      expect(await prompt.onWorkoutFinished(countsForStreak: true), isFalse);
      expect(store.count, 2);
      expect(await prompt.onWorkoutFinished(countsForStreak: true), isTrue);
      expect(requester.requests, 1);
      expect(store.asked, isTrue);

      expect(
        await prompt.onWorkoutFinished(
          countsForStreak: true,
          weekCompleted: 3,
          weekTarget: 3,
          weekAchieved: true,
        ),
        isFalse,
      );
      expect(requester.requests, 1);
    });

    test('lần đầu đạt mục tiêu tuần thì hỏi ngay', () async {
      expect(
        await prompt.onWorkoutFinished(
          countsForStreak: true,
          weekCompleted: 1,
          weekTarget: 1,
          weekAchieved: true,
        ),
        isTrue,
      );
      expect(requester.requests, 1);
    });

    test('tập thêm sau khi đã đạt tuần thì không tính là vừa đạt', () async {
      expect(
        await prompt.onWorkoutFinished(
          countsForStreak: true,
          weekCompleted: 4,
          weekTarget: 3,
          weekAchieved: true,
        ),
        isFalse,
      );
    });

    test('Play chưa sẵn sàng thì không đánh dấu, lần sau hỏi lại', () async {
      requester.available = false;
      store.count = 2;
      expect(await prompt.onWorkoutFinished(countsForStreak: true), isFalse);
      expect(store.asked, isFalse);
      requester.available = true;
      expect(await prompt.onWorkoutFinished(countsForStreak: true), isTrue);
      expect(requester.requests, 1);
    });

    test('lỗi plugin bị nuốt, không ném ra ngoài', () async {
      final p = ReviewPrompt(store: store, requester: _ThrowingRequester());
      store.count = 2;
      expect(await p.onWorkoutFinished(countsForStreak: true), isFalse);
      expect(store.asked, isFalse);
    });
  });
}
