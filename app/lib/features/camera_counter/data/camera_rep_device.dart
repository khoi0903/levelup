import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import 'camera_input_image.dart';

/// Injectable camera boundary; tests never open physical hardware.
abstract interface class CameraRepDevice {
  CameraController? get controller;
  Future<void> initialize();
  Future<void> startImages(
    void Function(InputImage) onImage,
    void Function(Object, StackTrace) onError,
  );
  Future<void> stopImages();
  Future<void> dispose();
}

class FrontCameraRepDevice implements CameraRepDevice {
  CameraController? _controller;

  @override
  CameraController? get controller => _controller;

  @override
  Future<void> initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      throw UnsupportedError('Camera counter supports Android and iOS only');
    }
    if (_controller != null) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        throw CameraException(
          permission.isPermanentlyDenied
              ? 'CameraAccessDeniedWithoutPrompt'
              : 'CameraAccessDenied',
          'Cho phép LevelUp dùng camera trong Cài đặt để đếm lần tập.',
        );
      }
    }
    // On iOS CameraController requests access using NSCameraUsageDescription.
    // This avoids requiring permission_handler Podfile macros outside scope.
    final cameras = await availableCameras();
    final front = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    if (front.isEmpty) {
      throw CameraException(
        'FrontCameraUnavailable',
        'Không tìm thấy camera trước.',
      );
    }
    final controller = CameraController(
      front.first,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
      _controller = controller;
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  @override
  Future<void> startImages(
    void Function(InputImage) onImage,
    void Function(Object, StackTrace) onError,
  ) async {
    final controller = _controller;
    if (controller == null) throw StateError('Camera has not been initialized');
    await controller.startImageStream((image) {
      try {
        onImage(
          cameraInputImage(
            image,
            camera: controller.description,
            orientation: controller.value.deviceOrientation,
            platform: defaultTargetPlatform,
          ),
        );
      } catch (error, stack) {
        onError(error, stack);
      }
    });
  }

  @override
  Future<void> stopImages() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

abstract interface class CameraRepPoseDetector {
  Future<List<Pose>> processImage(InputImage image);
  Future<void> close();
}

class MlkitStreamPoseDetector implements CameraRepPoseDetector {
  final _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  @override
  Future<List<Pose>> processImage(InputImage image) =>
      _detector.processImage(image);

  @override
  Future<void> close() => _detector.close();
}
