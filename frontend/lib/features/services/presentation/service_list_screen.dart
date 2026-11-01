import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/service_model.dart';
import '../providers/service_provider.dart';
import 'service_form_dialog.dart';

class ServiceListScreen extends ConsumerStatefulWidget {
  const ServiceListScreen({super.key});

  @override
  ConsumerState<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends ConsumerState<ServiceListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFormDialog([ServiceModel? service]) {
    showDialog(
      context: context,
      builder: (context) => ServiceFormDialog(
        service: service,
        onSave: (payload) {
          if (service == null) {
            return ref.read(serviceProvider.notifier).createService(payload);
          } else {
            return ref.read(serviceProvider.notifier).updateService(service.id, payload);
          }
        },
      ),
    );
  }

  void _confirmArchive(ServiceModel service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan Layanan?'),
        content: Text(
          'Layanan "${service.name}" tidak akan dapat dipilih untuk pesanan baru. Transaksi lama tetap mempertahankan harga saat pesanan dibuat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningOrange),
            onPressed: () {
              Navigator.pop(context);
              ref.read(serviceProvider.notifier).archiveService(service.id);
            },
            child: const Text('Nonaktifkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serviceState = ref.watch(serviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Layanan Laundry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(serviceProvider.notifier).loadServices(),
            tooltip: 'Segarkan data',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFormDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Layanan Baru'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Search & Filter
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Cari layanan (misal: Cuci Komplit, Bed Cover)...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(serviceProvider.notifier).loadServices(query: '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (query) {
                        ref.read(serviceProvider.notifier).loadServices(query: query);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Filter chips: All, per_kg, per_item (Wrap for responsive mobile screens)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        FilterChip(
                          label: const Text('Semua'),
                          selected: serviceState.priceTypeFilter == 'all',
                          onSelected: (_) {
                            ref.read(serviceProvider.notifier).loadServices(priceType: 'all');
                          },
                        ),
                        FilterChip(
                          label: const Text('Kiloan (per kg)'),
                          selected: serviceState.priceTypeFilter == 'per_kg',
                          onSelected: (_) {
                            ref.read(serviceProvider.notifier).loadServices(priceType: 'per_kg');
                          },
                        ),
                        FilterChip(
                          label: const Text('Satuan (per pcs)'),
                          selected: serviceState.priceTypeFilter == 'per_item',
                          onSelected: (_) {
                            ref.read(serviceProvider.notifier).loadServices(priceType: 'per_item');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Error Banner
              if (serviceState.errorMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          serviceState.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),

              // Service List
              Expanded(
                child: serviceState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : serviceState.services.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.dry_cleaning_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Belum ada layanan laundry',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Tambahkan layanan kiloan atau satuan untuk mulai melayani pelanggan.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _openFormDialog(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Tambah Layanan'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80),
                            itemCount: serviceState.services.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = serviceState.services[index];
                              final isKiloan = item.priceType == 'per_kg';

                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: item.isActive
                                            ? (isKiloan ? AppTheme.primaryBlue.withAlpha(30) : AppTheme.successGreen.withAlpha(30))
                                            : Colors.grey.shade200,
                                        child: Icon(
                                          isKiloan ? Icons.scale_outlined : Icons.checkroom_outlined,
                                          color: item.isActive
                                              ? (isKiloan ? AppTheme.primaryBlue : AppTheme.successGreen)
                                              : Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    item.name,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 15,
                                                      decoration: item.isActive ? null : TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                ),
                                                if (!item.isActive)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade200,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text('Nonaktif', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                  ),
                                              ],
                                            ),
                                            if (item.description != null && item.description!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Text(
                                                  item.description!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                ),
                                              ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                Text(
                                                  item.formattedPrice,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: AppTheme.primaryBlue,
                                                  ),
                                                ),
                                                if (item.estimatedDurationHours != null)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.timer_outlined, size: 13, color: AppTheme.textSecondary),
                                                      const SizedBox(width: 2),
                                                      Text(
                                                        '${item.estimatedDurationHours} jam',
                                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _openFormDialog(item);
                                          } else if (val == 'archive') {
                                            _confirmArchive(item);
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18),
                                                SizedBox(width: 8),
                                                Text('Ubah Layanan'),
                                              ],
                                            ),
                                          ),
                                          if (item.isActive)
                                            const PopupMenuItem(
                                              value: 'archive',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.archive_outlined, size: 18, color: Colors.orange),
                                                  SizedBox(width: 8),
                                                  Text('Nonaktifkan', style: TextStyle(color: Colors.orange)),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
