import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'receipt_model.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ReceiptRepository(dio);
});

class ReceiptRepository {
  final Dio _dio;

  ReceiptRepository(this._dio);

  String get baseUrl => _dio.options.baseUrl;

  String getThermalHtmlUrl(String orderId, {int width = 58}) {
    return '$baseUrl/api/v1/orders/$orderId/receipt/thermal?width=$width';
  }

  String getPdfUrl(String orderId) {
    return '$baseUrl/api/v1/orders/$orderId/receipt/pdf';
  }

  Future<ReceiptModel> getReceipt(String orderId) async {
    try {
      final response = await _dio.get('/api/v1/orders/$orderId/receipt');
      final data = response.data['data'] as Map<String, dynamic>;
      return ReceiptModel.fromJson(data);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ??
          'Gagal mengambil rincian nota pesanan';
      throw Exception(msg);
    }
  }

  Future<void> recordReprint(
    String orderId, {
    String printType = 'thermal',
    String? notes,
  }) async {
    try {
      await _dio.post(
        '/api/v1/orders/$orderId/receipt/reprint',
        data: {
          'print_type': printType,
          'notes': ?notes,
        },
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?['message'] ??
          'Gagal mencatat riwayat cetak ulang nota';
      throw Exception(msg);
    }
  }
}
