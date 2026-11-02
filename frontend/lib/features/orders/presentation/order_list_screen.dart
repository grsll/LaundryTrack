import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/order_model.dart';
import '../providers/order_provider.dart';
import 'order_detail_dialog.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _searchController = TextEditingController();

  static const _statusFilters = [
    {'key': 'all', 'label': 'Semua Status'},
    {'key': 'received', 'label': 'Diterima'},
    {'key': 'washing', 'label': 'Proses Cuci'},
    {'key': 'drying', 'label': 'Pengeringan'},
    {'key': 'ironing', 'label': 'Setrika'},
    {'key': 'packaging', 'label': 'Pengepakan'},
    {'key': 'ready', 'label': 'Siap Diambil'},
    {'key': 'completed', 'label': 'Selesai'},
    {'key': 'cancelled', 'label': 'Dibatalkan'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDetailDialog(String orderId) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailDialog(orderId: orderId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);
    final activeStatus = orderState.statusFilter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Pesanan (Kasir)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: () => ref.read(orderProvider.notifier).loadOrders(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders/create'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Buat Pesanan Baru'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search & Create Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari nomor nota atau nama pelanggan...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(orderProvider.notifier).loadOrders(query: '');
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (val) {
                          ref.read(orderProvider.notifier).loadOrders(query: val.trim());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(orderProvider.notifier).loadOrders(query: _searchController.text.trim());
                      },
                      icon: const Icon(Icons.search),
                      label: const Text('Cari'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status Filter Chips (Responsive Wrap)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _statusFilters.map((sf) {
                    final isSelected = activeStatus == sf['key'];
                    return ChoiceChip(
                      label: Text(sf['label']!),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) {
                          ref.read(orderProvider.notifier).loadOrders(status: sf['key']!);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Orders List / Empty State / Error State
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (orderState.isLoading && orderState.orders.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (orderState.errorMessage != null && orderState.orders.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                              const SizedBox(height: 12),
                              Text(
                                orderState.errorMessage!.replaceAll('Exception: ', ''),
                                style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => ref.read(orderProvider.notifier).loadOrders(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        );
                      }

                      final orders = orderState.orders;
                      if (orders.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'Belum ada pesanan ditemukan',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tekan tombol "Buat Pesanan Baru" untuk mencatat cucian pelanggan.',
                                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(orderProvider.notifier).loadOrders();
                        },
                        child: ListView.builder(
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return _buildOrderCard(order);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: InkWell(
        onTap: () => _openDetailDialog(order.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Order Number, Date, Status Chip (Responsive Wrap)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.orderNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(order.receivedAt),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: order.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: order.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Customer & Items Info
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    order.customerName ?? 'Pelanggan Umum',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (order.customerPhone != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '• ${order.customerPhone}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.dry_cleaning_outlined, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${order.itemsCount} jenis layanan dicatat',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Footer: Total & Payment Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: order.paymentStatusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          order.paymentStatusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: order.paymentStatusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'Total: ',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      Text(
                        OrderModel.formatRupiah(order.totalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
