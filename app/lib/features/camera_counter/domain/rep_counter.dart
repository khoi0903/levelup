import 'dart:math' as math;

import 'cv_config.dart';
import 'form_rule.dart';
import 'joint_angle.dart';
import 'pose.dart';

/// `up` = tư thế nghỉ, `down` = đang trong một lần tập. Với hướng `extend`
/// (nghỉ ở góc nhỏ) `down` vẫn nghĩa là "đang trong lần tập".
enum RepState { up, down }

/// Góc nhỏ nhất và lớn nhất của một bộ ba khớp trong một lần tập.
class AngleRange {
  const AngleRange(this.min, this.max);
  final double min;
  final double max;
}

class DetectedRep {
  const DetectedRep({
    required this.repIndex,
    required this.startedAt,
    required this.completedAt,
    required this.deepestAngle,
    required this.averageConfidence,
    this.peakAngle,
    this.angleRanges = const {},
  });

  /// One-based index, suitable for form issues shown to the user.
  final int repIndex;
  final Duration startedAt;
  final Duration completedAt;

  /// Góc chính nhỏ nhất trong lần tập.
  final double deepestAngle;

  /// Góc chính lớn nhất trong lần tập (null nếu tạo tay không có dữ liệu).
  final double? peakAngle;
  final double averageConfidence;

  /// Theo `tripletKey` (ví dụ `shoulder-hip-ankle`), gồm cả bộ chính.
  final Map<String, AngleRange> angleRanges;

  Duration get duration => completedAt - startedAt;
}

/// Immutable snapshot; previously returned results never change.
class RepCounterResult {
  RepCounterResult._({
    required Iterable<DetectedRep> reps,
    required this.averageConfidence,
    required this.personMissing,
    required this.state,
    required this.currentAngle,
    required this.selectedSide,
    required this.averagedSides,
    required this.orientationOk,
    required this.holdDuration,
    required this.holding,
    required Iterable<Duration> holdOutsideByRule,
  }) : reps = List.unmodifiable(reps),
       holdOutsideByRule = List.unmodifiable(holdOutsideByRule);

  final List<DetectedRep> reps;
  int get repCount => reps.length;

  /// Mean triplet confidence across all usable frames; zero before detection.
  final double averageConfidence;

  /// The UI should pause when true. Call checkPresence on a timer as well.
  final bool personMissing;
  final RepState state;
  final double? currentAngle;

  /// null khi chưa có dữ liệu hoặc khi góc là trung bình hai bên.
  final BodySide? selectedSide;

  /// true khi khung hình gần nhất lấy trung bình hai bên (`side: both`).
  final bool averagedSides;

  /// false khi khung gần nhất sai hướng thân (`orientation`); null nếu không
  /// có dữ liệu hoặc cấu hình không kiểm tra hướng.
  final bool? orientationOk;

  /// Tổng thời gian giữ đúng dải (chế độ hold); luôn 0 ở chế độ reps.
  final Duration holdDuration;

  /// Đang giữ trong dải ở khung gần nhất (chế độ hold).
  final bool holding;

  /// Chế độ hold: thời gian (trong lúc giữ) góc của luật band thứ i nằm ngoài
  /// dải của luật. Cùng chỉ số với `CvConfig.formRules`; luật khác là 0.
  final List<Duration> holdOutsideByRule;
}

/// Pure Dart state machine. Feed each frame once, in timestamp order.
///
/// Two consecutive usable frames must strictly cross a threshold. Initially,
/// and after losing the person, two rest frames are needed to arm the counter.
/// Short missing frames preserve an active rep but interrupt the debounce.
/// Losing the person for >1 second cancels any incomplete rep.
///
/// Chế độ hold: thời gian giữa hai khung dùng được liên tiếp cùng nằm trong
/// [holdMin, holdMax] được cộng vào holdDuration (khoảng hở > [holdMaxGap]
/// không được cộng). Ra khỏi dải, mất người hoặc tạm dừng thì ngừng cộng.
class RepCounter {
  RepCounter({required this.config, Duration startedAt = Duration.zero})
    : _startedAt = startedAt,
      _latestTime = startedAt,
      _triplets = config.trackedTriplets,
      _holdOutside = List.filled(config.formRules.length, Duration.zero) {
    if (startedAt.isNegative) {
      throw ArgumentError.value(startedAt, 'startedAt', 'Must be nonnegative');
    }
  }

