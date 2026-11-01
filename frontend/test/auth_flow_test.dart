import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/auth/data/auth_model.dart';
import 'package:frontend/features/auth/presentation/login_screen.dart';
import 'package:frontend/features/auth/presentation/register_screen.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/dashboard/presentation/dashboard_screen.dart';

class MockAuthNotifier extends AuthNotifier {
  final AuthState initialTestState;
  MockAuthNotifier(this.initialTestState);

  @override
  AuthState build() => initialTestState;
}

void main() {
  group('Auth Model Unit Tests', () {
    test('AuthDataModel parses complete backend response', () {
      final json = {
        'user': {
          'id': 'u1',
          'full_name': 'Budi Santoso',
          'email': 'budi@test.com',
          'phone': '081234567890',
          'user_type': 'staff',
          'role': 'owner',
        },
        'tenant': {
          'id': 't1',
          'name': 'Berkah Laundry',
          'slug': 'berkah-laundry',
        },
        'outlet': {
          'id': 'o1',
          'name': 'Outlet Utama',
        },
        'subscription': {
          'plan': 'free',
          'status': 'active',
        },
        'tokens': {
          'access_token': 'jwt_access',
          'refresh_token': 'jwt_refresh',
          'token_type': 'bearer',
          'expires_in': 1800,
        },
      };

      final authData = AuthDataModel.fromJson(json);
      expect(authData.user.fullName, 'Budi Santoso');
      expect(authData.user.role, 'owner');
      expect(authData.tenant.name, 'Berkah Laundry');
      expect(authData.outlet.name, 'Outlet Utama');
      expect(authData.subscription.plan, 'free');
      expect(authData.tokens.accessToken, 'jwt_access');
    });
  });

  group('Auth UI Screen Tests', () {
    testWidgets('LoginScreen renders inputs and brand header', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('LaundryTrack'), findsOneWidget);
      expect(find.text('Masuk ke Akun Bisnis'), findsOneWidget);
      expect(find.text('Email atau Nomor Telepon'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
      expect(find.text('Masuk ke Dashboard'), findsOneWidget);
      expect(find.text('Daftar Sekarang'), findsOneWidget);
    });

    testWidgets('RegisterScreen renders owner and business fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      expect(find.text('1. Data Pemilik Laundry'), findsOneWidget);
      expect(find.text('Nama Lengkap Pemilik'), findsOneWidget);
      expect(find.text('Email Bisnis'), findsOneWidget);
      expect(find.text('Nomor WhatsApp'), findsOneWidget);
      expect(find.text('2. Data Bisnis & Outlet Pertama'), findsOneWidget);
      expect(find.text('Nama Usaha Laundry'), findsOneWidget);
      expect(find.text('Daftarkan Bisnis Laundry'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders tenant and user details when authenticated', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const mockAuthData = AuthDataModel(
        user: UserSummary(
          id: 'u1',
          fullName: 'Siti Rahma',
          email: 'siti@laundry.com',
          phone: '081233344455',
          userType: 'staff',
          role: 'owner',
        ),
        tenant: TenantSummary(
          id: 't1',
          name: 'Bersih Express',
          slug: 'bersih-express',
        ),
        outlet: OutletSummary(
          id: 'o1',
          name: 'Outlet Pusat',
        ),
        subscription: SubscriptionSummary(
          plan: 'free',
          status: 'active',
        ),
        tokens: TokensModel(
          accessToken: 'token',
          refreshToken: 'refresh',
          tokenType: 'bearer',
          expiresIn: 1800,
        ),
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

      expect(find.text('Bersih Express'), findsOneWidget);
      expect(find.text('Selamat Datang, Siti Rahma!'), findsOneWidget);
      expect(find.textContaining('Outlet Pusat'), findsOneWidget);
      expect(find.text('Paket FREE'), findsOneWidget);
      expect(find.text('Informasi Sesi Terautentikasi (Phase 1 Baseline)'), findsOneWidget);
      expect(find.text('siti@laundry.com'), findsOneWidget);
    });

    testWidgets('LoginScreen renders cleanly on mobile viewport without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      expect(find.text('LaundryTrack'), findsOneWidget);
      expect(find.text('Masuk ke Akun Bisnis'), findsOneWidget);
      expect(find.text('Masuk ke Dashboard'), findsOneWidget);
    });

    testWidgets('LoginScreen displays validation error when submitting empty fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Tap submit with empty fields
      await tester.tap(find.text('Masuk ke Dashboard'));
      await tester.pumpAndSettle();

      expect(find.text('Email atau nomor telepon wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
    });
  });
}
