import 'package:camera/camera.dart';
import 'package:fitness_app/features/camera_counter/data/camera_input_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class FakeFormat implements ImageFormat {
  FakeFormat(this.group);
  @override
  final ImageFormatGroup group;
  @override
  int get raw => group == ImageFormatGroup.nv21 ? 17 : 1111970369;
}

class FakePlane implements Plane {
  FakePlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel = 1,
  });
  @override
  final Uint8List bytes;
  @override
  final int bytesPerRow;
  @override
  final int? bytesPerPixel;
  @override
  int? get height => null;
  @override
  int? get width => null;
}

class FakeImage implements CameraImage {
  FakeImage({
    required ImageFormatGroup group,
    required this.planes,
    this.width = 2,
    this.height = 2,
  }) : format = FakeFormat(group);
  @override
  final ImageFormat format;
  @override
  final List<Plane> planes;
  @override
  final int height;
  @override
  final int width;
  @override
  double? get lensAperture => null;
  @override
  int? get sensorExposureTime => null;
  @override
  double? get sensorSensitivity => null;
}

const front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);
const back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

void main() {
  test(
    'Android rotation includes front/back sensor and device orientation',
    () {
      for (final entry in <DeviceOrientation, int>{
        DeviceOrientation.portraitUp: 270,
        DeviceOrientation.landscapeLeft: 0,
        DeviceOrientation.portraitDown: 90,
        DeviceOrientation.landscapeRight: 180,
      }.entries) {
        expect(
          cameraImageRotation(
            front,
            entry.key,
            platform: TargetPlatform.android,
          ).rawValue,
          entry.value,
        );
      }
      expect(
        cameraImageRotation(
          back,
          DeviceOrientation.landscapeLeft,
          platform: TargetPlatform.android,
        ),
        InputImageRotation.rotation0deg,
      );
    },
  );

  test(
    'packed NV21 stays in memory with correct size, stride and rotation',
    () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      final result = cameraInputImage(
        FakeImage(
          group: ImageFormatGroup.nv21,
          planes: [FakePlane(bytes: bytes, bytesPerRow: 2)],
        ),
        camera: front,
        orientation: DeviceOrientation.portraitUp,
        platform: TargetPlatform.android,
      );
      expect(result.type, InputImageType.bytes);
      expect(result.filePath, isNull);
      expect(result.bytes, same(bytes));
      expect(result.metadata!.size, const Size(2, 2));
      expect(result.metadata!.format, InputImageFormat.nv21);
      expect(result.metadata!.rotation, InputImageRotation.rotation270deg);
      expect(result.metadata!.bytesPerRow, 2);
    },
  );

  test('iOS BGRA preserves padded row stride', () {
    final result = cameraInputImage(
      FakeImage(
        group: ImageFormatGroup.bgra8888,
        planes: [FakePlane(bytes: Uint8List(24), bytesPerRow: 12)],
      ),
      camera: front,
      orientation: DeviceOrientation.landscapeLeft,
      platform: TargetPlatform.iOS,
    );
    expect(result.metadata!.format, InputImageFormat.bgra8888);
    expect(result.metadata!.bytesPerRow, 12);
    expect(result.filePath, isNull);
  });

  test('rejects multi-plane YUV, wrong format and truncated buffers', () {
    for (final image in [
      FakeImage(
        group: ImageFormatGroup.yuv420,
        planes: [
          FakePlane(bytes: Uint8List(3), bytesPerRow: 2), // Y thiếu byte
          FakePlane(bytes: Uint8List(1), bytesPerRow: 1),
          FakePlane(bytes: Uint8List(1), bytesPerRow: 1),
        ],
      ),
      FakeImage(
        group: ImageFormatGroup.yuv420,
        planes: [FakePlane(bytes: Uint8List(6), bytesPerRow: 2)],
      ),
      FakeImage(
        group: ImageFormatGroup.nv21,
        planes: [FakePlane(bytes: Uint8List(5), bytesPerRow: 2)],
      ),
      FakeImage(
        group: ImageFormatGroup.nv21,
        planes: [FakePlane(bytes: Uint8List(6), bytesPerRow: 4)],
      ),
    ]) {
      expect(
        () => cameraInputImage(
          image,
          camera: front,
          orientation: DeviceOrientation.portraitUp,
          platform: TargetPlatform.android,
        ),
        throwsFormatException,
      );
    }
  });

  test('Android YUV420 with padded rows packs into exact NV21 (VU order)', () {
    // 4x2 ảnh, Y stride 6 (đệm 2 byte/hàng), U/V xen kẽ pixelStride 2, stride 6 — như CameraX
    final y = Uint8List.fromList([1, 2, 3, 4, 0, 0, 5, 6, 7, 8, 0, 0]);
    final u = Uint8List.fromList([10, 20, 11, 21, 0, 0]);
    final v = Uint8List.fromList([20, 11, 21, 0, 0, 0]);
    final image = FakeImage(
      group: ImageFormatGroup.yuv420,
      width: 4,
      height: 2,
      planes: [
        FakePlane(bytes: y, bytesPerRow: 6),
        FakePlane(bytes: u, bytesPerRow: 6, bytesPerPixel: 2),
        FakePlane(bytes: v, bytesPerRow: 6, bytesPerPixel: 2),
      ],
    );
    expect(yuv420ToNv21(image), [1, 2, 3, 4, 5, 6, 7, 8, 20, 10, 21, 11]);
    final input = cameraInputImage(
      image,
      camera: front,
      orientation: DeviceOrientation.portraitUp,
      platform: TargetPlatform.android,
    );
    expect(input.metadata!.format, InputImageFormat.nv21);
    expect(input.metadata!.bytesPerRow, 4);
    expect(input.bytes!.length, 12);
  });
}
