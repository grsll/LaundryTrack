import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.authData?.user;
    final tenant = authState.authData?.tenant;
    final outlet = authState.authData?.outlet;
    final subscription = authState.authData?.subscription;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_laundry_service, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                tenant?.name ?? 'LaundryTrack',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'Paket ${subscription?.plan.toUpperCase() ?? "FREE"}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.health_and_safety_outlined),
            tooltip: 'Status Server & DB',
            onPressed: () => context.push('/health'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Welcome Banner
                Card(
                  color: AppTheme.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selamat Datang, ${user?.fullName ?? "Pengguna"}!',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Outlet Aktif: ${outlet?.name ?? "Outlet Utama"} • Peran: ${user?.role.toUpperCase() ?? "OWNER"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Responsive Stat Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 640;
                    const items = [
                      _StatCard(
                        title: 'Pesanan Aktif',
                        value: '0',
                        subtitle: 'Phase 3 (Manajemen Pesanan)',
                        icon: Icons.receipt_long,
                        color: AppTheme.primaryBlue,
                      ),
                      _StatCard(
                        title: 'Siap Diambil',
                        value: '0',
                        subtitle: 'Phase 3 (Status Pesanan)',
                        icon: Icons.check_circle_outline,
                        color: AppTheme.successGreen,
                      ),
                      _StatCard(
                        title: 'Pendapatan Hari Ini',
                        value: 'Rp0',
                        subtitle: 'Phase 4 (Pembayaran)',
                        icon: Icons.payments_outlined,
                        color: AppTheme.warningOrange,
                      ),
                    ];

                    if (isNarrow) {
                      return Column(
                        children: items
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: item,
                                ))
                            .toList(),
                      );
                    }

                    return Row(
                      children: items
                          .map((item) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                  child: item,
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Operational Quick Action Cards (Phase 2 Master Data)
                const Text(
                  'Manajemen Operasional',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    final actionCards = [
                      _QuickActionCard(
                        title: 'Data Pelanggan',
                        subtitle: 'Pencatatan pelanggan, kontak WhatsApp, & preferensi laundry',
                        icon: Icons.people_alt_outlined,
                        color: AppTheme.primaryBlue,
                        buttonText: 'Buka Data Pelanggan',
                        onTap: () => context.push('/customers'),
                      ),
                      _QuickActionCard(
                        title: 'Katalog Layanan',
                        subtitle: 'Daftar tarif cuci kiloan (per kg) & satuan (per pcs)',
                        icon: Icons.dry_cleaning_outlined,
                        color: AppTheme.successGreen,
                        buttonText: 'Buka Katalog Layanan',
                        onTap: () => context.push('/services'),
                      ),
                    ];

                    if (isMobile) {
                      return Column(
                        children: actionCards
                            .map((card) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: card,
                                ))
                            .toList(),
                      );
                    }

                    return Row(
                      children: actionCards
                          .map((card) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                  child: card,
                                ),
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Active Session Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Sesi Terautentikasi (Phase 1 Baseline)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(label: 'Tenant ID:', value: tenant?.id ?? '-'),
                        const Divider(height: 16),
                        _InfoRow(label: 'Bisnis Slug:', value: tenant?.slug ?? '-'),
                        const Divider(height: 16),
                        _InfoRow(label: 'User Email:', value: user?.email ?? '-'),
                        const Divider(height: 16),
                        _InfoRow(label: 'No. WhatsApp:', value: user?.phone ?? '-'),
                        const Divider(height: 16),
                        _InfoRow(label: 'Status Multi-Tenancy:', value: 'Terisolasi Penuh di Backend (JWT Verified)'),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 22),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String buttonText;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withAlpha(25),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                child: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
