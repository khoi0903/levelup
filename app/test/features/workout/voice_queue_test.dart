import 'dart:async';

import 'package:fitness_app/core/voice/voice_models.dart';
import 'package:fitness_app/core/voice/voice_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hàng đợi với "giọng đọc" giả: mỗi câu đọc trong [ms] mili giây, ghi lại câu đã đọc và câu bị cắt.
class _Harness {
  _Harness({this.ms = 300}) {
    queue = VoiceQueue(
      onSpeak: (e) async {
        spoken.add(e.text);
        _current = Completer<void>();
        final c = _current!;
        Timer(Duration(milliseconds: ms), () {
          if (!c.isCompleted) c.complete();
        });
        await c.future;
      },
      onStopTts: () async {
        if (_current != null && !_current!.isCompleted) {
          cut.add(spoken.last);
          _current!.complete();
        }
      },
    );
  }

  final int ms;
  late final VoiceQueue queue;
  final spoken = <String>[];
  final cut = <String>[];
  Completer<void>? _current;
}

void main() {
  test('đếm lùi bắt đầu hiệp không cắt câu đang đọc (mẹo kỹ thuật trước khi camera mở)', () async {
    final h = _Harness();
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Giữ gót bám sàn', isStartTip: true));
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Xong hiệp 1', key: VoiceLineKey.setDone));
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Chuẩn bị, 3', key: VoiceLineKey.startCountdown));
    await h.queue.whenIdle(max: const Duration(seconds: 3));

    expect(h.cut, isEmpty);
    expect(h.spoken, ['Giữ gót bám sàn', 'Xong hiệp 1', 'Chuẩn bị, 3']);
  });

  test('đếm lùi bỏ câu đếm số cũ còn chờ', () async {
    final h = _Harness();
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Còn 3 lần', key: VoiceLineKey.almostDone));
    await h.queue.enqueue(const VoiceQueueEntry(text: '8', key: VoiceLineKey.rep));
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Chuẩn bị, 3', key: VoiceLineKey.startCountdown));
    await h.queue.whenIdle(max: const Duration(seconds: 3));

    expect(h.spoken, ['Còn 3 lần', 'Chuẩn bị, 3']);
    expect(h.cut, isEmpty);
  });

  test('whenIdle chờ nói xong, có giới hạn thời gian', () async {
    final h = _Harness(ms: 200);
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Bài tiếp theo: Squat', key: VoiceLineKey.exerciseNext));
    final sw = Stopwatch()..start();
    await h.queue.whenIdle(max: const Duration(seconds: 2));
    expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(150));
    expect(h.queue.isSpeaking, isFalse);

    final slow = _Harness(ms: 5000);
    await slow.queue.enqueue(const VoiceQueueEntry(text: 'Câu rất dài', key: VoiceLineKey.workoutDone));
    final sw2 = Stopwatch()..start();
    await slow.queue.whenIdle(max: const Duration(milliseconds: 300));
    expect(sw2.elapsedMilliseconds, lessThan(1500));
  });

  test('đếm lùi giữ tên bài và mẹo kỹ thuật còn chờ (bài không có camera)', () async {
    final h = _Harness();
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Bài tiếp theo: Plank', key: VoiceLineKey.exerciseNext));
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Khuỷu tay dưới vai', isStartTip: true));
    await h.queue.enqueue(const VoiceQueueEntry(text: 'Chuẩn bị, 3', key: VoiceLineKey.startCountdown));
    await h.queue.whenIdle(max: const Duration(seconds: 3));
    expect(h.spoken, ['Bài tiếp theo: Plank', 'Khuỷu tay dưới vai', 'Chuẩn bị, 3']);
    expect(h.cut, isEmpty);
  });
}
