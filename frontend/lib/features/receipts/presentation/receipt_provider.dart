import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/receipt_model.dart';
import '../data/receipt_repository.dart';

final receiptDetailProvider =
    FutureProvider.family<ReceiptModel, String>((ref, orderId) async {
  final repo = ref.watch(receiptRepositoryProvider);
  return repo.getReceipt(orderId);
});
