import 'exercise_response.dart';

/// Bài tập thay thế trả về từ GET /plans/sessions/{sessionId}/alternatives
/// hoặc dựng từ thư viện bài tập cho buổi tập thêm.
class ExerciseAlternative {
  final String exerciseId;
  final String nameVi;
  final String? slug;
  final String? thumbnailUrl;
  final String? primaryMuscle;
  final String? tracking;
  final bool cameraSupported;
  final String? reason;

  const ExerciseAlternative({
    required this.exerciseId,
    required this.nameVi,
    this.slug,
    this.thumbnailUrl,
    this.primaryMuscle,
    this.tracking,
    this.cameraSupported = false,
    this.reason,
  });

  factory ExerciseAlternative.fromJson(Map<String, dynamic> json) {
    return ExerciseAlternative(
      exerciseId: json['exerciseId']?.toString() ?? '',
      nameVi: json['nameVi']?.toString() ?? '',
      slug: json['slug'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      primaryMuscle: json['primaryMuscle'] as String?,
      tracking: json['tracking'] as String?,
      cameraSupported: json['cameraSupported'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }

  factory ExerciseAlternative.fromExercise(ExerciseResponse ex, {String? reason}) {
    return ExerciseAlternative(
      exerciseId: ex.id,
      nameVi: ex.nameVi,
      slug: ex.slug,
      thumbnailUrl: ex.thumbnailUrl,
      primaryMuscle: ex.primaryMuscle,
      tracking: ex.tracking,
      cameraSupported: ex.camera != null,
      reason: reason,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'nameVi': nameVi,
    if (slug != null) 'slug': slug,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (primaryMuscle != null) 'primaryMuscle': primaryMuscle,
    if (tracking != null) 'tracking': tracking,
    'cameraSupported': cameraSupported,
    if (reason != null) 'reason': reason,
  };
}