  static const personMissingAfter = Duration(seconds: 1);

  /// Khoảng hở lớn nhất giữa hai khung vẫn được cộng vào thời gian giữ.
  static const holdMaxGap = Duration(milliseconds: 500);

  final CvConfig config;
  final Duration _startedAt;
  final List<List<PoseJoint>> _triplets;
  final List<DetectedRep> _reps = [];
  Duration _latestTime;
  Duration? _lastFrameAt;
  Duration? _lastConfidentAt;
  RepState _state = RepState.up;
  bool _armed = false;
  bool _personMissing = false;
  int _pendingFrames = 0;
  Duration? _upCandidateAt;
  _RepInProgress? _candidateRep;
  _RepInProgress? _activeRep;
  double _confidenceSum = 0;
  int _confidenceFrames = 0;
  double? _currentAngle;
  BodySide? _selectedSide;
  bool _averagedSides = false;
  bool? _orientationOk;
  Duration _holdDuration = Duration.zero;
  final List<Duration> _holdOutside;
  Duration? _holdPrevAt;
  bool _holdPrevInBand = false;

  RepCounterResult get result => RepCounterResult._(
    reps: _reps,
    averageConfidence: _confidenceFrames == 0
        ? 0
        : _confidenceSum / _confidenceFrames,
    personMissing: _personMissing,
    state: _state,
    currentAngle: _currentAngle,
    selectedSide: _selectedSide,
    averagedSides: _averagedSides,
    orientationOk: _orientationOk,
    holdDuration: _holdDuration,
    holding: _holdPrevAt != null && _holdPrevInBand && !_personMissing,
    holdOutsideByRule: _holdOutside,
  );

  RepCounterResult addFrame(PoseFrame frame) {
    if (_lastFrameAt != null && frame.timestamp <= _lastFrameAt!) {
      throw ArgumentError('Frame timestamps must be strictly increasing');
    }
    _advanceTime(frame.timestamp);
    _lastFrameAt = frame.timestamp;
    final sample = _selectSample(frame);
    _currentAngle = sample?.angle;
    _selectedSide = sample?.side;
    _averagedSides = sample?.averaged ?? false;
    _orientationOk = sample?.orientationOk;
    if (sample == null) {
      _clearDebounce();
      return result;
    }

    _lastConfidentAt = frame.timestamp;
    _personMissing = false;
    _confidenceSum += sample.confidence;
    _confidenceFrames++;

    if (config.isHold) {
      _addHoldSample(frame.timestamp, sample);
      return result;
    }
    if (sample.orientationOk == false) {
      // Sai hướng thân: vẫn có người, nhưng không làm tiến trạng thái đếm.
      _clearDebounce();
      return result;
    }

    if (_state == RepState.down) {
      _activeRep!.add(sample);
      if (_isRest(sample.angle)) {
        _upCandidateAt ??= frame.timestamp;
        _pendingFrames++;
        if (_pendingFrames >= 2) {
          final active = _activeRep!;
          // Use first threshold crossings, not debounce confirmation times.
          final completedAt = _upCandidateAt!;
          if (completedAt - active.startedAt >=
              Duration(milliseconds: config.minRepMs)) {
            _reps.add(
              DetectedRep(
                repIndex: _reps.length + 1,
                startedAt: active.startedAt,
                completedAt: completedAt,
                deepestAngle: active.deepestAngle,
                peakAngle: active.peakAngle,
                averageConfidence: active.averageConfidence,
                angleRanges: Map.unmodifiable(active.ranges),
              ),
            );
          }
          _state = RepState.up;
          _activeRep = null;
          _clearDebounce();
        }
      } else {
        _clearDebounce();
      }
    } else if (!_armed) {
      if (_isRest(sample.angle)) {
        _pendingFrames++;
        if (_pendingFrames >= 2) {
          _armed = true;
          _clearDebounce();
        }
      } else {
        _clearDebounce();
      }
    } else if (_isActive(sample.angle)) {
      _candidateRep ??= _RepInProgress(frame.timestamp);
      _candidateRep!.add(sample);
      _pendingFrames++;
      if (_pendingFrames >= 2) {
        _state = RepState.down;
        _activeRep = _candidateRep;
        _clearDebounce();
      }
    } else {
      _clearDebounce();
    }
    return result;
  }

