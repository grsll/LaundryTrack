import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tracking_provider.dart';

class TrackingScreen extends ConsumerWidget {
  final String token;

  const TrackingScreen({
    super.key,
    required this.token,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.blue;
      case 'washing':
        return Colors.teal;
      case 'drying':
        return Colors.amber.shade800;
      case 'ironing':
        return Colors.deepOrange;
      case 'packaging':
        return Colors.indigo;
      case 'ready':
        return Colors.green;
      case 'completed':
        return Colors.blueGrey;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'received':
        return Icons.inventory_2_outlined;
      case 'washing':
        return Icons.local_laundry_service;
      case 'drying':
        return Icons.wb_sunny_outlined;
      case 'ironing':
        return Icons.iron;
      case 'packaging':
        return Icons.checkroom;
      case 'ready':
        return Icons.task_alt;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  int _getStatusStepIndex(String status) {
    switch (status) {
      case 'received':
        return 0;
      case 'washing':
        return 1;
      case 'drying':
        return 2;
      case 'ironing':
        return 3;
      case 'packaging':
        return 4;
      case 'ready':
      case 'completed':
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingAsync = ref.watch(publicTrackingProvider(token));
    final currencyFormatter =
        NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);
    final dateFormatter = DateFormat('dd/MM/yyyy, HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_laundry_service, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text(
              'LaundryTrack',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: trackingAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Memuat status pesanan...'),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.red.shade100),
              ),
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Tautan Pelacakan Tidak Valid',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString().replaceAll('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          ref.refresh(publicTrackingProvider(token)),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        data: (tracking) {
          final statusColor = _getStatusColor(tracking.status);
          final currentStep = _getStatusStepIndex(tracking.status);
          final isCancelled = tracking.status == 'cancelled';

          final steps = [
            {'title': 'Diterima', 'icon': Icons.inventory_2_outlined},
            {'title': 'Dicuci', 'icon': Icons.local_laundry_service},
            {'title': 'Dikeringkan', 'icon': Icons.wb_sunny_outlined},
            {'title': 'Disetrika', 'icon': Icons.iron},
            {'title': 'Dikemas', 'icon': Icons.checkroom},
            {'title': 'Siap Diambil', 'icon': Icons.task_alt},
          ];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(publicTrackingProvider(token).future),
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                  // Status Hero Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    color: statusColor.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Nomor Pesanan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      tracking.orderNumber,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getStatusIcon(tracking.status),
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      tracking.statusLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Tanggal Masuk',
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.black54),
                                    ),
                                    Text(
                                      dateFormatter.format(tracking.receivedAt),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (tracking.estimatedCompletionAt != null)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Estimasi Selesai',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54),
                                      ),
                                      Text(
                                        dateFormatter.format(
                                            tracking.estimatedCompletionAt!),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress Pipeline Stepper Card
                  if (!isCancelled)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tahapan Pengerjaan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: List.generate(steps.length, (i) {
                                      final isDone = i <= currentStep;
                                      final isCurrent = i == currentStep;

                                      return Row(
                                        children: [
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircleAvatar(
                                                radius: isCurrent ? 20 : 16,
                                                backgroundColor: isDone
                                                    ? (isCurrent
                                                        ? Colors.blueAccent
                                                        : Colors.blue.shade100)
                                                    : Colors.grey.shade200,
                                                child: Icon(
                                                  steps[i]['icon'] as IconData,
                                                  size: isCurrent ? 20 : 16,
                                                  color: isCurrent
                                                      ? Colors.white
                                                      : (isDone
                                                          ? Colors.blueAccent
                                                          : Colors.grey),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                steps[i]['title'] as String,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: isCurrent
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isDone
                                                      ? Colors.black87
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (i < steps.length - 1)
                                            Container(
                                              width: 32,
                                              height: 2,
                                              color: i < currentStep
                                                  ? Colors.blueAccent
                                                  : Colors.grey.shade300,
                                              margin: const EdgeInsets.only(
                                                  bottom: 20),
                                            ),
                                        ],
                                      );
                                    }),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Customer & Outlet Info
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informasi Pelanggan & Outlet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pelanggan: ${tracking.customerNameMasked} (${tracking.customerPhoneMasked})',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.storefront_outlined,
                                  size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Outlet: ${tracking.outletName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (tracking.outletAddress != null) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 26.0),
                              child: Text(
                                tracking.outletAddress!,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          ],
                          if (tracking.outletPhone != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final phone = tracking.outletPhone!
                                    .replaceAll(RegExp(r'\D'), '');
                                final waPhone = phone.startsWith('0')
                                    ? '62${phone.substring(1)}'
                                    : phone;
                                final uri = Uri.parse(
                                    'https://wa.me/$waPhone?text=Halo%20${tracking.outletName},%20saya%20ingin%20menanyakan%20status%20pesanan%20${tracking.orderNumber}');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.chat_bubble_outline,
                                  size: 18, color: Colors.green),
                              label: const Text('Hubungi WhatsApp Outlet'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade800,
                                side: BorderSide(color: Colors.green.shade200),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Order Items Breakdown Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rincian Cucian',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...tracking.items.map((item) {
                            final qtyStr = item.quantity % 1 != 0
                                ? item.quantity.toStringAsFixed(1)
                                : item.quantity.toStringAsFixed(0);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.serviceName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '$qtyStr ${item.unit} x ${currencyFormatter.format(item.unitPrice)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currencyFormatter.format(item.subtotal),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 24),
                          // Financial Summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                              Text(currencyFormatter.format(tracking.subtotal),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          if (tracking.discountAmount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Diskon',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.green)),
                                Text(
                                    '-${currencyFormatter.format(tracking.discountAmount)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.green)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Tagihan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                currencyFormatter.format(tracking.totalAmount),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sudah Dibayar',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                              Text(
                                  currencyFormatter.format(tracking.paidAmount),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Sisa Tagihan',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                currencyFormatter
                                    .format(tracking.remainingAmount),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: tracking.remainingAmount > 0
                                      ? Colors.orange.shade800
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: tracking.remainingAmount <= 0
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: tracking.remainingAmount <= 0
                                      ? Colors.green.shade200
                                      : Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                tracking.paymentStatusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: tracking.remainingAmount <= 0
                                      ? Colors.green.shade800
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (tracking.timeline.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Riwayat Proses Pengerjaan',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...tracking.timeline.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final item = entry.value;
                              final isLast = idx == tracking.timeline.length - 1;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: isLast
                                              ? Colors.blueAccent
                                              : Colors.grey.shade400,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      if (!isLast)
                                        Container(
                                          width: 2,
                                          height: 32,
                                          color: Colors.grey.shade300,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.statusLabel,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: isLast
                                                      ? Colors.blueAccent
                                                      : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                dateFormatter.format(item.timestamp),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (item.notes != null &&
                                              item.notes!.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.notes!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'LaundryTrack • Solusi Cerdas Manajemen & Pelacakan Laundry',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
        },
      ),
    );
  }
}
