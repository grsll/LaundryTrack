import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'customer_model.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return CustomerRepository(dio);
});

class CustomerRepository {
  final Dio _dio;

  CustomerRepository(this._dio);

  Future<List<CustomerModel>> getCustomers({String? query, bool? isActive}) async {
    final queryParams = <String, dynamic>{
      'page': 1,
      'page_size': 50,
      if (query != null && query.isNotEmpty) 'q': query,
      'is_active': ?isActive,
    };

    final response = await _dio.get(
      '/api/v1/customers',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final List rawList = response.data['data'] as List;
      return rawList.map((item) => CustomerModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal memuat data pelanggan');
  }

  Future<CustomerModel> createCustomer(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '/api/v1/customers',
      data: payload,
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return CustomerModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal menambahkan pelanggan');
  }

  Future<CustomerModel> updateCustomer(String customerId, Map<String, dynamic> payload) async {
    final response = await _dio.patch(
      '/api/v1/customers/$customerId',
      data: payload,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return CustomerModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal memperbarui pelanggan');
  }

  Future<CustomerModel> archiveCustomer(String customerId) async {
    final response = await _dio.delete('/api/v1/customers/$customerId');

    if (response.statusCode == 200 && response.data['success'] == true) {
      return CustomerModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal mengarsipkan pelanggan');
  }
}
