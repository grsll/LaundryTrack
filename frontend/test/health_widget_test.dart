import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/features/health/data/health_model.dart';
import 'package:frontend/features/health/presentation/health_screen.dart';

void main() {
  group('HealthModel Unit Tests', () {
    test('fromJson handles complete valid payload', () {
      final json = {
        'status': 'healthy',
        'app_name': 'LaundryTrack',
        'environment': 'development',
        'version': '1.0.0',
        'database': 'healthy',
        'timestamp': '2026-11-01T20:00:00Z',
      };
      final model = HealthModel.fromJson(json);
      expect(model.status, 'healthy');
      expect(model.appName, 'LaundryTrack');
      expect(model.environment, 'development');
      expect(model.version, '1.0.0');
      expect(model.database, 'healthy');
      expect(model.timestamp, '2026-11-01T20:00:00Z');
    });

    test('fromJson handles partial or missing fields with safe defaults', () {
      final json = <String, dynamic>{};
      final model = HealthModel.fromJson(json);
      expect(model.status, 'unknown');
      expect(model.appName, '');
      expect(model.database, 'unknown');
    });
  });

  group('HealthScreen Widget Tests', () {
    testWidgets('renders healthy status when services are operational', (WidgetTester tester) async {
      const mockHealth = HealthModel(
        status: 'healthy',
        appName: 'LaundryTrack',
        environment: 'development',
        version: '1.0.0',
        database: 'healthy',
        timestamp: '2026-11-01T20:00:00Z',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            healthProvider.overrideWith((ref) => Future.value(mockHealth)),
          ],
          child: const MaterialApp(
            home: HealthScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('LaundryTrack'), findsOneWidget);
      expect(find.text('Pemeriksaan Status Layanan'), findsOneWidget);
      expect(find.text('Backend API Service'), findsOneWidget);
      expect(find.text('Online & Responsif'), findsOneWidget);
      expect(find.text('Database PostgreSQL (VPS)'), findsOneWidget);
      expect(find.text('Terhubung & Aktif'), findsOneWidget);
      expect(find.text('Peta Jalan Pengembangan (Phase Gates)'), findsOneWidget);
      expect(find.textContaining('Phase 8 — Audit Menyeluruh'), findsOneWidget);
    });

    testWidgets('renders degraded status when database is unreachable', (WidgetTester tester) async {
      const degradedHealth = HealthModel(
        status: 'degraded',
        appName: 'LaundryTrack',
        environment: 'development',
        version: '1.0.0',
        database: 'unreachable',
        timestamp: '2026-11-01T20:00:00Z',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            healthProvider.overrideWith((ref) => Future.value(degradedHealth)),
          ],
          child: const MaterialApp(
            home: HealthScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Degraded'), findsOneWidget);
      expect(find.text('Tidak Terjangkau'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNWidgets(2));
    });

    testWidgets('renders loading state while awaiting API probe', (WidgetTester tester) async {
      final completer = Completer<HealthModel>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            healthProvider.overrideWith((ref) => completer.future),
          ],
          child: const MaterialApp(
            home: HealthScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Menghubungi Backend FastAPI & Database VPS...'), findsOneWidget);

      // Complete future to prevent dangling
      completer.complete(const HealthModel(
        status: 'healthy',
        appName: 'LaundryTrack',
        environment: 'development',
        version: '1.0.0',
        database: 'healthy',
        timestamp: '2026-11-01T20:00:00Z',
      ));
      await tester.pump();
    });

    testWidgets('renders error banner when backend connection fails', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            healthProvider.overrideWith((ref) => Future.error(
              Exception('Connection refused'),
              StackTrace.empty,
            )),
          ],
          child: const MaterialApp(
            home: HealthScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Gagal terhubung ke Backend API'), findsOneWidget);
    });
  });
}
