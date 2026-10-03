class ApiException implements Exception {
  final String code;
  final Map<String, String> fields;
  final int? statusCode;

  const ApiException({
    required this.code,
    this.fields = const {},
    this.statusCode,
  });

  bool get isNetworkError => code == 'NETWORK_ERROR';
  bool get isOnboardingRequired => statusCode == 404 && code == 'ONBOARDING_REQUIRED';
  bool get isValidationError => statusCode == 400 || code == 'VALIDATION_ERROR';

  @override
  String toString() =>
      'ApiException(code: $code, fields: $fields, statusCode: $statusCode)';
}
