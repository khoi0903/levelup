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
  if (platform == TargetPlatform.android &&
      image.format.group == ImageFormatGroup.yuv420 &&
      image.planes.length == 3) {
    // Android: một số máy (Xiaomi...) đệm thêm byte cuối mỗi hàng nhưng plugin vẫn
    // báo bytesPerRow = width cho NV21. YUV_420 báo đúng stride từng plane, nên tự ghép NV21.
    return InputImage.fromBytes(
      bytes: yuv420ToNv21(image),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: cameraImageRotation(camera, orientation, platform: platform),
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );
  }
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

/// Ghép 3 plane YUV_420_888 (có thể có stride/pixelStride) thành NV21 liền khối:
/// width*height byte Y, rồi (width/2)*(height/2) cặp V,U xen kẽ.
Uint8List yuv420ToNv21(CameraImage image) {
  final width = image.width;
  final height = image.height;
  if (width <= 0 || height <= 0 || width.isOdd || height.isOdd) {
    throw const FormatException('Invalid YUV420 size');
  }
  final y = image.planes[0];
  final u = image.planes[1];
  final v = image.planes[2];
  final uvWidth = width ~/ 2;
  final uvHeight = height ~/ 2;
  final yPixel = y.bytesPerPixel ?? 1;
  final uPixel = u.bytesPerPixel ?? 1;
  final vPixel = v.bytesPerPixel ?? 1;
  if (y.bytesPerRow < width * yPixel ||
      y.bytes.length <
          (height - 1) * y.bytesPerRow + (width - 1) * yPixel + 1 ||
      u.bytes.length <
          (uvHeight - 1) * u.bytesPerRow + (uvWidth - 1) * uPixel + 1 ||
      v.bytes.length <
          (uvHeight - 1) * v.bytesPerRow + (uvWidth - 1) * vPixel + 1) {
    throw const FormatException('Truncated YUV420 buffer');
  }
  final out = Uint8List(width * height + 2 * uvWidth * uvHeight);
  var i = 0;
  for (var row = 0; row < height; row++) {
    final start = row * y.bytesPerRow;
    if (yPixel == 1) {
      out.setRange(i, i + width, y.bytes, start);
      i += width;
    } else {
      for (var col = 0; col < width; col++) {
        out[i++] = y.bytes[start + col * yPixel];
      }
    }
  }
  for (var row = 0; row < uvHeight; row++) {
    for (var col = 0; col < uvWidth; col++) {
      out[i++] = v.bytes[row * v.bytesPerRow + col * vPixel];
      out[i++] = u.bytes[row * u.bytesPerRow + col * uPixel];
    }
  }
  return out;
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
