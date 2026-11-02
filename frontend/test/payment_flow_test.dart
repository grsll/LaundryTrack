import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/orders/data/order_model.dart';
import 'package:frontend/features/orders/presentation/order_detail_dialog.dart';
import 'package:frontend/features/orders/providers/order_provider.dart';
import 'package:frontend/features/payments/data/payment_model.dart';
import 'package:frontend/features/payments/presentation/payment_form_dialog.dart';
import 'package:frontend/features/payments/presentation/refund_form_dialog.dart';
import 'package:frontend/features/payments/providers/payment_provider.dart';

void main() {
  group('Payment & Refund Model Unit Tests', () {
    test('PaymentModel parses JSON correctly with status and method labels', () {
      final json = {
        'id': 'pay-123',
        'tenant_id': 'ten-1',
        'outlet_id': 'out-1',
        'order_id': 'ord-1',
        'received_by_id': 'usr-1',
        'received_by_name': 'Kasir Siti',
        'amount': '50000.00',
        'payment_method': 'qris',
        'reference_number': 'QRIS-998877',
        'status': 'partially_refunded',
        'paid_at': '2026-11-02T10:00:00Z',
        'notes': 'Pembayaran QRIS',
        'created_at': '2026-11-02T10:00:00Z',
        'total_refunded': '15000.00',
        'net_amount': '35000.00',
        'refunds': [
          {
            'id': 'ref-1',
            'tenant_id': 'ten-1',
            'outlet_id': 'out-1',
            'payment_id': 'pay-123',
            'order_id': 'ord-1',
            'refunded_by_id': 'usr-owner',
            'refunded_by_name': 'Pak Bos',
            'amount': '15000.00',
            'reason': 'Kompensasi pakaian luntur',
            'refunded_at': '2026-11-02T11:00:00Z',
            'created_at': '2026-11-02T11:00:00Z',
          }
        ],
      };

      final payment = PaymentModel.fromJson(json);

      expect(payment.id, 'pay-123');
      expect(payment.amount, 50000.0);
      expect(payment.totalRefunded, 15000.0);
      expect(payment.netAmount, 35000.0);
      expect(payment.methodLabel, 'QRIS');
      expect(payment.statusLabel, 'Refund Sebagian');
      expect(payment.receivedByName, 'Kasir Siti');
      expect(payment.refunds.length, 1);
      expect(payment.refunds.first.reason, 'Kompensasi pakaian luntur');
      expect(payment.refunds.first.refundedByName, 'Pak Bos');
      expect(PaymentModel.formatRupiah(50000.0), 'Rp 50.000');
      expect(PaymentModel.formatRupiah(-15000.0), '-Rp 15.000');
    });

    test('PaymentModel status and method helpers handle all cases', () {
      final cashPay = PaymentModel.fromJson({
        'id': 'p1',
        'tenant_id': 't1',
        'outlet_id': 'o1',
        'order_id': 'ord1',
        'amount': '10000.00',
        'payment_method': 'cash',
        'status': 'paid',
        'paid_at': '2026-11-02T10:00:00Z',
        'created_at': '2026-11-02T10:00:00Z',
      });
      expect(cashPay.methodLabel, 'Tunai');
      expect(cashPay.statusLabel, 'Lunas');

      final trfPay = PaymentModel.fromJson({
        'id': 'p2',
        'tenant_id': 't1',
        'outlet_id': 'o1',
        'order_id': 'ord1',
        'amount': '10000.00',
        'payment_method': 'bank_transfer',
        'status': 'refunded',
        'paid_at': '2026-11-02T10:00:00Z',
        'created_at': '2026-11-02T10:00:00Z',
      });
      expect(trfPay.methodLabel, 'Transfer Bank');
      expect(trfPay.statusLabel, 'Direfund');

      final debitPay = PaymentModel.fromJson({
        'id': 'p3',
        'tenant_id': 't1',
        'outlet_id': 'o1',
        'order_id': 'ord1',
        'amount': '10000.00',
        'payment_method': 'debit',
        'status': 'paid',
        'paid_at': '2026-11-02T10:00:00Z',
        'created_at': '2026-11-02T10:00:00Z',
      });
      expect(debitPay.methodLabel, 'Kartu Debit');
    });
  });

  group('Payment UI Widget Tests', () {
    testWidgets('PaymentFormDialog renders bill info and calculates cash change', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PaymentFormDialog(
                orderId: 'ord-test-1',
                orderNumber: 'LDR-20261102-0001',
                remainingAmount: 40000.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and remaining bill
      expect(find.text('Catat Pembayaran Kasir'), findsOneWidget);
      expect(find.text('Pesanan: LDR-20261102-0001'), findsOneWidget);
      expect(find.text('Rp 40.000'), findsWidgets);

      // Check method chips
      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Transfer Bank'), findsOneWidget);
      expect(find.text('Kartu Debit'), findsOneWidget);

      // Tap quick chip "Rp 50.000"
      final chip50k = find.text('Rp 50.000');
      if (chip50k.evaluate().isNotEmpty) {
        await tester.tap(chip50k);
        await tester.pumpAndSettle();

        // Kembalian should be 10.000
        expect(find.text('Kembalian:'), findsOneWidget);
        expect(find.text('Rp 10.000'), findsOneWidget);
      }
    });

    testWidgets('RefundFormDialog displays max refundable limit and validates reason', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final samplePayment = PaymentModel.fromJson({
        'id': 'pay-ref-test',
        'tenant_id': 't1',
        'outlet_id': 'o1',
        'order_id': 'ord-1',
        'amount': '30000.00',
        'payment_method': 'cash',
        'status': 'paid',
        'paid_at': '2026-11-02T10:00:00Z',
        'created_at': '2026-11-02T10:00:00Z',
        'net_amount': '30000.00',
        'total_refunded': '0.00',
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RefundFormDialog(
                payment: samplePayment,
                orderId: 'ord-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pengembalian Dana (Refund)'), findsOneWidget);
      expect(find.text('Maksimal yang dapat direfund:'), findsOneWidget);
      expect(find.text('Rp 30.000'), findsWidgets);

      // Tap Konfirmasi Refund without entering reason
      await tester.tap(find.text('Konfirmasi Refund'));
      await tester.pumpAndSettle();

      expect(find.text('Alasan refund wajib diisi'), findsOneWidget);
    });

    testWidgets('OrderDetailDialog renders payment summary and cashier button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final sampleOrder = OrderModel.fromJson({
        'id': 'ord-detail-1',
        'tenant_id': 'ten-1',
        'outlet_id': 'out-1',
        'outlet_name': 'Outlet Pusat',
        'customer_id': 'cust-1',
        'customer_name': 'Budi Santoso',
        'customer_phone': '081234567890',
        'order_number': 'LDR-20261102-0099',
        'status': 'received',
        'payment_status': 'partial',
        'received_at': '2026-11-02T10:00:00Z',
        'subtotal': '50000.00',
        'discount_amount': '0.00',
        'total_amount': '50000.00',
        'paid_amount': '20000.00',
        'remaining_amount': '30000.00',
        'items_count': 1,
        'created_at': '2026-11-02T10:00:00Z',
        'updated_at': '2026-11-02T10:00:00Z',
        'items': [],
        'status_logs': [],
      });

      final samplePayments = [
        PaymentModel.fromJson({
          'id': 'pay-hist-1',
          'tenant_id': 'ten-1',
          'outlet_id': 'out-1',
          'order_id': 'ord-detail-1',
          'received_by_id': 'u1',
          'received_by_name': 'Kasir Andi',
          'amount': '20000.00',
          'payment_method': 'cash',
          'status': 'paid',
          'paid_at': '2026-11-02T10:05:00Z',
          'created_at': '2026-11-02T10:05:00Z',
          'net_amount': '20000.00',
          'total_refunded': '0.00',
          'refunds': [],
        })
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderDetailProvider('ord-detail-1').overrideWith((ref) => Future.value(sampleOrder)),
            orderPaymentsProvider('ord-detail-1').overrideWith((ref) => Future.value(samplePayments)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrderDetailDialog(orderId: 'ord-detail-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LDR-20261102-0099'), findsOneWidget);
      expect(find.text('Catat Pembayaran Kasir'), findsOneWidget);
      expect(find.text('Riwayat Transaksi Pembayaran'), findsOneWidget);
      expect(find.textContaining('Kasir Andi'), findsOneWidget);
      expect(find.text('Rp 20.000'), findsWidgets);
    });
  });
}
