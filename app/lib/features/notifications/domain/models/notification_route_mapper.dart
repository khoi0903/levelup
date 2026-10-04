/// Ánh xạ route từ push notification payload data.route sang đường dẫn go_router trong app.
///
/// Bảng ánh xạ theo đặc tả:
/// - `/checkin` -> `/checkin`
/// - `/workout/<sessionId>` -> `/workout/<sessionId>`
/// - `/nutrition` -> `/nutrition`
/// - `/coach` (+ coachMessageId) -> `/coach`
/// - `/buddy` (+ pairId) -> `/buddy`
/// - `/review` (+ reviewId) -> `/reviews/latest` (router chưa có /review)
/// - `/plan` -> `/workout` (router chưa có /plan)
/// - route lạ / thiếu -> `/home`
String mapNotificationRoute(String? route) {
  if (route == null || route.trim().isEmpty) {
    return '/home';
  }

  final trimmed = route.trim();

  if (trimmed == '/checkin') {
    return '/checkin';
  }

  // /workout/<sessionId> giữ nguyên sessionId
  if (trimmed.startsWith('/workout/')) {
    return trimmed;
  }
  if (trimmed == '/workout') {
    return '/workout';
  }

  // /nutrition (nhắc uống nước...)
  if (trimmed == '/nutrition' ||
      trimmed.startsWith('/nutrition?') ||
      trimmed.startsWith('/nutrition/')) {
    return '/nutrition';
  }

  // /coach
  if (trimmed == '/coach' ||
      trimmed.startsWith('/coach?') ||
      trimmed.startsWith('/coach/')) {
    return '/coach';
  }

  // /buddy
  if (trimmed == '/buddy' ||
      trimmed.startsWith('/buddy?') ||
      trimmed.startsWith('/buddy/')) {
    return '/buddy';
  }

  // /review (+ reviewId) -> router chưa có /review, mở /reviews/latest
  if (trimmed == '/review' ||
      trimmed.startsWith('/review?') ||
      trimmed.startsWith('/review/')) {
    return '/reviews/latest';
  }

  // /plan -> router chưa có /plan, mở tab Tập /workout
  if (trimmed == '/plan' ||
      trimmed.startsWith('/plan?') ||
      trimmed.startsWith('/plan/')) {
    return '/workout';
  }

  if (trimmed == '/home') {
    return '/home';
  }

  // Mọi route lạ hoặc không nhận diện được -> /home
  return '/home';
}
