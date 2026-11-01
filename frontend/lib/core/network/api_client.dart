import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import 'auth_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: AppConstants.defaultApiHost,
  );

  final dio = Dio(
    BaseOptions(
      baseUrl: apiHost,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Attach Auth Interceptor
  dio.interceptors.add(AuthInterceptor());

  // Attach Logging Interceptor (without logging sensitive credentials/bodies)
  dio.interceptors.add(
    LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) => debugPrint('[Dio] $obj'),
    ),
  );

  return dio;
});