  /// Call with elapsed session time even if the camera sends no frames.
  /// Uses the same monotonic clock as PoseFrame.timestamp.
  RepCounterResult checkPresence(Duration timestamp) {
    _advanceTime(timestamp);
    return result;
  }

  /// Cancel partial motion on an explicit pause, keeping completed reps.
  /// The next rep must start from two confident up frames again.
  /// Chế độ hold: giữ nguyên holdDuration, ngừng cộng cho tới khung kế tiếp.
  RepCounterResult discardIncompleteRep() {
    _state = RepState.up;
    _armed = false;
    _activeRep = null;
    _currentAngle = null;
    _selectedSide = null;
    _averagedSides = false;
    _orientationOk = null;
    _holdPrevAt = null;
    _holdPrevInBand = false;
    _clearDebounce();
    return result;
  }

  bool _isRest(double angle) => config.direction == CvDirection.flex
      ? angle > config.upAbove
      : angle < config.downBelow;

  bool _isActive(double angle) => config.direction == CvDirection.flex
      ? angle < config.downBelow
      : angle > config.upAbove;

  void _addHoldSample(Duration timestamp, _AngleSample sample) {
    final inBand =
        sample.orientationOk != false &&
        sample.angle >= config.holdMin! &&
        sample.angle <= config.holdMax!;
    final previous = _holdPrevAt;
    if (previous != null && _holdPrevInBand && inBand) {
      final delta = timestamp - previous;
      if (delta <= holdMaxGap) {
        _holdDuration += delta;
        for (var i = 0; i < config.formRules.length; i++) {
          final rule = config.formRules[i];
          if (rule.type != FormRuleType.band) continue;
          final angle = rule.joints == null
              ? sample.angle
              : sample.tracked[tripletKey(rule.joints!)];
          if (angle != null && (angle < rule.min! || angle > rule.max!)) {
            _holdOutside[i] += delta;
          }
        }
      }
    }
    _holdPrevAt = timestamp;
    _holdPrevInBand = inBand;
  }

  void _advanceTime(Duration timestamp) {
    if (timestamp < _latestTime) {
      throw ArgumentError('Time must not move backwards');
    }
    _latestTime = timestamp;
    if (timestamp - (_lastConfidentAt ?? _startedAt) > personMissingAfter) {
      _personMissing = true;
      _state = RepState.up;
      _armed = false;
      _activeRep = null;
      _currentAngle = null;
      _selectedSide = null;
      _averagedSides = false;
      _orientationOk = null;
      _holdPrevAt = null;
      _holdPrevInBand = false;
      _clearDebounce();
    }
  }

  void _clearDebounce() {
    _pendingFrames = 0;
    _candidateRep = null;
    _upCandidateAt = null;
  }

  _AngleSample? _selectSample(PoseFrame frame) {
    final left = _measure(frame, config.joints, BodySide.left);
    final right = _measure(frame, config.joints, BodySide.right);
    if (left == null && right == null) return null;
    final List<BodySide> sides;
    if (left == null || right == null) {
      sides = [left == null ? BodySide.right : BodySide.left];
    } else {
      sides = switch (config.side) {
        CvSide.auto => [
          right.confidence > left.confidence ? BodySide.right : BodySide.left,
        ],
        CvSide.both => BodySide.values,
        CvSide.min => [
          right.angle < left.angle ? BodySide.right : BodySide.left,
        ],
        CvSide.max => [
          right.angle > left.angle ? BodySide.right : BodySide.left,
        ],
      };
    }
    final primary = [
      for (final side in sides) side == BodySide.left ? left! : right!,
    ];
    final tracked = <String, double>{
      tripletKey(config.joints): _mean(primary.map((m) => m.angle)),
    };
    for (final triplet in _triplets.skip(1)) {
      final angles = [
        for (final side in sides) _measure(frame, triplet, side)?.angle,
      ].whereType<double>();
      if (angles.isNotEmpty) tracked[tripletKey(triplet)] = _mean(angles);
    }
    return _AngleSample(
      angle: tracked[tripletKey(config.joints)]!,
      confidence: _mean(primary.map((m) => m.confidence)),
      side: sides.length == 1 ? sides.single : null,
      averaged: sides.length > 1,
      tracked: tracked,
      orientationOk: _orientation(frame, sides),
    );
  }

