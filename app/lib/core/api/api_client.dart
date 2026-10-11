import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/auth_constants.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import 'api_exceptions.dart';

/// Provider cung cấp token xác thực cho ApiClient.
/// Khi AUTH_MODE=dev thì dùng dev token, ngược lại lấy từ FirebaseAuth.
typedef AuthTokenProvider = Future<String?> Function();
typedef UnauthorizedHandler = void Function();

String defaultDevTokenProvider() {
  return 'dev-${AuthConstants.devUid}';
}

final authTokenProvider = Provider<AuthTokenProvider>((ref) {
  if (AuthConstants.isDevMode) {
    return () async => defaultDevTokenProvider();
  }
  final authRepo = ref.watch(authRepositoryProvider);
  return () async {
    return await authRepo.getIdToken();
  };
});

final unauthorizedHandlerProvider = Provider<UnauthorizedHandler?>(
  (ref) => null,
);

final apiBaseUrlProvider = Provider<String>((ref) {
  return const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8081',
  );
});

class ApiClient {
  final Dio dio;
  final UnauthorizedHandler? onUnauthorized;

  ApiClient({
    required String baseUrl,
    required AuthTokenProvider tokenProvider,
    this.onUnauthorized,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: baseUrl,
           connectTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 10),
           sendTimeout: const Duration(seconds: 10),
           headers: {
             'Content-Type': 'application/json',
             'Accept': 'application/json',
           },
         ),
       ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenProvider();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          final response = error.response;
          if (response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          // Request dạng stream (coach): body lỗi là luồng byte, đọc ra JSON để lấy mã lỗi thật
          if (response != null && response.data is ResponseBody) {
            response.data = await _readErrorBody(response.data as ResponseBody);
          }
          if (response != null && response.data is Map<String, dynamic>) {
            final data = response.data as Map<String, dynamic>;
            final code =
                data['code']?.toString() ?? 'HTTP_${response.statusCode}';
            final rawFields = data['fields'];
            final Map<String, String> fields = {};
            if (rawFields is Map) {
              rawFields.forEach((key, value) {
                if (key != null && value != null) {
                  fields[key.toString()] = value.toString();
                }
              });
            }
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: response,
                type: error.type,
                error: ApiException(
                  code: code,
                  fields: fields,
                  statusCode: response.statusCode,
                ),
              ),
            );
          } else {
            final statusCode = response?.statusCode;
            final isNetwork =
                error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.sendTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.connectionError ||
                // Không có phản hồi (máy chủ đóng kết nối, đang khởi động lại): cũng là lỗi kết nối
                (response == null && error.type == DioExceptionType.unknown);
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: response,
                type: error.type,
                error: ApiException(
                  code: isNetwork ? 'NETWORK_ERROR' : 'UNKNOWN_ERROR',
                  fields: const {},
                  statusCode: statusCode,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  static Future<Object?> _readErrorBody(ResponseBody body) async {
    try {
      final bytes = await body.stream
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk))
          .timeout(const Duration(seconds: 5));
      final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException(
        code: 'NETWORK_ERROR',
        fields: const {},
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException(
        code: 'NETWORK_ERROR',
        fields: const {},
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Response<ResponseBody>> postStream(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final streamOptions = (options ?? Options()).copyWith(
      responseType: ResponseType.stream,
      headers: {
        'Accept': 'text/event-stream',
        if (options?.headers != null) ...options!.headers!,
      },
    );
    try {
      return await dio.post<ResponseBody>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: streamOptions,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException(
        code: e.response?.statusCode != null
            ? 'HTTP_${e.response!.statusCode}'
            : 'NETWORK_ERROR',
        fields: const {},
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException(
        code: 'NETWORK_ERROR',
        fields: const {},
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException(
        code: 'NETWORK_ERROR',
        fields: const {},
        statusCode: e.response?.statusCode,
      );
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw ApiException(
        code: 'NETWORK_ERROR',
        fields: const {},
        statusCode: e.response?.statusCode,
      );
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final baseUrl = ref.watch(apiBaseUrlProvider);
  final tokenProvider = ref.watch(authTokenProvider);
  final onUnauthorized = ref.watch(unauthorizedHandlerProvider);
  return ApiClient(
    baseUrl: baseUrl,
    tokenProvider: tokenProvider,
    onUnauthorized: onUnauthorized,
  );
});
