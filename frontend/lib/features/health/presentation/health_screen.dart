import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/health_model.dart';

final healthProvider = FutureProvider.autoDispose<HealthModel>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '${AppConstants.apiV1Prefix}/health',
    options: Options(
      validateStatus: (status) => status != null && (status == 200 || status == 503),
    ),
  );
  return HealthModel.fromJson(response.data as Map<String, dynamic>);
});

class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(healthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_laundry_service, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Text(
              'LaundryTrack',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Periksa Ulang Status',
            onPressed: () => ref.refresh(healthProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Card(
                  color: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sistem Manajemen Operasional Laundry',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Fondasi Proyek (Phase 0) — Status Koneksi Layanan & Basis Data Terpadu',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Health Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pemeriksaan Status Layanan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        healthAsync.when(
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text(
                                    'Menghubungi Backend FastAPI & Database VPS...',
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          error: (err, stack) => Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppTheme.errorRed),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Gagal terhubung ke Backend API: $err\nPastikan backend FastAPI sudah berjalan di port 8000.',
                                    style: const TextStyle(color: AppTheme.errorRed),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          data: (health) => Column(
                            children: [
                              _StatusRow(
                                title: 'Backend API Service',
                                subtitle: '${health.appName} v${health.version} (${health.environment})',
                                isHealthy: health.status == 'healthy',
                                healthyText: 'Online & Responsif',
                                unhealthyText: 'Degraded',
                              ),
                              const Divider(height: 24),
                              _StatusRow(
                                title: 'Database PostgreSQL (VPS)',
                                subtitle: 'Database: laundrytrack_db @ 45.66.153.146:5432',
                                isHealthy: health.database == 'healthy',
                                healthyText: 'Terhubung & Aktif',
                                unhealthyText: 'Tidak Terjangkau',
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Waktu Pemeriksaan:',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                  Text(
                                    health.timestamp,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Roadmap Checklist Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Peta Jalan Pengembangan (Phase Gates)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _PhaseItem(
                          title: 'Phase 0 — Fondasi Proyek (Monorepo, DB VPS, Alembic, Flutter Web)',
                          isCompleted: true,
                        ),
                        _PhaseItem(
                          title: 'Phase 1 — Auth dan Multi-Tenancy (Tenant Isolation)',
                          isCompleted: false,
                        ),
                        _PhaseItem(
                          title: 'Phase 2 — Pelanggan dan Layanan Laundry',
                          isCompleted: false,
                        ),
                        _PhaseItem(
                          title: 'Phase 3 — Manajemen Pesanan (POS Kasir & Snapshot Harga)',
                          isCompleted: false,
                        ),
                        _PhaseItem(
                          title: 'Phase 4 — Pembayaran Parsial, Lunas & Riwayat Refund',
                          isCompleted: false,
                        ),
                        _PhaseItem(
                          title: 'Phase 5 — Tracking Publik (QR Code) & Nota Thermal Print',
                          isCompleted: false,
                        ),
                        _PhaseItem(
                          title: 'Phase 6 — Portal Pelanggan Dasar',
                          isCompleted: false,
                        ),
                        _PhaseItem(
                          title: 'Phase 7 — Dashboard, Laporan & Paket SaaS Langganan',
                          isCompleted: false,
                        ),
                        _PhaseItem(
                          title: 'Phase 8 — Audit Menyeluruh & Panduan Deployment',
                          isCompleted: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isHealthy;
  final String healthyText;
  final String unhealthyText;

  const _StatusRow({
    required this.title,
    required this.subtitle,
    required this.isHealthy,
    required this.healthyText,
    required this.unhealthyText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isHealthy ? Icons.check_circle : Icons.cancel,
          color: isHealthy ? AppTheme.successGreen : AppTheme.errorRed,
          size: 28,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHealthy ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHealthy ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: Text(
            isHealthy ? healthyText : unhealthyText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isHealthy ? AppTheme.successGreen : AppTheme.errorRed,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseItem extends StatelessWidget {
  final String title;
  final bool isCompleted;

  const _PhaseItem({
    required this.title,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
            color: isCompleted ? AppTheme.primaryBlue : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                color: isCompleted ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