  bool? _orientation(PoseFrame frame, List<BodySide> sides) {
    final orientation = config.orientation;
    if (orientation == null) return null;
    for (final side in sides) {
      final a = _point(frame, orientation.joints[0], side);
      final b = _point(frame, orientation.joints[1], side);
      if (a == null || b == null) return false;
      final dx = (b.x - a.x).abs();
      final dy = (b.y - a.y).abs();
      if (!dx.isFinite || !dy.isFinite || (dx == 0 && dy == 0)) return false;
      // Góc của đoạn so với phương ngang của ảnh, 0..90 độ.
      final tilt = math.atan2(dy, dx) * 180 / math.pi;
      final ok = orientation.axis == OrientationAxis.horizontal
          ? tilt <= orientation.maxTiltDeg
          : 90 - tilt <= orientation.maxTiltDeg;
      if (!ok) return false;
    }
    return true;
  }

  PoseLandmark? _point(PoseFrame frame, PoseJoint joint, BodySide side) {
    final point = frame.landmarks[PoseLandmarkType.forJoint(joint, side)];
    if (point == null ||
        !point.likelihood.isFinite ||
        point.likelihood < config.minConfidence ||
        point.likelihood < 0 ||
        point.likelihood > 1) {
      return null;
    }
    return point;
  }

  _Measurement? _measure(
    PoseFrame frame,
    List<PoseJoint> joints,
    BodySide side,
  ) {
    final points = <PoseLandmark>[];
    for (final joint in joints) {
      final point = _point(frame, joint, side);
      if (point == null) return null;
      points.add(point);
    }
    final angle = jointAngle(points[0], points[1], points[2]);
    if (angle == null) return null;
    return _Measurement(
      angle,
      points.fold<double>(0, (sum, point) => sum + point.likelihood) / 3,
    );
  }

  static double _mean(Iterable<double> values) {
    var sum = 0.0;
    var count = 0;
    for (final value in values) {
      sum += value;
      count++;
    }
    return sum / count;
  }
}

class _Measurement {
  const _Measurement(this.angle, this.confidence);
  final double angle;
  final double confidence;
}

class _AngleSample {
  const _AngleSample({
    required this.angle,
    required this.confidence,
    required this.side,
    required this.averaged,
    required this.tracked,
    required this.orientationOk,
  });
  final double angle;
  final double confidence;
  final BodySide? side;
  final bool averaged;

  /// Góc của mọi bộ ba khớp đo được ở khung này, theo `tripletKey`.
  final Map<String, double> tracked;
  final bool? orientationOk;
}

class _RepInProgress {
  _RepInProgress(this.startedAt);
  final Duration startedAt;
  double deepestAngle = 180;
  double peakAngle = 0;
  final Map<String, AngleRange> ranges = {};
  double _confidenceSum = 0;
  int _frames = 0;

  double get averageConfidence => _confidenceSum / _frames;

  void add(_AngleSample sample) {
    if (sample.angle < deepestAngle) deepestAngle = sample.angle;
    if (sample.angle > peakAngle) peakAngle = sample.angle;
    for (final entry in sample.tracked.entries) {
      final range = ranges[entry.key];
      ranges[entry.key] = range == null
          ? AngleRange(entry.value, entry.value)
          : AngleRange(
              math.min(range.min, entry.value),
              math.max(range.max, entry.value),
            );
    }
    _confidenceSum += sample.confidence;
    _frames++;
  }
}
