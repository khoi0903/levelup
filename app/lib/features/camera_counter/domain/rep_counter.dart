import 'cv_config.dart';
import 'joint_angle.dart';
import 'pose.dart';

enum RepState { up, down }

class DetectedRep {
  const DetectedRep({
    required this.repIndex,
    required this.startedAt,
    required this.completedAt,
    required this.deepestAngle,
    required this.averageConfidence,
  });

  /// One-based index, suitable for form issues shown to the user.
  final int repIndex;
  final Duration startedAt;
  final Duration completedAt;
  final double deepestAngle;
  final double averageConfidence;

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
  }) : reps = List.unmodifiable(reps);

  final List<DetectedRep> reps;
  int get repCount => reps.length;

  /// Mean triplet confidence across all usable frames; zero before detection.
  final double averageConfidence;

  /// The UI should pause when true. Call checkPresence on a timer as well.
  final bool personMissing;
  final RepState state;
  final double? currentAngle;
  final BodySide? selectedSide;
}

/// Pure Dart state machine. Feed each frame once, in timestamp order.
///
/// Two consecutive usable frames must strictly cross a threshold. Initially,
/// and after losing the person, two up frames are needed to arm the counter.
/// Short missing frames preserve an active rep but interrupt the debounce.
/// Losing the person for >1 second cancels any incomplete rep.
class RepCounter {
  RepCounter({required this.config, Duration startedAt = Duration.zero})
    : _startedAt = startedAt,
      _latestTime = startedAt {
    if (startedAt.isNegative) {
      throw ArgumentError.value(startedAt, 'startedAt', 'Must be nonnegative');
    }
  }

  static const personMissingAfter = Duration(seconds: 1);
  final CvConfig config;
  final Duration _startedAt;
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

  RepCounterResult get result => RepCounterResult._(
    reps: _reps,
    averageConfidence: _confidenceFrames == 0
        ? 0
        : _confidenceSum / _confidenceFrames,
    personMissing: _personMissing,
    state: _state,
    currentAngle: _currentAngle,
    selectedSide: _selectedSide,
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
    if (sample == null) {
      _clearDebounce();
      return result;
    }

    _lastConfidentAt = frame.timestamp;
    _personMissing = false;
    _confidenceSum += sample.confidence;
    _confidenceFrames++;

    if (_state == RepState.down) {
      _activeRep!.add(sample);
      if (sample.angle > config.upAbove) {
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
                averageConfidence: active.averageConfidence,
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
      if (sample.angle > config.upAbove) {
        _pendingFrames++;
        if (_pendingFrames >= 2) {
          _armed = true;
          _clearDebounce();
        }
      } else {
        _clearDebounce();
      }
    } else if (sample.angle < config.downBelow) {
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
  RepCounterResult discardIncompleteRep() {
    _state = RepState.up;
    _armed = false;
    _activeRep = null;
    _currentAngle = null;
    _selectedSide = null;
    _clearDebounce();
    return result;
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
      _clearDebounce();
    }
  }

  void _clearDebounce() {
    _pendingFrames = 0;
    _candidateRep = null;
    _upCandidateAt = null;
  }

  _AngleSample? _selectSample(PoseFrame frame) {
    final left = _sampleSide(frame, BodySide.left);
    final right = _sampleSide(frame, BodySide.right);
    if (left == null) return right;
    if (right == null) return left;
    return right.confidence > left.confidence ? right : left;
  }

  _AngleSample? _sampleSide(PoseFrame frame, BodySide side) {
    final points = <PoseLandmark>[];
    for (final joint in config.joints) {
      final point = frame.landmarks[PoseLandmarkType.forJoint(joint, side)];
      if (point == null ||
          !point.likelihood.isFinite ||
          point.likelihood < config.minConfidence ||
          point.likelihood < 0 ||
          point.likelihood > 1) {
        return null;
      }
      points.add(point);
    }
    final angle = jointAngle(points[0], points[1], points[2]);
    if (angle == null) return null;
    return _AngleSample(
      angle,
      points.fold<double>(0, (sum, point) => sum + point.likelihood) / 3,
      side,
    );
  }
}

class _AngleSample {
  const _AngleSample(this.angle, this.confidence, this.side);
  final double angle;
  final double confidence;
  final BodySide side;
}

class _RepInProgress {
  _RepInProgress(this.startedAt);
  final Duration startedAt;
  double deepestAngle = 180;
  double _confidenceSum = 0;
  int _frames = 0;

  double get averageConfidence => _confidenceSum / _frames;

  void add(_AngleSample sample) {
    if (sample.angle < deepestAngle) deepestAngle = sample.angle;
    _confidenceSum += sample.confidence;
    _frames++;
  }
}
