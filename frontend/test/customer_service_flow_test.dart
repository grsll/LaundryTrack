import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/customers/data/customer_model.dart';
import 'package:frontend/features/customers/presentation/customer_list_screen.dart';
import 'package:frontend/features/customers/presentation/customer_form_dialog.dart';
import 'package:frontend/features/customers/providers/customer_provider.dart';
import 'package:frontend/features/services/data/service_model.dart';
import 'package:frontend/features/services/presentation/service_list_screen.dart';
import 'package:frontend/features/services/presentation/service_form_dialog.dart';
import 'package:frontend/features/services/providers/service_provider.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_screen.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/auth/data/auth_model.dart';

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

class MockAuthNotifier extends AuthNotifier {
  final AuthState initialTestState;
  MockAuthNotifier(this.initialTestState);

  @override
  AuthState build() => initialTestState;
}

void main() {
  group('Customer & Service Model Tests', () {
    test('CustomerModel parses backend response correctly', () {
      final json = {
        'id': 'c1',
        'tenant_id': 't1',
        'name': 'Ibu Siti',
        'phone': '081234567890',
        'email': 'siti@gmail.com',
        'address': 'Jl. Melati No. 5',
        'notes': 'Pewangi lembut',
        'is_active': true,
        'created_at': '2026-11-01T20:00:00Z',
        'updated_at': '2026-11-01T20:00:00Z',
      };

      final customer = CustomerModel.fromJson(json);
      expect(customer.id, 'c1');
      expect(customer.name, 'Ibu Siti');
      expect(customer.phone, '081234567890');
      expect(customer.isActive, isTrue);
    });

    test('ServiceModel parses and formats currency correctly', () {
      final json = {
        'id': 's1',
        'tenant_id': 't1',
        'name': 'Cuci Komplit Reguler',
        'description': 'Cuci kering setrika',
        'price_type': 'per_kg',
        'unit': 'kg',
        'price': '8000.00',
        'estimated_duration_hours': 48,
        'is_active': true,
        'created_at': '2026-11-01T20:00:00Z',
        'updated_at': '2026-11-01T20:00:00Z',
      };

      final service = ServiceModel.fromJson(json);
      expect(service.id, 's1');
      expect(service.price, 8000.0);
      expect(service.formattedPrice, 'Rp 8.000 / kg');
      expect(service.estimatedDurationHours, 48);
    });
  });

  group('Customer UI Tests', () {
    testWidgets('CustomerListScreen renders search bar and add customer button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerProvider.overrideWith(
              () => MockCustomerNotifier(
                CustomerState(
                  customers: [
                    CustomerModel(
                      id: 'c1',
                      tenantId: 't1',
                      name: 'Ibu Fatimah',
                      phone: '081234567890',
                      isActive: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  ],
                  isLoading: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: CustomerListScreen(),
          ),
        ),
      );

      expect(find.text('Data Pelanggan'), findsOneWidget);
      expect(find.text('Pelanggan Baru'), findsOneWidget);
      expect(find.text('Ibu Fatimah'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
    });
  });

  group('Service UI Tests', () {
    testWidgets('ServiceListScreen renders filter chips and service cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceProvider.overrideWith(
              () => MockServiceNotifier(
                ServiceState(
                  services: [
                    ServiceModel(
                      id: 's1',
                      tenantId: 't1',
                      name: 'Cuci Komplit Reguler',
                      priceType: 'per_kg',
                      unit: 'kg',
                      price: 8000.0,
                      estimatedDurationHours: 48,
                      isActive: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  ],
                  isLoading: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: ServiceListScreen(),
          ),
        ),
      );

      expect(find.text('Katalog Layanan Laundry'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Kiloan (per kg)'), findsOneWidget);
      expect(find.text('Satuan (per pcs)'), findsOneWidget);
      expect(find.text('Layanan Baru'), findsOneWidget);
      expect(find.text('Cuci Komplit Reguler'), findsOneWidget);
      expect(find.text('Rp 8.000 / kg'), findsOneWidget);
      expect(find.text('48 jam'), findsOneWidget);
    });
  });

  group('Dashboard Quick Action Navigation Tests', () {
    testWidgets('DashboardScreen renders Phase 2 management action cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const mockAuthData = AuthDataModel(
        user: UserSummary(
          id: 'u1',
          fullName: 'Pak Agus',
          email: 'agus@laundry.com',
          phone: '08123456789',
          userType: 'staff',
          role: 'owner',
        ),
        tenant: TenantSummary(id: 't1', name: 'Agus Laundry', slug: 'agus-laundry'),
        outlet: OutletSummary(id: 'o1', name: 'Outlet Pusat'),
        subscription: SubscriptionSummary(plan: 'free', status: 'active'),
        tokens: TokensModel(accessToken: 'tk', refreshToken: 'rf', tokenType: 'bearer', expiresIn: 1800),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => MockAuthNotifier(const AuthState(isAuthenticated: true, authData: mockAuthData)),
            ),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      expect(find.text('Manajemen Operasional'), findsOneWidget);
      expect(find.text('Buka Data Pelanggan'), findsOneWidget);
      expect(find.text('Buka Katalog Layanan'), findsOneWidget);
    });

    testWidgets('CustomerListScreen renders cleanly on mobile viewport', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerProvider.overrideWith(
              () => MockCustomerNotifier(
                CustomerState(
                  customers: [
                    CustomerModel(
                      id: 'c1',
                      tenantId: 't1',
                      name: 'Ibu Fatimah Mobile Test',
                      phone: '081234567890',
                      isActive: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  ],
                  isLoading: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: CustomerListScreen(),
          ),
        ),
      );

      expect(find.text('Data Pelanggan'), findsOneWidget);
      expect(find.text('Ibu Fatimah Mobile Test'), findsOneWidget);
    });

    testWidgets('ServiceListScreen renders cleanly on mobile viewport', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceProvider.overrideWith(
              () => MockServiceNotifier(
                ServiceState(
                  services: [
                    ServiceModel(
                      id: 's1',
                      tenantId: 't1',
                      name: 'Cuci Mobile 24 Jam',
                      priceType: 'per_kg',
                      unit: 'kg',
                      price: 9000.0,
                      estimatedDurationHours: 24,
                      isActive: true,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  ],
                  isLoading: false,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: ServiceListScreen(),
          ),
        ),
      );

      expect(find.text('Katalog Layanan Laundry'), findsOneWidget);
      expect(find.text('Cuci Mobile 24 Jam'), findsOneWidget);
      expect(find.text('Rp 9.000 / kg'), findsOneWidget);
    });

    testWidgets('CustomerFormDialog shows validation error when name is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => CustomerFormDialog(onSave: (_) async => true),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap submit without typing name
      await tester.tap(find.text('Tambah Pelanggan'));
      await tester.pump();

      // Verify error text
      expect(find.text('Nama pelanggan wajib diisi'), findsOneWidget);
    });

    testWidgets('ServiceFormDialog validates required name and positive price', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => ServiceFormDialog(onSave: (_) async => true),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter name but zero price
      await tester.enterText(find.byType(TextFormField).at(0), 'Layanan Uji');
      await tester.enterText(find.byType(TextFormField).at(2), '0'); // Price field
      await tester.tap(find.text('Tambah Layanan'));
      await tester.pump();

      expect(find.text('Harga harus > 0'), findsOneWidget);
    });

    test('ServiceModel formattedPrice formats large numbers correctly', () {
      final service = ServiceModel(
        id: 's2',
        tenantId: 't1',
        name: 'Paket Karpet Masjid',
        priceType: 'per_item',
        unit: 'meter',
        price: 1500000.0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(service.formattedPrice, 'Rp 1.500.000 / meter');
    });
  });
}
