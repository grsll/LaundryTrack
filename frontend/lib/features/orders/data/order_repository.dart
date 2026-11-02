import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'order_model.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return OrderRepository(dio);
});

class OrderRepository {
  final Dio _dio;

  OrderRepository(this._dio);

  Future<List<OrderModel>> getOrders({
    int page = 1,
    int pageSize = 50,
    String? status,
    String? query,
    String? customerId,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
      if (status != null && status != 'all') 'status': status,
      if (query != null && query.isNotEmpty) 'q': query,
      if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
    };

    final response = await _dio.get(
      '/api/v1/orders',
      queryParameters: queryParams,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final List rawList = response.data['data'] as List;
      return rawList.map((item) => OrderModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal memuat daftar pesanan');
  }

  Future<OrderModel> getOrderDetail(String orderId) async {
    final response = await _dio.get('/api/v1/orders/$orderId');

    if (response.statusCode == 200 && response.data['success'] == true) {
      return OrderModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal memuat detail pesanan');
  }

  Future<OrderModel> createOrder(Map<String, dynamic> payload) async {
    final response = await _dio.post(
      '/api/v1/orders',
      data: payload,
    );

    if (response.statusCode == 201 && response.data['success'] == true) {
      return OrderModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal membuat pesanan baru');
  }

  Future<OrderModel> updateOrder(String orderId, Map<String, dynamic> payload) async {
    final response = await _dio.patch(
      '/api/v1/orders/$orderId',
      data: payload,
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return OrderModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal memperbarui catatan pesanan');
  }

  Future<OrderModel> transitionStatus(String orderId, String newStatus, {String? notes}) async {
    final response = await _dio.post(
      '/api/v1/orders/$orderId/status',
      data: {
        'status': newStatus,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return OrderModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal mengubah status pengerjaan pesanan');
  }

  Future<OrderModel> cancelOrder(String orderId, String reason) async {
    final response = await _dio.post(
      '/api/v1/orders/$orderId/cancel',
      data: {'reason': reason},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      return OrderModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal membatalkan pesanan');
  }

  Future<List<OrderStatusLogModel>> getOrderTimeline(String orderId) async {
    final response = await _dio.get('/api/v1/orders/$orderId/timeline');

    if (response.statusCode == 200 && response.data['success'] == true) {
      final List rawList = response.data['data'] as List;
      return rawList.map((item) => OrderStatusLogModel.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception(response.data['error']?['message'] ?? 'Gagal memuat timeline pesanan');
  }
}
