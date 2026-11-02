import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/receipts/data/receipt_model.dart';
import 'package:frontend/features/receipts/presentation/receipt_dialog.dart';
import 'package:frontend/features/receipts/presentation/receipt_provider.dart';
import 'package:frontend/features/tracking/data/tracking_model.dart';
import 'package:frontend/features/tracking/presentation/tracking_provider.dart';
import 'package:frontend/features/tracking/presentation/tracking_screen.dart';

void main() {
  group('Tracking & Receipt Model Unit Tests', () {
    test('PublicTrackingModel parses JSON correctly with masked PII and timeline', () {
      final json = {
        'order_number': 'LDR-20261102-0001',
        'status': 'washing',
        'status_label': 'Sedang Dicuci',
        'payment_status': 'paid',
        'payment_status_label': 'Lunas',
        'customer_name_masked': 'Budi S*****',
        'customer_phone_masked': '0812****7890',
        'received_at': '2026-11-02T10:00:00Z',
        'estimated_completion_at': '2026-11-04T10:00:00Z',
        'outlet_name': 'Laundry Jaya - Outlet Pusat',
        'outlet_phone': '081299990000',
        'outlet_address': 'Jl. Melati No. 12',
        'items': [
          {
            'service_name': 'Cuci Komplit Reguler',
            'price_type': 'per_kg',
            'unit': 'kg',
            'quantity': '3.50',
            'unit_price': '7000.00',
            'subtotal': '24500.00',
            'notes': 'Wangi lavender',
          }
        ],
        'subtotal': '24500.00',
        'discount_amount': '0.00',
        'total_amount': '24500.00',
        'paid_amount': '24500.00',
        'remaining_amount': '0.00',
        'timeline': [
          {
            'status': 'received',
            'status_label': 'Diterima Kasir',
            'timestamp': '2026-11-02T10:00:00Z',
            'notes': 'Pesanan diterima di kasir',
          },
          {
            'status': 'washing',
            'status_label': 'Sedang Dicuci',
            'timestamp': '2026-11-02T10:30:00Z',
            'notes': 'Masuk mesin cuci 2',
          }
        ],
      };

      final tracking = PublicTrackingModel.fromJson(json);

      expect(tracking.orderNumber, 'LDR-20261102-0001');
      expect(tracking.status, 'washing');
      expect(tracking.statusLabel, 'Sedang Dicuci');
      expect(tracking.paymentStatus, 'paid');
      expect(tracking.customerNameMasked, 'Budi S*****');
      expect(tracking.customerPhoneMasked, '0812****7890');
      expect(tracking.totalAmount, 24500.0);
      expect(tracking.remainingAmount, 0.0);
      expect(tracking.items.length, 1);
      expect(tracking.items.first.serviceName, 'Cuci Komplit Reguler');
      expect(tracking.items.first.quantity, 3.5);
      expect(tracking.timeline.length, 2);
      expect(tracking.timeline.last.statusLabel, 'Sedang Dicuci');
    });

    test('ReceiptModel parses JSON correctly with reprint count and payments', () {
      final json = {
        'order_id': 'ord-123',
        'order_number': 'LDR-20261102-0001',
        'status': 'received',
        'status_label': 'Diterima Kasir',
        'payment_status': 'paid',
        'payment_status_label': 'Lunas',
        'received_at': '2026-11-02T10:00:00Z',
        'customer_name': 'Budi Santoso',
        'customer_phone': '081234567890',
        'outlet_name': 'Outlet Pusat',
        'tenant_name': 'Laundry Jaya',
        'cashier_name': 'Kasir Andi',
        'items': [
          {
            'service_name': 'Cuci Komplit',
            'price_type': 'per_kg',
            'unit': 'kg',
            'quantity': '2.00',
            'unit_price': '10000.00',
            'subtotal': '20000.00',
          }
        ],
        'subtotal': '20000.00',
        'discount_amount': '0.00',
        'total_amount': '20000.00',
        'paid_amount': '20000.00',
        'remaining_amount': '0.00',
        'payments': [
          {
            'id': 'pay-1',
            'amount': '20000.00',
            'payment_method': 'cash',
            'paid_at': '2026-11-02T10:05:00Z',
            'received_by_name': 'Kasir Andi',
          }
        ],
        'tracking_token': 'xyz_token_secret',
        'tracking_url': 'http://localhost:3000/#/track/xyz_token_secret',
        'reprint_count': 3,
      };

      final receipt = ReceiptModel.fromJson(json);

      expect(receipt.orderId, 'ord-123');
      expect(receipt.orderNumber, 'LDR-20261102-0001');
      expect(receipt.customerName, 'Budi Santoso');
      expect(receipt.reprintCount, 3);
      expect(receipt.payments.length, 1);
      expect(receipt.payments.first.paymentMethod, 'cash');
    });
  });

  group('Tracking & Receipt Widget Tests', () {
    testWidgets('TrackingScreen renders order status, masked PII, and items', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeTracking = PublicTrackingModel(
        orderNumber: 'LDR-20261102-0001',
        status: 'washing',
        statusLabel: 'Sedang Dicuci',
        paymentStatus: 'paid',
        paymentStatusLabel: 'Lunas',
        customerNameMasked: 'Budi S*****',
        customerPhoneMasked: '0812****7890',
        receivedAt: DateTime(2026, 11, 2, 10, 0),
        estimatedCompletionAt: DateTime(2026, 11, 4, 10, 0),
        outletName: 'Outlet Pusat',
        outletPhone: '081299990000',
        outletAddress: 'Jl. Melati No. 12',
        items: [
          PublicTrackingItemModel(
            serviceName: 'Cuci Komplit Reguler',
            priceType: 'per_kg',
            unit: 'kg',
            quantity: 3.5,
            unitPrice: 7000.0,
            subtotal: 24500.0,
          ),
        ],
        subtotal: 24500.0,
        discountAmount: 0.0,
        totalAmount: 24500.0,
        paidAmount: 24500.0,
        remainingAmount: 0.0,
        timeline: [
          PublicTrackingTimelineModel(
            status: 'received',
            statusLabel: 'Diterima Kasir',
            timestamp: DateTime(2026, 11, 2, 10, 0),
          ),
          PublicTrackingTimelineModel(
            status: 'washing',
            statusLabel: 'Sedang Dicuci',
            timestamp: DateTime(2026, 11, 2, 10, 30),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicTrackingProvider('fake_token').overrideWith(
              (ref) async => fakeTracking,
            ),
          ],
          child: const MaterialApp(
            home: TrackingScreen(token: 'fake_token'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LDR-20261102-0001'), findsOneWidget);
      expect(find.text('Sedang Dicuci'), findsWidgets);
      expect(find.textContaining('Budi S*****'), findsOneWidget);
      expect(find.textContaining('0812****7890'), findsOneWidget);
      expect(find.text('Cuci Komplit Reguler'), findsOneWidget);
      expect(find.text('Lunas'), findsWidgets);
      expect(find.text('Hubungi WhatsApp Outlet'), findsOneWidget);
    });

    testWidgets('ReceiptShareDialog renders print, PDF, WhatsApp, and copy options', (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeReceipt = ReceiptModel(
        orderId: 'ord-123',
        orderNumber: 'LDR-20261102-0001',
        status: 'received',
        statusLabel: 'Diterima Kasir',
        paymentStatus: 'paid',
        paymentStatusLabel: 'Lunas',
        receivedAt: DateTime(2026, 11, 2, 10, 0),
        customerName: 'Budi Santoso',
        customerPhone: '081234567890',
        outletName: 'Outlet Pusat',
        tenantName: 'Laundry Jaya',
        cashierName: 'Kasir Andi',
        items: [
          ReceiptItemModel(
            serviceName: 'Cuci Komplit',
            priceType: 'per_kg',
            unit: 'kg',
            quantity: 2.0,
            unitPrice: 10000.0,
            subtotal: 20000.0,
          ),
        ],
        subtotal: 20000.0,
        discountAmount: 0.0,
        totalAmount: 20000.0,
        paidAmount: 20000.0,
        remainingAmount: 0.0,
        payments: [],
        trackingToken: 'token_123',
        trackingUrl: 'http://localhost:3000/#/track/token_123',
        reprintCount: 1,
      );

      final fakeLink = TrackingLinkModel(
        orderId: 'ord-123',
        orderNumber: 'LDR-20261102-0001',
        trackingToken: 'token_123',
        trackingUrl: 'http://localhost:3000/#/track/token_123',
        whatsappShareText: 'Halo Kak Budi, cek cucian Anda...',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            receiptDetailProvider('ord-123').overrideWith((ref) async => fakeReceipt),
            trackingLinkProvider('ord-123').overrideWith((ref) async => fakeLink),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReceiptShareDialog(orderId: 'ord-123'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nota #LDR-20261102-0001'), findsOneWidget);
      expect(find.text('Cetak Thermal (58mm)'), findsOneWidget);
      expect(find.text('Unduh PDF'), findsOneWidget);
      expect(find.text('Kirim WhatsApp'), findsOneWidget);
      expect(find.text('Salin Link Tracking'), findsOneWidget);
      expect(find.textContaining('Dicetak ulang 1 kali'), findsOneWidget);
    });

    testWidgets('TrackingScreen shows error card on invalid token', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicTrackingProvider('invalid_token').overrideWith(
              (ref) => Future.error(Exception('Pesanan tidak ditemukan')),
            ),
          ],
          child: const MaterialApp(
            home: TrackingScreen(token: 'invalid_token'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tautan Pelacakan Tidak Valid'), findsOneWidget);
      expect(find.text('Pesanan tidak ditemukan'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('TrackingScreen renders status timeline history items', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeTracking = PublicTrackingModel(
        orderNumber: 'LDR-20261102-0001',
        status: 'washing',
        statusLabel: 'Sedang Dicuci',
        paymentStatus: 'paid',
        paymentStatusLabel: 'Lunas',
        customerNameMasked: 'Budi S*****',
        customerPhoneMasked: '0812****7890',
        receivedAt: DateTime(2026, 11, 2, 10, 0),
        outletName: 'Laundry Jaya - Outlet Pusat',
        items: [],
        subtotal: 20000.0,
        discountAmount: 0.0,
        totalAmount: 20000.0,
        paidAmount: 20000.0,
        remainingAmount: 0.0,
        timeline: [
          PublicTrackingTimelineModel(
            status: 'received',
            statusLabel: 'Diterima Kasir',
            timestamp: DateTime(2026, 11, 2, 10, 0),
            notes: 'Diterima oleh Kasir Siti',
          ),
          PublicTrackingTimelineModel(
            status: 'washing',
            statusLabel: 'Sedang Dicuci',
            timestamp: DateTime(2026, 11, 2, 10, 30),
            notes: 'Proses cuci dimulai',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicTrackingProvider('valid_token').overrideWith((ref) async => fakeTracking),
          ],
          child: const MaterialApp(
            home: TrackingScreen(token: 'valid_token'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Riwayat Proses Pengerjaan'), findsOneWidget);
      expect(find.text('Diterima oleh Kasir Siti'), findsOneWidget);
      expect(find.text('Proses cuci dimulai'), findsOneWidget);
    });
  });
}
