import 'dart:math' as math;

import 'pose.dart';

/// Nhận cử chỉ "vẫy một tay trên đầu" để ra lệnh mà không cần chạm điện thoại.
///
/// - Một tay giơ cao hơn vai ít nhất [raiseRatio] × chiều dài thân (vai → hông), tay kia không giơ.
/// - Cổ tay đổi hướng trái/phải ít nhất [minDirectionChanges] lần, mỗi lần lắc ≥ [swingRatio] × thân,
///   trong vòng [window].
/// Cử chỉ động, một tay, cao hơn đầu nên gần như không trùng động tác tập (jumping jack giơ cả hai tay,
/// đẩy qua đầu đi thẳng lên xuống). Màn tập còn chỉ nhận khi không đang đếm và có bước xác nhận.
class WaveDetector {
  WaveDetector({
    this.raiseRatio = 0.35,
    this.swingRatio = 0.18,
    this.minDirectionChanges = 3,
    this.window = const Duration(milliseconds: 2500),
    this.cooldown = const Duration(seconds: 2),
    this.minLikelihood = 0.5,
  });

  final double raiseRatio;
  final double swingRatio;
  final int minDirectionChanges;
  final Duration window;
  final Duration cooldown;
  final double minLikelihood;

  final List<({Duration t, double x})> _track = [];
  BodySide? _side;
  Duration? _lastWave;
  bool _handRaised = false;
  int _waveCount = 0;

  /// Đang giơ một tay cao (để UI sáng biểu tượng bàn tay).
  bool get handRaised => _handRaised;

  /// Số lần vẫy đã nhận, chỉ tăng. UI so với số trước để biết có lần vẫy mới.
  int get waveCount => _waveCount;

  void reset() {
    _track.clear();
    _side = null;
    _handRaised = false;
  }

  void addFrame(PoseFrame? frame) {
    final raised = frame == null ? null : _raisedSide(frame);
    _handRaised = raised != null;
    if (raised == null || raised != _side) {
      _track.clear();
      _side = raised;
      if (raised == null) return;
    }
    final f = frame!;
    final wrist = f.landmarks[PoseLandmarkType.forJoint(PoseJoint.wrist, raised)]!;
    final shoulder = f.landmarks[PoseLandmarkType.forJoint(PoseJoint.shoulder, raised)]!;
    _track.add((t: f.timestamp, x: wrist.x - shoulder.x));
    _track.removeWhere((p) => f.timestamp - p.t > window);
    if (_lastWave != null && f.timestamp - _lastWave! < cooldown) return;
    final torso = _torso(f, raised);
    if (torso == null) return;
    if (_directionChanges(swingRatio * torso) >= minDirectionChanges) {
      _waveCount++;
      _lastWave = f.timestamp;
      _track.clear();
    }
  }

  /// Bên đang giơ tay cao một mình; null khi không giơ hoặc giơ cả hai tay.
  BodySide? _raisedSide(PoseFrame f) {
    final left = _isRaised(f, BodySide.left);
    final right = _isRaised(f, BodySide.right);
    if (left == right) return null;
    return left ? BodySide.left : BodySide.right;
  }

  bool _isRaised(PoseFrame f, BodySide side) {
    final wrist = _point(f, PoseJoint.wrist, side);
    final shoulder = _point(f, PoseJoint.shoulder, side);
    final torso = _torso(f, side);
    if (wrist == null || shoulder == null || torso == null) return false;
    // Trục y hướng xuống: tay cao hơn vai thì y nhỏ hơn
    return shoulder.y - wrist.y >= raiseRatio * torso;
  }

  double? _torso(PoseFrame f, BodySide side) {
    final shoulder = _point(f, PoseJoint.shoulder, side);
    final hip = _point(f, PoseJoint.hip, side);
    if (shoulder == null || hip == null) return null;
    final d = math.sqrt(math.pow(shoulder.x - hip.x, 2) + math.pow(shoulder.y - hip.y, 2));
    return d > 0 ? d : null;
  }

  PoseLandmark? _point(PoseFrame f, PoseJoint joint, BodySide side) {
    final p = f.landmarks[PoseLandmarkType.forJoint(joint, side)];
    return p != null && p.likelihood >= minLikelihood ? p : null;
  }

  /// Số lần đổi hướng có biên độ đủ lớn (bỏ rung nhẹ dưới [minSwing]).
  int _directionChanges(double minSwing) {
    if (_track.length < 3) return 0;
    var changes = 0;
    var direction = 0; // -1 sang trái, 1 sang phải
    var pivot = _track.first.x;
    for (final p in _track.skip(1)) {
      final delta = p.x - pivot;
      if (direction >= 0 && delta <= -minSwing) {
        if (direction == 1) changes++;
        direction = -1;
        pivot = p.x;
      } else if (direction <= 0 && delta >= minSwing) {
        if (direction == -1) changes++;
        direction = 1;
        pivot = p.x;
      } else if ((direction == 1 && p.x > pivot) || (direction == -1 && p.x < pivot)) {
        pivot = p.x; // vẫn đi cùng hướng: dời mốc tới điểm xa nhất
      }
    }
    return changes;
  }
}
