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
  FakePlane({required this.bytes, required this.bytesPerRow});
  @override
  final Uint8List bytes;
  @override
  final int bytesPerRow;
  @override
  int? get bytesPerPixel => 1;
  @override
  int? get height => null;
  @override
  int? get width => null;
}

class FakeImage implements CameraImage {
  FakeImage({required ImageFormatGroup group, required this.planes})
    : format = FakeFormat(group);
  @override
  final ImageFormat format;
  @override
  final List<Plane> planes;
  @override
  int get height => 2;
  @override
  int get width => 2;
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
        planes: List.generate(
          3,
          (_) => FakePlane(bytes: Uint8List(4), bytesPerRow: 2),
        ),
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
}
