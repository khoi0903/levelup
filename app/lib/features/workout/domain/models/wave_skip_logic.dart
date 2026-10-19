import '../../data/camera/rep_counting_session.dart';

/// Việc màn camera cần làm theo cử chỉ vẫy tay / lúc đứng lâu không tập.
enum WaveSkipEvent {
  /// Đã lâu không đếm được lần nào: hỏi có muốn đổi bài (giọng + thẻ).
  prompt,

  /// Bắt đầu đếm ngược bỏ bài (vẫy tay hoặc bấm "Bỏ bài này").
  countdown,

  /// Đếm ngược giảm một giây.
  countdownTick,

  /// Huỷ bỏ bài (bấm Huỷ hoặc làm tiếp một lần).
  cancelled,

  /// Hết đếm ngược: bỏ bài.
  skip,
}

/// Luật vẫy tay để bỏ bài, tách khỏi widget để test bằng đồng hồ giả.
///
/// - Chỉ nhận vẫy tay khi không đang tập: đã [recentActivity] không đếm được lần nào (bài giữ tư thế: không
///   đang giữ), hoặc trong lúc đang hỏi "đổi bài không".
/// - Đứng [idleAfter] không tập (vẫn thấy người) thì hỏi một lần mỗi hiệp, thẻ hiện [promptFor].
/// - Vẫy tay không bỏ ngay: đếm ngược [countdownSec] giây, làm tiếp một lần hoặc bấm Huỷ là huỷ.
class WaveSkipLogic {
  WaveSkipLogic({
    this.idleAfter = const Duration(seconds: 20),
    this.promptFor = const Duration(seconds: 8),
    this.recentActivity = const Duration(seconds: 3),
    this.countdownSec = 3,
  });

  final Duration idleAfter;
  final Duration promptFor;
  final Duration recentActivity;
  final int countdownSec;

  DateTime? _lastActivity;
  DateTime? _promptUntil;
  bool _prompted = false;
  int _lastRep = 0;
  int _lastWave = 0;
  bool _personMissing = true;
  int? _countdownLeft;

  /// Số giây còn lại trước khi bỏ bài; null khi không đếm ngược.
  int? get countdownLeft => _countdownLeft;

  bool promptVisible(DateTime now) =>
      _promptUntil != null && now.isBefore(_promptUntil!);

  /// Gọi khi bắt đầu đếm (sau "Bắt đầu"): mốc tính thời gian đứng yên.
  void start(DateTime now, RepSnapshot r) {
    _lastActivity = now;
    _lastRep = r.repCount;
    _lastWave = r.waveCount;
    _personMissing = r.personMissing;
  }

  bool get started => _lastActivity != null;

  List<WaveSkipEvent> onSnapshot(RepSnapshot r, DateTime now) {
    _personMissing = r.personMissing;
    if (!started) {
      _lastWave = r.waveCount; // vẫy lúc đếm lùi trước khi tập thì bỏ qua
      return const [];
    }
    final events = <WaveSkipEvent>[];
    final moved = r.repCount > _lastRep || r.holding;
    if (moved) {
      _lastActivity = now;
      _promptUntil = null;
      if (_countdownLeft != null && r.repCount > _lastRep) {
        _countdownLeft = null;
        events.add(WaveSkipEvent.cancelled);
      }
    }
    _lastRep = r.repCount;
    if (r.waveCount > _lastWave) {
      _lastWave = r.waveCount;
      final idle = !r.holding && now.difference(_lastActivity!) >= recentActivity;
      if (_countdownLeft == null && (promptVisible(now) || idle)) {
        events.add(_startCountdown());
      }
    }
    return events;
  }

  /// Gọi mỗi giây.
  List<WaveSkipEvent> tick(DateTime now) {
    if (!started) return const [];
    final left = _countdownLeft;
    if (left != null) {
      if (left <= 1) {
        _countdownLeft = null;
        return const [WaveSkipEvent.skip];
      }
      _countdownLeft = left - 1;
      return const [WaveSkipEvent.countdownTick];
    }
    if (!_prompted &&
        !_personMissing &&
        now.difference(_lastActivity!) >= idleAfter) {
      _prompted = true;
      _promptUntil = now.add(promptFor);
      return const [WaveSkipEvent.prompt];
    }
    return const [];
  }

  /// Bấm "Bỏ bài này" trên thẻ hỏi.
  WaveSkipEvent requestSkip() => _startCountdown();

  /// Bấm "Tập tiếp" hoặc "Huỷ".
  void dismiss() {
    _promptUntil = null;
    _countdownLeft = null;
  }

  WaveSkipEvent _startCountdown() {
    _promptUntil = null;
    _countdownLeft = countdownSec;
    return WaveSkipEvent.countdown;
  }
}
