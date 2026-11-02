import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/payment_model.dart';
import '../providers/payment_provider.dart';

class RefundFormDialog extends ConsumerStatefulWidget {
  final PaymentModel payment;
  final String orderId;

  const RefundFormDialog({
    super.key,
    required this.payment,
    required this.orderId,
  });

  @override
  ConsumerState<RefundFormDialog> createState() => _RefundFormDialogState();
}

class _RefundFormDialogState extends ConsumerState<RefundFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.payment.netAmount.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRefund() async {
    if (!_formKey.currentState!.validate()) return;

    final cleanAmount = _amountController.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final amount = double.tryParse(cleanAmount) ?? 0.0;

    if (amount <= 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal refund harus lebih besar dari Rp 0'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (amount > widget.payment.netAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nominal refund tidak boleh melebihi sisa dana pembayaran (${PaymentModel.formatRupiah(widget.payment.netAmount)})',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final refund = await ref.read(paymentNotifierProvider.notifier).recordRefund(
            widget.payment.id,
            widget.orderId,
            amount: amount,
            reason: _reasonController.text.trim(),
          );

      if (mounted && refund != null) {
        Navigator.of(context).pop(refund);
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
        constraints: const BoxConstraints(maxWidth: 480),
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
                        color: AppTheme.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_return_outlined, color: AppTheme.errorRed),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pengembalian Dana (Refund)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Pembayaran: ${widget.payment.methodLabel} • ${PaymentModel.formatRupiah(widget.payment.amount)}',
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
                const SizedBox(height: 16),

                // Refundable Limit Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Maksimal yang dapat direfund:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                        ),
                      ),
                      Text(
                        PaymentModel.formatRupiah(widget.payment.netAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Nominal Refund',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Nominal refund wajib diisi';
                    }
                    final clean = val.trim().replaceAll('.', '').replaceAll(',', '.');
                    final num = double.tryParse(clean);
                    if (num == null || num <= 0) {
                      return 'Masukkan nominal yang valid (> 0)';
                    }
                    if (num > widget.payment.netAmount) {
                      return 'Tidak boleh melebihi sisa dana pembayaran';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Reason Field
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Alasan Pengembalian Dana *',
                    hintText: 'Contoh: Pakaian luntur/rusak, pembatalan item cucian, kompensasi pelanggan...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Alasan refund wajib diisi';
                    }
                    if (val.trim().length < 3) {
                      return 'Alasan refund minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Actions (Responsive Wrap)
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
                      onPressed: _isLoading ? null : _submitRefund,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Konfirmasi Refund'),
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
}
