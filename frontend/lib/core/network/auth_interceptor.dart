import 'package:dio/dio.dart';

class TokenStorage {
  static String? _accessToken;
  static String? _refreshToken;

  static void saveTokens(String accessToken, String refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  static void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;
  static bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;
}

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = TokenStorage.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }
}
