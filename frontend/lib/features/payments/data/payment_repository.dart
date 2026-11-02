import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'payment_model.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return PaymentRepository(dio);
});

class PaymentRepository {
  final Dio _dio;

  PaymentRepository(this._dio);

  String _extractDioError(DioException e, String defaultMessage) {
    if (e.response?.data is Map) {
      final map = e.response!.data as Map;
      if (map['error'] is Map && map['error']['message'] != null) {
        return map['error']['message'].toString();
      }
      if (map['message'] != null) {
        return map['message'].toString();
      }
    }
    return e.message ?? defaultMessage;
  }

  Future<PaymentModel> recordPayment(
    String orderId, {
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/orders/$orderId/payments',
        data: {
          'amount': amount.toStringAsFixed(2),
          'payment_method': paymentMethod,
          if (referenceNumber != null && referenceNumber.trim().isNotEmpty)
            'reference_number': referenceNumber.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        return PaymentModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      throw Exception(response.data['error']?['message'] ?? 'Gagal mencatat pembayaran');
    } on DioException catch (e) {
      throw Exception(_extractDioError(e, 'Gagal mencatat pembayaran'));
    }
  }

  Future<List<PaymentModel>> getOrderPayments(String orderId) async {
    try {
      final response = await _dio.get('/api/v1/orders/$orderId/payments');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List rawList = response.data['data'] as List;
        return rawList.map((item) => PaymentModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      throw Exception(response.data['error']?['message'] ?? 'Gagal memuat riwayat pembayaran');
    } on DioException catch (e) {
      throw Exception(_extractDioError(e, 'Gagal memuat riwayat pembayaran'));
    }
  }

  Future<RefundModel> recordRefund(
    String paymentId, {
    required double amount,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/payments/$paymentId/refunds',
        data: {
          'amount': amount.toStringAsFixed(2),
          'reason': reason.trim(),
        },
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        return RefundModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      throw Exception(response.data['error']?['message'] ?? 'Gagal mencatat pengembalian dana (refund)');
    } on DioException catch (e) {
      throw Exception(_extractDioError(e, 'Gagal mencatat pengembalian dana (refund)'));
    }
  }

  Future<PaymentModel> getPaymentDetail(String paymentId) async {
    try {
      final response = await _dio.get('/api/v1/payments/$paymentId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return PaymentModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      throw Exception(response.data['error']?['message'] ?? 'Gagal memuat detail pembayaran');
    } on DioException catch (e) {
      throw Exception(_extractDioError(e, 'Gagal memuat detail pembayaran'));
    }
  }
}
