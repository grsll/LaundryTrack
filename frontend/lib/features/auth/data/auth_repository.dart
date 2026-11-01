import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/auth_interceptor.dart';
import 'auth_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<AuthDataModel> registerBusiness({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String businessName,
    String? outletName,
    String? outletAddress,
    String? outletPhone,
  }) async {
    final response = await _dio.post(
      '${AppConstants.apiV1Prefix}/auth/register',
      data: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
        'business_name': businessName,
        'outlet_name': outletName ?? 'Outlet Utama',
        'outlet_address': outletAddress,
        'outlet_phone': outletPhone,
      },
    );

    final resData = response.data as Map<String, dynamic>;
    final authData = AuthDataModel.fromJson(resData['data'] as Map<String, dynamic>);
    TokenStorage.saveTokens(authData.tokens.accessToken, authData.tokens.refreshToken);
    return authData;
  }

  Future<AuthDataModel> login({
    required String emailOrPhone,
    required String password,
  }) async {
    final response = await _dio.post(
      '${AppConstants.apiV1Prefix}/auth/login',
      data: {
        'email_or_phone': emailOrPhone,
        'password': password,
      },
    );

    final resData = response.data as Map<String, dynamic>;
    final authData = AuthDataModel.fromJson(resData['data'] as Map<String, dynamic>);
    TokenStorage.saveTokens(authData.tokens.accessToken, authData.tokens.refreshToken);
    return authData;
  }

  Future<void> logout() async {
    final refreshToken = TokenStorage.refreshToken;
    if (refreshToken != null) {
      try {
        await _dio.post(
          '${AppConstants.apiV1Prefix}/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      } catch (_) {
        // Ignored during logout cleanup
      }
    }
    TokenStorage.clearTokens();
  }
}
