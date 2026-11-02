import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'service_model.dart';

final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ServiceRepository(dio);
});

class ServiceRepository {
  final Dio _dio;

  ServiceRepository(this._dio);

  Future<List<ServiceModel>> getServices({
    String? query,
    String? priceType,
    bool? isActive,
  }) async {
    final queryParams = <String, dynamic>{
      'page': 1,
      'page_size': 100,
      if (query != null && query.isNotEmpty) 'q': query,
      if (priceType != null && priceType != 'all') 'price_type': priceType,
      'is_active': ?isActive,
    };

    final response = await _dio.get(
      '/api/v1/services',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final List rawList = response.data['data'] as List;
      return rawList.map((item) => ServiceModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal memuat katalog layanan');
  }

  Future<ServiceModel> createService(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '/api/v1/services',
      data: payload,
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return ServiceModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal menambahkan layanan');
  }

  Future<ServiceModel> updateService(String serviceId, Map<String, dynamic> payload) async {
    final response = await _dio.patch(
      '/api/v1/services/$serviceId',
      data: payload,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return ServiceModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal memperbarui layanan');
  }

  Future<ServiceModel> archiveService(String serviceId) async {
    final response = await _dio.delete('/api/v1/services/$serviceId');

    if (response.statusCode == 200 && response.data['success'] == true) {
      return ServiceModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal mengarsipkan layanan');
  }
}
