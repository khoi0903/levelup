import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../../camera_counter/data/camera_rep_session.dart';
import '../../../camera_counter/domain/cv_config.dart';
import '../../domain/models/exercise_response.dart';
import '../../domain/models/workout_models.dart';

enum RepCountingStatus { idle, running, paused, stopped }

/// Ảnh chụp kết quả đếm của một hiệp, tách khỏi CameraRepResult để test được.
class RepSnapshot {
  final int repCount;
  final bool personMissing;
  final double averageConfidence;
  final int formScore;
  final List<FormIssueLog> issues;
  final RepCountingStatus status;
  final String? error;

  /// Bài giữ tư thế (plank, wall sit): đo thời gian thay vì đếm lần.
  final bool isHold;
  final Duration holdDuration;

  /// Đang giữ đúng tư thế ngay lúc này (để UI báo "đang tính giờ").
  final bool holding;

  /// Đang giơ một tay cao (sáng biểu tượng bàn tay trên màn camera).
  final bool handRaised;

  /// Số lần vẫy tay đã nhận trong phiên, chỉ tăng (vẫy tay để bỏ bài).
  final int waveCount;

  const RepSnapshot({
    this.isHold = false,
    this.holdDuration = Duration.zero,
    this.holding = false,
    this.handRaised = false,
    this.waveCount = 0,
    this.repCount = 0,
    this.personMissing = false,
    this.averageConfidence = 0,
    this.formScore = 100,
    this.issues = const [],
    this.status = RepCountingStatus.idle,
    this.error,
  });

  bool get permissionDenied => error?.contains('CameraAccessDenied') ?? false;
}

/// Một phiên đếm bằng camera cho một hiệp. Màn tập chỉ biết interface này.
abstract class RepCountingSession {
  Stream<RepSnapshot> get results;
  RepSnapshot get latest;

  /// Controller để vẽ CameraPreview; null khi camera chưa mở hoặc trong test.
  CameraController? get cameraController;

  Future<void> start();
  Future<void> pause();

  /// Kết thúc hẳn, giải phóng camera. Gọi nhiều lần không sao.
  Future<void> stop();
}

/// Tạo phiên đếm cho một bài tập. Test ghi đè bằng bản giả.
abstract class RepSessionFactory {
  /// Bài này đếm được bằng camera trên thiết bị hiện tại không.
  bool supports(ExerciseCamera? camera);

  RepCountingSession create(ExerciseCamera camera);
}

/// Bản thật: bọc CameraRepSession của module camera_counter.
class CameraRepSessionFactory implements RepSessionFactory {
  const CameraRepSessionFactory({this.sessionBuilder});

  /// Inject hardware boundaries while exercising the real snapshot adapter.
  @visibleForTesting
  final CameraRepSession Function(CvConfig config)? sessionBuilder;

  bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool supports(ExerciseCamera? camera) {
    final config = camera?.config;
    if (!_platformSupported || config == null) return false;
    try {
      // Mọi cấu hình hợp lệ trong mongo/cv-configs.json: đếm lần hoặc giữ tư thế.
      CvConfig.fromJson(config);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  RepCountingSession create(ExerciseCamera camera) => _CameraRepCountingSession(
    sessionBuilder?.call(CvConfig.fromJson(camera.config!)) ??
        CameraRepSession(config: CvConfig.fromJson(camera.config!)),
  );
}

class _CameraRepCountingSession implements RepCountingSession {
  _CameraRepCountingSession(this._session);

  final CameraRepSession _session;

  static RepSnapshot _map(CameraRepResult r) => RepSnapshot(
    isHold: r.isHold,
    holdDuration: r.holdDuration,
    holding: r.holding,
    handRaised: r.handRaised,
    waveCount: r.waveCount,
    repCount: r.repCount,
    personMissing: r.personMissing,
    averageConfidence: r.averageConfidence,
    formScore: r.formScore,
    issues: r.issues
        .map(
          (i) => FormIssueLog(
            repIndex: i.repIndex,
            code: i.code,
            severity: i.severity,
          ),
        )
        .toList(),
    status: switch (r.status) {
      CameraRepSessionStatus.idle => RepCountingStatus.idle,
      CameraRepSessionStatus.running => RepCountingStatus.running,
      CameraRepSessionStatus.paused => RepCountingStatus.paused,
      CameraRepSessionStatus.stopped => RepCountingStatus.stopped,
    },
    error: r.error,
  );

  @override
  Stream<RepSnapshot> get results => _session.results.map(_map);

  @override
  RepSnapshot get latest => _map(_session.latestResult);

  @override
  CameraController? get cameraController => _session.cameraController;

  @override
  Future<void> start() => _session.start();

  @override
  Future<void> pause() => _session.pause();

  @override
  Future<void> stop() => _session.stop();
}
