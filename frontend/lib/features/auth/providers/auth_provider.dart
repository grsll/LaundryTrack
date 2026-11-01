import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_model.dart';
import '../data/auth_repository.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final AuthDataModel? authData;
  final String? errorMessage;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.authData,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    AuthDataModel? authData,
    String? errorMessage,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      authData: authData ?? this.authData,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    return const AuthState();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<bool> login(String emailOrPhone, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final authData = await _repository.login(
        emailOrPhone: emailOrPhone.trim(),
        password: password,
      );
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        authData: authData,
      );
      return true;
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Terjadi kesalahan sistem: $e');
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String businessName,
    String? outletName,
    String? outletAddress,
    String? outletPhone,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final authData = await _repository.registerBusiness(
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        password: password,
        businessName: businessName.trim(),
        outletName: outletName?.trim(),
        outletAddress: outletAddress?.trim(),
        outletPhone: outletPhone?.trim(),
      );
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        authData: authData,
      );
      return true;
    } on DioException catch (e) {
      final message = _extractErrorMessage(e);
      state = state.copyWith(isLoading: false, errorMessage: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Gagal mendaftar: $e');
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState();
  }

  String _extractErrorMessage(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final data = e.response!.data as Map<String, dynamic>;
      if (data.containsKey('error') && data['error'] is Map<String, dynamic>) {
        final err = data['error'] as Map<String, dynamic>;
        return err['message'] as String? ?? 'Terjadi kesalahan pada server.';
      }
      if (data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is Map<String, dynamic> && detail.containsKey('error')) {
          return detail['error']['message'] as String? ?? 'Terjadi kesalahan autentikasi.';
        }
        if (detail is String) return detail;
      }
    }
    return e.message ?? 'Gagal menghubungi server. Periksa koneksi Anda.';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
