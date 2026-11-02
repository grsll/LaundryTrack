import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'tracking_model.dart';

final trackingRepositoryProvider = Provider<TrackingRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TrackingRepository(dio);
});

class TrackingRepository {
  final Dio _dio;

  TrackingRepository(this._dio);

  Future<PublicTrackingModel> getPublicTracking(String token) async {
    try {
      final response = await _dio.get('/api/v1/tracking/$token');
      final data = response.data['data'] as Map<String, dynamic>;
      return PublicTrackingModel.fromJson(data);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ??
          'Gagal memuat status pelacakan cucian';
      throw Exception(msg);
    }
  }

  Future<TrackingLinkModel> getOrderTrackingLink(String orderId) async {
    try {
      final response = await _dio.get('/api/v1/orders/$orderId/tracking-link');
      final data = response.data['data'] as Map<String, dynamic>;
      return TrackingLinkModel.fromJson(data);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ??
          'Gagal mengambil link pelacakan pesanan';
      throw Exception(msg);
    }
  }

  Future<TrackingLinkModel> regenerateTrackingLink(String orderId) async {
    try {
      final response =
          await _dio.post('/api/v1/orders/$orderId/tracking-link/regenerate');
      final data = response.data['data'] as Map<String, dynamic>;
      return TrackingLinkModel.fromJson(data);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ??
          'Gagal memperbarui link pelacakan pesanan';
      throw Exception(msg);
    }
  }
}
