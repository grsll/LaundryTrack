import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/customers/data/customer_model.dart';
import 'package:frontend/features/customers/providers/customer_provider.dart';
import 'package:frontend/features/orders/data/order_model.dart';
import 'package:frontend/features/orders/presentation/order_create_screen.dart';
import 'package:frontend/features/orders/presentation/order_detail_dialog.dart';
import 'package:frontend/features/orders/presentation/order_list_screen.dart';
import 'package:frontend/features/orders/providers/order_provider.dart';
import 'package:frontend/features/payments/providers/payment_provider.dart';
import 'package:frontend/features/services/data/service_model.dart';
import 'package:frontend/features/services/providers/service_provider.dart';

class MockOrderNotifier extends OrderNotifier {
  final OrderState initialTestState;
  MockOrderNotifier(this.initialTestState);

  @override
  OrderState build() => initialTestState;
}

class MockCustomerNotifier extends CustomerNotifier {
  final CustomerState initialTestState;
  MockCustomerNotifier(this.initialTestState);

  @override
  CustomerState build() => initialTestState;
}

class MockServiceNotifier extends ServiceNotifier {
  final ServiceState initialTestState;
  MockServiceNotifier(this.initialTestState);

  @override
  ServiceState build() => initialTestState;
}

void main() {
  group('OrderModel & Calculation Tests', () {
    test('OrderModel parses JSON correctly with snapshots and formatting', () {
      final json = {
        'id': 'ord-123',
        'tenant_id': 'ten-1',
        'outlet_id': 'out-1',
        'outlet_name': 'Outlet Pusat',
        'customer_id': 'cust-1',
        'customer_name': 'Pak Joko',
        'customer_phone': '081234567899',
        'order_number': 'LDR-20261102-0001',
        'status': 'received',
        'payment_status': 'unpaid',
        'received_at': '2026-11-02T10:00:00Z',
        'subtotal': '74500.00',
        'discount_amount': '5000.00',
        'total_amount': '69500.00',
        'paid_amount': '0.00',
        'remaining_amount': '69500.00',
        'notes': 'Catatan uji coba',
        'items_count': 2,
        'created_at': '2026-11-02T10:00:00Z',
        'updated_at': '2026-11-02T10:00:00Z',
        'items': [
          {
            'id': 'it-1',
            'service_id': 'svc-1',
            'service_name_snapshot': 'Cuci Komplit Reguler',
            'price_type_snapshot': 'per_kg',
            'unit_snapshot': 'kg',
            'unit_price_snapshot': '7000.00',
            'quantity': '3.50',
            'subtotal': '24500.00',
            'notes': 'Pewangi lavender',
            'created_at': '2026-11-02T10:00:00Z',
          },
          {
            'id': 'it-2',
            'service_id': 'svc-2',
            'service_name_snapshot': 'Bedcover Besar',
            'price_type_snapshot': 'per_item',
            'unit_snapshot': 'pcs',
            'unit_price_snapshot': '25000.00',
            'quantity': '2.00',
            'subtotal': '50000.00',
            'created_at': '2026-11-02T10:00:00Z',
          },
        ],
        'status_logs': [
          {
            'id': 'log-1',
            'previous_status': null,
            'new_status': 'received',
            'notes': 'Pesanan dibuat',
            'changed_by_name': 'Kasir Andi',
            'created_at': '2026-11-02T10:00:00Z',
          }
        ],
      };

      final order = OrderModel.fromJson(json);

      expect(order.id, 'ord-123');
      expect(order.orderNumber, 'LDR-20261102-0001');
      expect(order.status, 'received');
      expect(order.statusLabel, 'Diterima');
      expect(order.paymentStatusLabel, 'Belum Lunas');
      expect(order.nextPipelineStatus, 'washing');
      expect(order.nextPipelineLabel, 'Mulai Cuci');
      expect(order.totalAmount, 69500.00);
      expect(OrderModel.formatRupiah(order.totalAmount), 'Rp69.500');
      expect(order.items.length, 2);
      expect(order.items[0].serviceNameSnapshot, 'Cuci Komplit Reguler');
      expect(order.statusLogs.length, 1);
      expect(order.statusLogs[0].newStatus, 'received');
    });
  });

  group('OrderListScreen Widget Tests', () {
    testWidgets('renders empty state when no orders are present', (tester) async {
      final mockNotifier = MockOrderNotifier(
        const OrderState(orders: [], isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: OrderListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Manajemen Pesanan (Kasir)'), findsOneWidget);
      expect(find.text('Buat Pesanan Baru'), findsOneWidget);
      expect(find.text('Belum ada pesanan ditemukan'), findsOneWidget);
      expect(find.text('Semua Status'), findsOneWidget);
      expect(find.text('Diterima'), findsOneWidget);
    });

    testWidgets('renders order card with details and formats', (tester) async {
      final sampleOrder = OrderModel(
        id: 'ord-99',
        tenantId: 't1',
        outletId: 'o1',
        customerId: 'c1',
        customerName: 'Budi Santoso',
        customerPhone: '081234567890',
        orderNumber: 'LDR-20261102-0001',
        status: 'received',
        paymentStatus: 'unpaid',
        receivedAt: DateTime(2026, 11, 2, 10, 30),
        subtotal: 74500.0,
        discountAmount: 5000.0,
        totalAmount: 69500.0,
        paidAmount: 0.0,
        remainingAmount: 69500.0,
        itemsCount: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mockNotifier = MockOrderNotifier(
        OrderState(orders: [sampleOrder], isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: OrderListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LDR-20261102-0001'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Diterima'), findsNWidgets(2)); // in filter chip and card badge
      expect(find.text('Belum Lunas'), findsOneWidget);
      expect(find.text('Rp69.500'), findsOneWidget);
    });

    testWidgets('responsive layout on narrow mobile viewport (390x844)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockNotifier = MockOrderNotifier(
        const OrderState(orders: [], isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderProvider.overrideWith(() => mockNotifier),
          ],
          child: const MaterialApp(
            home: OrderListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Manajemen Pesanan (Kasir)'), findsOneWidget);
    });
  });

  group('OrderCreateScreen Widget Tests', () {
    testWidgets('renders creation form components with customers and services', (tester) async {
      final sampleCustomer = CustomerModel(
        id: 'c1',
        tenantId: 't1',
        name: 'Ahmad Dahlan',
        phone: '081299998888',
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final sampleService = ServiceModel(
        id: 's1',
        tenantId: 't1',
        name: 'Cuci Komplit Reguler',
        priceType: 'per_kg',
        unit: 'kg',
        price: 7000.0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final mockCustNotifier = MockCustomerNotifier(
        CustomerState(customers: [sampleCustomer], isLoading: false),
      );
      final mockSvcNotifier = MockServiceNotifier(
        ServiceState(services: [sampleService], isLoading: false),
      );
      final mockOrderNotifier = MockOrderNotifier(
        const OrderState(orders: [], isLoading: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerProvider.overrideWith(() => mockCustNotifier),
            serviceProvider.overrideWith(() => mockSvcNotifier),
            orderProvider.overrideWith(() => mockOrderNotifier),
          ],
          child: const MaterialApp(
            home: OrderCreateScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Buat Pesanan Baru (Kasir)'), findsOneWidget);
      expect(find.text('Pilih Pelanggan *'), findsOneWidget);
      expect(find.text('Layanan & Cucian *'), findsOneWidget);
      expect(find.text('Simpan & Proses Pesanan'), findsOneWidget);
      expect(find.text('Tambah Item'), findsOneWidget);
      expect(find.text('Pelanggan Baru'), findsOneWidget);
    });
  });

  group('OrderDetailDialog Widget Tests', () {
    testWidgets('renders pipeline, items snapshot, and action buttons', (tester) async {
      final sampleDetail = OrderModel(
        id: 'ord-detail-1',
        tenantId: 't1',
        outletId: 'o1',
        customerId: 'c1',
        customerName: 'Siti Nurhaliza',
        customerPhone: '081377778888',
        orderNumber: 'LDR-20261102-0088',
        status: 'received',
        paymentStatus: 'unpaid',
        receivedAt: DateTime(2026, 11, 2, 14, 0),
        subtotal: 50000.0,
        discountAmount: 0.0,
        totalAmount: 50000.0,
        paidAmount: 0.0,
        remainingAmount: 50000.0,
        itemsCount: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        items: [
          OrderItemModel(
            id: 'it-1',
            serviceId: 's1',
            serviceNameSnapshot: 'Cuci Komplit Reguler',
            priceTypeSnapshot: 'per_kg',
            unitSnapshot: 'kg',
            unitPriceSnapshot: 10000.0,
            quantity: 5.0,
            subtotal: 50000.0,
            createdAt: DateTime.now(),
          ),
        ],
        statusLogs: [
          OrderStatusLogModel(
            id: 'log-1',
            newStatus: 'received',
            notes: 'Pesanan masuk',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderDetailProvider('ord-detail-1').overrideWith((ref) => sampleDetail),
            orderPaymentsProvider('ord-detail-1').overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OrderDetailDialog(orderId: 'ord-detail-1'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('LDR-20261102-0088'), findsOneWidget);
      expect(find.text('Cuci Komplit Reguler'), findsOneWidget);
      expect(find.text('Mulai Cuci'), findsOneWidget);
      expect(find.text('Batalkan'), findsOneWidget);
      expect(find.text('Total Tagihan'), findsOneWidget);
    });
  });
}
