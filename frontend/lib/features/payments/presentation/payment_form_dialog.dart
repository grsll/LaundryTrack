import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/payment_model.dart';
import '../providers/payment_provider.dart';

class PaymentFormDialog extends ConsumerStatefulWidget {
  final String orderId;
  final String orderNumber;
  final double remainingAmount;

  const PaymentFormDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.remainingAmount,
  });

  @override
  ConsumerState<PaymentFormDialog> createState() => _PaymentFormDialogState();
}

class _PaymentFormDialogState extends ConsumerState<PaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'cash';
  bool _isLoading = false;
  double _tenderedAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _tenderedAmount = widget.remainingAmount;
    _amountController.text = widget.remainingAmount.toStringAsFixed(0);
    _amountController.addListener(_onAmountChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _refController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    final clean = _amountController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    setState(() {
      _tenderedAmount = double.tryParse(clean) ?? 0.0;
    });
  }

  void _setTenderedAmount(double val) {
    _amountController.text = val.toStringAsFixed(0);
  }

  double get _actualChargeAmount {
    if (_paymentMethod == 'cash') {
      if (_tenderedAmount >= widget.remainingAmount) {
        return widget.remainingAmount;
      }
      return _tenderedAmount;
    }
    return _tenderedAmount;
  }

  double get _changeAmount {
    if (_paymentMethod == 'cash' && _tenderedAmount > widget.remainingAmount) {
      return _tenderedAmount - widget.remainingAmount;
    }
    return 0.0;
  }

  List<double> get _recommendedCashAmounts {
    final suggestions = <double>{};
    final bill = widget.remainingAmount;
    if (bill < 20000) suggestions.add(20000);
    if (bill < 50000) suggestions.add(50000);
    if (bill < 100000) suggestions.add(100000);

    final ceil50k = (bill / 50000).ceil() * 50000.0;
    final ceil100k = (bill / 100000).ceil() * 100000.0;
    if (ceil50k > bill) suggestions.add(ceil50k);
    if (ceil100k > bill) suggestions.add(ceil100k);

    final list = suggestions.toList()..sort();
    return list.take(3).toList();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_actualChargeAmount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal pembayaran harus lebih besar dari Rp 0'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (_actualChargeAmount > widget.remainingAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal pembayaran tidak boleh melebihi sisa tagihan (${PaymentModel.formatRupiah(widget.remainingAmount)})',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payment = await ref.read(paymentNotifierProvider.notifier).recordPayment(
            widget.orderId,
            amount: _actualChargeAmount,
            paymentMethod: _paymentMethod,
            referenceNumber: _refController.text.isNotEmpty ? _refController.text : null,
            notes: _notesController.text.isNotEmpty ? _notesController.text : null,
          );

      if (mounted && payment != null) {
        Navigator.of(context).pop(payment);
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.point_of_sale_rounded, color: AppTheme.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Catat Pembayaran Kasir',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pesanan: ${widget.orderNumber}',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Remaining Bill Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sisa Tagihan:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                      ),
                      Flexible(
                        child: Text(
                          PaymentModel.formatRupiah(widget.remainingAmount),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Payment Method Selector
                const Text(
                  'Metode Pembayaran',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMethodChip('cash', 'Tunai', Icons.payments_outlined),
                    _buildMethodChip('qris', 'QRIS', Icons.qr_code_2_rounded),
                    _buildMethodChip('bank_transfer', 'Transfer Bank', Icons.account_balance_outlined),
                    _buildMethodChip('debit', 'Kartu Debit', Icons.credit_card_outlined),
                  ],
                ),
                const SizedBox(height: 20),

                // Cash Quick Chips
                if (_paymentMethod == 'cash') ...[
                  const Text(
                    'Pilihan Cepat Nominal Uang (Tunai)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Uang Pas'),
                        avatar: const Icon(Icons.check, size: 16),
                        onPressed: () => _setTenderedAmount(widget.remainingAmount),
                      ),
                      ..._recommendedCashAmounts.map(
                        (amt) => ActionChip(
                          label: Text(PaymentModel.formatRupiah(amt)),
                          onPressed: () => _setTenderedAmount(amt),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _paymentMethod == 'cash' ? 'Uang Diterima dari Pelanggan' : 'Nominal Pembayaran',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nominal pembayaran wajib diisi';
                    }
                    final clean = val.trim().replaceAll('.', '').replaceAll(',', '.');
                    final num = double.tryParse(clean);
                    if (num == null || num <= 0) {
                      return 'Masukkan nominal yang valid (> 0)';
                    }
                    if (_paymentMethod != 'cash' && num > widget.remainingAmount) {
                      return 'Tidak boleh melebihi sisa tagihan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Cash Change Info
                if (_paymentMethod == 'cash') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _changeAmount > 0
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _changeAmount > 0
                            ? AppTheme.successGreen.withValues(alpha: 0.3)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _changeAmount > 0 ? 'Kembalian:' : 'Kembalian:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _changeAmount > 0 ? FontWeight.bold : FontWeight.w500,
                              color: _changeAmount > 0 ? AppTheme.successGreen : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          PaymentModel.formatRupiah(_changeAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _changeAmount > 0 ? AppTheme.successGreen : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Reference Field
                TextFormField(
                  controller: _refController,
                  decoration: InputDecoration(
                    labelText: 'Nomor Referensi / ID Transaksi (Opsional)',
                    hintText: _paymentMethod == 'qris'
                        ? 'Contoh: QRIS-12345678'
                        : _paymentMethod == 'bank_transfer'
                            ? 'Contoh: BCA-TRF-99001'
                            : 'Nomor slip / referensi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes Field
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan Pembayaran (Opsional)',
                    hintText: 'Contoh: Uang pas, titip amplop, dll.',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons (Responsive Wrap)
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text('Bayar ${PaymentModel.formatRupiah(_actualChargeAmount)}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(String key, String label, IconData icon) {
    final isSelected = _paymentMethod == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.primaryBlue),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _paymentMethod = key;
          });
        }
      },
    );
  }
}
