import 'dart:async';

import 'voice_models.dart';

class VoiceQueueEntry {
  final String text;
  final VoiceLineKey? key;
  final Map<String, Object?> params;
  final double? rate;
  final double? pitch;
  final bool isFormCue;
  final bool isStartTip;

  const VoiceQueueEntry({
    required this.text,
    this.key,
    this.params = const {},
    this.rate,
    this.pitch,
    this.isFormCue = false,
    this.isStartTip = false,
  });

  bool get isProtected =>
      key == VoiceLineKey.setDone ||
      key == VoiceLineKey.restStart ||
      key == VoiceLineKey.workoutDone ||
      key == VoiceLineKey.personalRecord;

  bool get isNonImportant =>
      isFormCue ||
      isStartTip ||
      key == VoiceLineKey.formGeneric ||
      key == VoiceLineKey.restEnding ||
      key == VoiceLineKey.lostPerson ||
      key == VoiceLineKey.exerciseNext;
}

class VoiceQueue {
  VoiceQueue({
    required this.onSpeak,
    required this.onStopTts,
    this.onEntryStarted,
    this.isActive = _defaultIsActive,
  });

  static bool _defaultIsActive() => true;

  final FutureOr<void> Function(VoiceQueueEntry entry) onSpeak;
  final Future<void> Function() onStopTts;
  final void Function(VoiceQueueEntry entry)? onEntryStarted;
  final bool Function() isActive;

  static const int maxQueueSize = 3;

  final List<VoiceQueueEntry> _queue = [];
  VoiceQueueEntry? _current;
  bool _isSpeaking = false;
  bool _isProcessing = false;

  bool get isSpeaking => _isSpeaking;
  VoiceQueueEntry? get current => _current;
  List<VoiceQueueEntry> get waitingEntries => List.unmodifiable(_queue);

  Future<void> enqueue(VoiceQueueEntry entry) async {
    if (!isActive()) return;

    // 1. Khi bắt đầu hiệp mới: start_countdown xóa hàng đợi cũ rồi đọc
    if (entry.key == VoiceLineKey.startCountdown) {
      _queue.clear();
      _queue.add(entry);
      await _cancelCurrent();
      _processQueue();
      return;
    }

    // 2. Gộp câu đếm: rep mới vào thì bỏ các rep CŨ còn chờ trong hàng đợi (chỉ đọc số mới nhất)
    if (entry.key == VoiceLineKey.rep) {
      _queue.removeWhere((i) => i.key == VoiceLineKey.rep);
    }

    // 4. hold_last (5 giây cuối) mỗi giây một số: nếu số trước chưa đọc xong thì bỏ số đó, đọc số mới
    if (entry.key == VoiceLineKey.holdLast) {
      _queue.removeWhere((i) => i.key == VoiceLineKey.holdLast);
      _queue.add(entry);
      if (_current?.key == VoiceLineKey.holdLast) {
        await _cancelCurrent();
      }
      _processQueue();
      return;
    }

    // 3. Hàng đợi tối đa 3 câu: đầy thì bỏ câu cũ nhất không quan trọng (form, rest_ending), không bỏ set_done/rest_start/workout_done/personal_record
    while (_queue.length >= maxQueueSize) {
      final nonImportantIdx = _queue.indexWhere((i) => i.isNonImportant);
      if (nonImportantIdx != -1) {
        _queue.removeAt(nonImportantIdx);
      } else {
        final nonProtectedIdx = _queue.indexWhere((i) => !i.isProtected);
        if (nonProtectedIdx != -1) {
          _queue.removeAt(nonProtectedIdx);
        } else {
          if (!entry.isProtected) {
            return;
          }
          break;
        }
      }
    }

    _queue.add(entry);
    _processQueue();
  }

  Future<void> _cancelCurrent() async {
    await onStopTts();
  }

  Future<void> stop() async {
    _queue.clear();
    await _cancelCurrent();
    _current = null;
    _isSpeaking = false;
  }

  void clearQueue() {
    _queue.clear();
  }

  void _processQueue() {
    if (_isProcessing) return;
    _isProcessing = true;
    _drainQueue();
  }

  void _drainQueue() {
    while (_queue.isNotEmpty && isActive()) {
      final entry = _queue.removeAt(0);
      _current = entry;
      _isSpeaking = true;
      onEntryStarted?.call(entry);

      try {
        final res = onSpeak(entry);
        if (res is Future) {
          res.catchError((_) {}).whenComplete(() {
            _current = null;
            _drainQueue();
          });
          return;
        } else {
          _current = null;
        }
      } catch (_) {
        _current = null;
      }
    }

    _isSpeaking = false;
    _isProcessing = false;
  }
}
