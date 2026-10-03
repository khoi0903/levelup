import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Converts an in-memory stream buffer. No image/video files are created.
InputImage cameraInputImage(
  CameraImage image, {
  required CameraDescription camera,
  required DeviceOrientation orientation,
  required TargetPlatform platform,
}) {
  if (image.planes.length != 1) {
    throw const FormatException(
      'Expected one packed NV21 or BGRA camera plane',
    );
  }
  final plane = image.planes.single;
  final InputImageFormat format;
  if (platform == TargetPlatform.android &&
      image.format.group == ImageFormatGroup.nv21) {
    format = InputImageFormat.nv21;
    if (image.width.isOdd ||
        image.height.isOdd ||
        plane.bytesPerRow != image.width ||
        plane.bytes.length != image.width * image.height * 3 ~/ 2) {
      throw const FormatException('Invalid packed NV21 buffer');
    }
  } else if (platform == TargetPlatform.iOS &&
      image.format.group == ImageFormatGroup.bgra8888) {
    format = InputImageFormat.bgra8888;
    if (plane.bytesPerRow < image.width * 4 ||
        plane.bytes.length < plane.bytesPerRow * image.height) {
      throw const FormatException('Invalid BGRA buffer');
    }
  } else {
    throw FormatException(
      'Unsupported camera stream format: ${image.format.group.name}',
    );
  }
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: cameraImageRotation(camera, orientation, platform: platform),
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

InputImageRotation cameraImageRotation(
  CameraDescription camera,
  DeviceOrientation orientation, {
  required TargetPlatform platform,
}) {
  var degrees = camera.sensorOrientation;
  if (platform == TargetPlatform.android) {
    final deviceDegrees = switch (orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    degrees = camera.lensDirection == CameraLensDirection.front
        ? (degrees + deviceDegrees) % 360
        : (degrees - deviceDegrees + 360) % 360;
  }
  final rotation = InputImageRotationValue.fromRawValue(degrees);
  if (rotation == null) {
    throw ArgumentError('Camera sensor orientation must be a multiple of 90');
  }
  return rotation;
}
