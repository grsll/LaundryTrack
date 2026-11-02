import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../customers/data/customer_model.dart';
import '../../customers/presentation/customer_form_dialog.dart';
import '../../customers/providers/customer_provider.dart';
import '../../services/data/service_model.dart';
import '../../services/providers/service_provider.dart';
import '../data/order_model.dart';
import '../providers/order_provider.dart';

class _OrderItemEntry {
  ServiceModel? service;
  final TextEditingController quantityController = TextEditingController(text: '1.0');
  final TextEditingController notesController = TextEditingController();

  double get quantity => double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 0.0;
  double get unitPrice => service?.price ?? 0.0;
  double get subtotal => quantity * unitPrice;

  void dispose() {
    quantityController.dispose();
    notesController.dispose();
  }
}

class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  CustomerModel? _selectedCustomer;
  final List<_OrderItemEntry> _items = [];
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _orderNotesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Start with 1 default item
    _addNewItem();
  }

  void _addNewItem() {
    setState(() {
      _items.add(_OrderItemEntry());
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  double get _subtotal {
    double total = 0.0;
    for (final item in _items) {
      total += item.subtotal;
    }
    return total;
  }

  double get _discount => double.tryParse(_discountController.text) ?? 0.0;

  double get _totalAmount {
    final sub = _subtotal;
    final disc = _discount;
    final res = sub - disc;
    return res > 0 ? res : 0.0;
  }

  Future<void> _submitOrder() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih pelanggan terlebih dahulu!'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Validate all items have services
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].service == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pilih layanan untuk item baris ke-${i + 1}!'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }
      if (_items[i].quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kuantitas item baris ke-${i + 1} harus lebih dari 0!'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'customer_id': _selectedCustomer!.id,
        'items': _items.map((it) {
          return {
            'service_id': it.service!.id,
            'quantity': it.quantity.toStringAsFixed(2),
            if (it.notesController.text.trim().isNotEmpty) 'notes': it.notesController.text.trim(),
          };
        }).toList(),
        'discount_amount': _discount.toStringAsFixed(2),
        if (_orderNotesController.text.trim().isNotEmpty) 'notes': _orderNotesController.text.trim(),
      };

      final createdOrder = await ref.read(orderProvider.notifier).createOrder(payload);

      if (createdOrder != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pesanan ${createdOrder.orderNumber} berhasil dibuat!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.pop();
      } else if (mounted) {
        final err = ref.read(orderProvider).errorMessage ?? 'Gagal membuat pesanan';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showNewCustomerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        onSave: (payload) async {
          final success = await ref.read(customerProvider.notifier).createCustomer(payload);
          if (success) {
            // Find created customer and select it
            final customers = ref.read(customerProvider).customers;
            if (customers.isNotEmpty) {
              setState(() {
                _selectedCustomer = customers.first;
              });
            }
          }
          return success;
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _discountController.dispose();
    _orderNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerProvider);
    final serviceState = ref.watch(serviceProvider);
    final activeServices = serviceState.services.where((s) => s.isActive).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Pesanan Baru (Kasir)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Customer Selection Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.person_pin, color: AppTheme.primaryBlue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Pilih Pelanggan *',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: _showNewCustomerDialog,
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Pelanggan Baru'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (customerState.isLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            DropdownButtonFormField<CustomerModel>(
                              initialValue: _selectedCustomer,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                hintText: 'Pilih pelanggan...',
                                prefixIcon: Icon(Icons.search),
                              ),
                              items: customerState.customers.map((c) {
                                return DropdownMenuItem<CustomerModel>(
                                  value: c,
                                  child: Text('${c.name} • ${c.phone ?? "Tanpa Telepon"}'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedCustomer = val);
                              },
                              validator: (val) => val == null ? 'Pelanggan wajib dipilih' : null,
                            ),
                          if (_selectedCustomer != null && _selectedCustomer!.address != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Alamat: ${_selectedCustomer!.address}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Order Items Section
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.dry_cleaning, color: AppTheme.primaryBlue),
                                  SizedBox(width: 8),
                                  Text(
                                    'Layanan & Cucian *',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _addNewItem,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Tambah Item'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(_items.length, (index) {
                            return _buildItemRow(index, activeServices);
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Order Options Card (Discount & Notes)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Potongan Diskon & Catatan',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _discountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: const InputDecoration(
                                    labelText: 'Potongan Diskon (Rp)',
                                    prefixText: 'Rp ',
                                    hintText: '0',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _orderNotesController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Catatan Umum Pesanan (Opsional)',
                              hintText: 'Misal: Selesai tepat waktu sebelum akhir pekan',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Order Calculation Summary & Action Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                            Text(
                              OrderModel.formatRupiah(_subtotal),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (_discount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Diskon:', style: TextStyle(fontSize: 14, color: AppTheme.errorRed)),
                              Text(
                                '- ${OrderModel.formatRupiah(_discount)}',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                              ),
                            ],
                          ),
                        ],
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Tagihan:',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            Text(
                              OrderModel.formatRupiah(_totalAmount),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _submitOrder,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isSubmitting ? 'Memproses Pesanan...' : 'Simpan & Proses Pesanan',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemRow(int index, List<ServiceModel> services) {
    final item = _items[index];
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      key: ObjectKey(item),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          if (isMobile) ...[
            // Full width service selector on mobile
            DropdownButtonFormField<ServiceModel>(
              initialValue: item.service,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Layanan',
                isDense: true,
              ),
              items: services.map((s) {
                final priceFormatted = OrderModel.formatRupiah(s.price);
                return DropdownMenuItem<ServiceModel>(
                  value: s,
                  child: Text('${s.name} ($priceFormatted/${s.unit})', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  item.service = val;
                });
              },
              validator: (val) => val == null ? 'Pilih layanan' : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Qty (${item.service?.unit ?? "Satuan"})',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      final d = double.tryParse((val ?? '').replaceAll(',', '.'));
                      if (d == null || d <= 0) return '> 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(
                      OrderModel.formatRupiah(item.subtotal),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                if (_items.length > 1) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                    tooltip: 'Hapus Item',
                    onPressed: () => _removeItem(index),
                  ),
                ],
              ],
            ),
          ] else ...[
            // Desktop horizontal row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<ServiceModel>(
                    initialValue: item.service,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Layanan',
                      isDense: true,
                    ),
                    items: services.map((s) {
                      final priceFormatted = OrderModel.formatRupiah(s.price);
                      return DropdownMenuItem<ServiceModel>(
                        value: s,
                        child: Text('${s.name} ($priceFormatted/${s.unit})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        item.service = val;
                      });
                    },
                    validator: (val) => val == null ? 'Pilih layanan' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item.quantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Qty (${item.service?.unit ?? "Satuan"})',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      final d = double.tryParse((val ?? '').replaceAll(',', '.'));
                      if (d == null || d <= 0) return '> 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(
                      OrderModel.formatRupiah(item.subtotal),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    if (_items.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.errorRed),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Hapus Item',
                        onPressed: () => _removeItem(index),
                      ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: item.notesController,
            decoration: const InputDecoration(
              hintText: 'Catatan item (misal: warna putih, ada noda luntur)',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}
