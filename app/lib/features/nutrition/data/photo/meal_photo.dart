import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_exceptions.dart';

const maxMealPhotoBytes = 2 * 1024 * 1024;

class MealPhoto {
  MealPhoto(Uint8List bytes, this.mediaType)
    : bytes = Uint8List.fromList(bytes) {
    if (bytes.isEmpty) throw const ApiException(code: 'INVALID_IMAGE');
    if (bytes.length > maxMealPhotoBytes) {
      throw const ApiException(code: 'IMAGE_TOO_LARGE', statusCode: 413);
    }
    if (!const ['image/jpeg', 'image/png', 'image/webp'].contains(mediaType)) {
      throw const ApiException(code: 'UNSUPPORTED_MEDIA_TYPE', statusCode: 415);
    }
  }
  final Uint8List bytes;
  final String mediaType;
  Map<String, dynamic> toJson() => {
    'imageBase64': base64Encode(bytes),
    'mediaType': mediaType,
    'sha256': crypto.sha256.convert(bytes).toString(),
  };
}

enum MealPhotoSource { camera, gallery }

abstract interface class MealPhotoPicker {
  Future<MealPhoto?> pick(MealPhotoSource source);
}

class PlatformMealPhotoPicker implements MealPhotoPicker {
  @override
  Future<MealPhoto?> pick(MealPhotoSource source) async {
    final file = await ImagePicker().pickImage(
      source: source == MealPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    // Only read the picker's temporary file; never copy to persistent storage.
    final bytes = await compute(compressMealPhoto, await file.readAsBytes());
    return MealPhoto(bytes, 'image/jpeg');
  }
}

/// Encode in memory, normalize orientation, strip EXIF, then hash the encoded bytes.
Uint8List compressMealPhoto(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const ApiException(code: 'INVALID_IMAGE', statusCode: 415);
  }
  if (decoded == null) {
    throw const ApiException(code: 'INVALID_IMAGE', statusCode: 415);
  }
  var photo = img.bakeOrientation(decoded);
  if (photo.width > 1600 || photo.height > 1600) {
    photo = img.copyResize(
      photo,
      width: photo.width >= photo.height ? 1600 : null,
      height: photo.height > photo.width ? 1600 : null,
    );
  }
  photo.exif.clear();
  for (final quality in [85, 70, 55, 40]) {
    final encoded = img.encodeJpg(photo, quality: quality);
    if (encoded.length <= maxMealPhotoBytes) return encoded;
  }
  throw const ApiException(code: 'IMAGE_TOO_LARGE', statusCode: 413);
}
