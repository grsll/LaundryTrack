import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/payment_model.dart';
import '../data/payment_repository.dart';

final orderPaymentsProvider = FutureProvider.autoDispose.family<List<PaymentModel>, String>((ref, orderId) async {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getOrderPayments(orderId);
});

class PaymentNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<PaymentModel?> recordPayment(
    String orderId, {
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final payment = await repo.recordPayment(
        orderId,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(orderPaymentsProvider(orderId));
      return payment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<RefundModel?> recordRefund(
    String paymentId,
    String orderId, {
    required double amount,
    required String reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(paymentRepositoryProvider);
      final refund = await repo.recordRefund(
        paymentId,
        amount: amount,
        reason: reason,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(orderPaymentsProvider(orderId));
      return refund;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final paymentNotifierProvider = NotifierProvider<PaymentNotifier, AsyncValue<void>>(PaymentNotifier.new);
