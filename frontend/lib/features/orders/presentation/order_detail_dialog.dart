import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../payments/data/payment_model.dart';
import '../../payments/presentation/payment_form_dialog.dart';
import '../../payments/presentation/refund_form_dialog.dart';
import '../../payments/providers/payment_provider.dart';
import '../data/order_model.dart';
import '../providers/order_provider.dart';

class OrderDetailDialog extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailDialog({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends ConsumerState<OrderDetailDialog> {
  bool _isProcessing = false;

  Future<void> _advanceStatus(OrderModel order) async {
    final nextStatus = order.nextPipelineStatus;
    if (nextStatus == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi ${order.nextPipelineLabel}'),
        content: Text(
          'Apakah Anda yakin ingin memproses pesanan ${order.orderNumber} ke tahap "${order.nextPipelineLabel}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final success = await ref.read(orderProvider.notifier).transitionStatus(order.id, nextStatus);
      ref.invalidate(orderDetailProvider(widget.orderId));

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status pesanan berhasil diubah menjadi ${order.nextPipelineLabel}'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else if (mounted) {
        final err = ref.read(orderProvider).errorMessage ?? 'Gagal mengubah status pesanan';
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
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _openPaymentDialog(OrderModel order) async {
    final payment = await showDialog<PaymentModel>(
      context: context,
      builder: (ctx) => PaymentFormDialog(
        orderId: order.id,
        orderNumber: order.orderNumber,
        remainingAmount: order.remainingAmount,
      ),
    );

    if (payment != null && mounted) {
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(orderPaymentsProvider(widget.orderId));
      ref.read(orderProvider.notifier).loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pembayaran ${PaymentModel.formatRupiah(payment.amount)} berhasil dicatat'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _openRefundDialog(PaymentModel payment, OrderModel order) async {
    final refund = await showDialog<RefundModel>(
      context: context,
      builder: (ctx) => RefundFormDialog(
        payment: payment,
        orderId: order.id,
      ),
    );

    if (refund != null && mounted) {
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.invalidate(orderPaymentsProvider(widget.orderId));
      ref.read(orderProvider.notifier).loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengembalian dana ${PaymentModel.formatRupiah(refund.amount)} berhasil diproses'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    try {
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Batalkan Pesanan', style: TextStyle(color: AppTheme.errorRed)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pesanan ${order.orderNumber} akan dibatalkan secara permanen. Mohon berikan alasan pembatalan:',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Pembatalan *',
                    hintText: 'Misal: Pelanggan salah pilih paket layanan',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 3) {
                      return 'Alasan pembatalan minimal 3 karakter';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Kembali'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(ctx).pop(reasonController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Batalkan Pesanan'),
            ),
          ],
        ),
      );

      if (reason == null || reason.isEmpty) return;

      setState(() => _isProcessing = true);
      try {
        final success = await ref.read(orderProvider.notifier).cancelOrder(order.id, reason);
        ref.invalidate(orderDetailProvider(widget.orderId));

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pesanan berhasil dibatalkan'),
              backgroundColor: AppTheme.warningOrange,
            ),
          );
        } else if (mounted) {
          final err = ref.read(orderProvider).errorMessage ?? 'Gagal membatalkan pesanan';
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
          setState(() => _isProcessing = false);
        }
      }
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 850),
        child: orderAsync.when(
          loading: () => const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                const SizedBox(height: 12),
                Text(
                  err.toString().replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
          data: (order) => _buildDetailContent(order),
        ),
      ),
    );
  }

  Widget _buildDetailContent(OrderModel order) {
    final canAdvance = order.nextPipelineStatus != null && !_isProcessing;
    final canCancel = order.status != 'completed' && order.status != 'cancelled' && !_isProcessing;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.orderNumber,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Pelanggan: ${order.customerName ?? "-"} (${order.customerPhone ?? "-"})',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: order.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: order.statusColor.withValues(alpha: 0.4)),
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
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cancellation Banner if cancelled
                if (order.status == 'cancelled') ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cancel_outlined, color: AppTheme.errorRed, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pesanan Dibatalkan',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Alasan: ${order.cancellationReason ?? "Tanpa alasan"}',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Status Pipeline Stepper
                const Text(
                  'Siklus Pengerjaan Laundry',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildStatusPipeline(order),
                const SizedBox(height: 24),

                // Order Items Breakdown (Snapshots)
                const Text(
                  'Rincian Layanan (Snapshot Nota)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                ...order.items.map((item) => _buildItemCard(item)),
                const SizedBox(height: 20),

                // Order Financial Summary
                _buildFinancialSummary(order),
                const SizedBox(height: 24),

                // Payment History Section
                _buildPaymentHistory(order),
                const SizedBox(height: 24),

                // Order Notes if any
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const Text(
                    'Catatan Pesanan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(order.notes!, style: const TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(height: 24),
                ],

                // Lifecycle Timeline Logs
                if (order.statusLogs.isNotEmpty) ...[
                  const Text(
                    'Riwayat Perubahan Status',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  ...order.statusLogs.reversed.map((log) => _buildTimelineTile(log)),
                ],
              ],
            ),
          ),
        ),

        // Action Buttons Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              if (canCancel)
                OutlinedButton.icon(
                  onPressed: _isProcessing ? null : () => _cancelOrder(order),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Batalkan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorRed,
                    side: const BorderSide(color: AppTheme.errorRed),
                  ),
                )
              else
                const SizedBox.shrink(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                  if (canAdvance) ...[
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _advanceStatus(order),
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_forward, size: 18),
                      label: Text(order.nextPipelineLabel ?? 'Lanjut'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPipeline(OrderModel order) {
    final stages = [
      {'key': 'received', 'label': 'Diterima'},
      {'key': 'washing', 'label': 'Cuci'},
      {'key': 'drying', 'label': 'Kering'},
      {'key': 'ironing', 'label': 'Setrika'},
      {'key': 'packaging', 'label': 'Kemas'},
      {'key': 'ready', 'label': 'Siap'},
      {'key': 'completed', 'label': 'Selesai'},
    ];

    final currentIndex = stages.indexWhere((s) => s['key'] == order.status);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: stages.map((s) {
        final stageIndex = stages.indexOf(s);
        final isPassed = currentIndex != -1 && stageIndex <= currentIndex;
        final isCurrent = s['key'] == order.status;

        Color bg = const Color(0xFFF1F5F9);
        Color textColor = AppTheme.textSecondary;
        if (order.status == 'cancelled') {
          bg = const Color(0xFFFEE2E2);
          textColor = AppTheme.errorRed;
        } else if (isCurrent) {
          bg = AppTheme.primaryBlue;
          textColor = Colors.white;
        } else if (isPassed) {
          bg = AppTheme.successGreen.withValues(alpha: 0.15);
          textColor = AppTheme.successGreen;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: isCurrent ? Border.all(color: AppTheme.primaryBlue) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isPassed && !isCurrent && order.status != 'cancelled') ...[
                const Icon(Icons.check, size: 14, color: AppTheme.successGreen),
                const SizedBox(width: 4),
              ],
              Text(
                s['label'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildItemCard(OrderItemModel item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.serviceNameSnapshot,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity.toStringAsFixed(1)} ${item.unitSnapshot} x ${OrderModel.formatRupiah(item.unitPriceSnapshot)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Catatan: ${item.notes}',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                  ),
                ],
              ],
            ),
          ),
          Text(
            OrderModel.formatRupiah(item.subtotal),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _summaryRow('Subtotal', OrderModel.formatRupiah(order.subtotal)),
          if (order.discountAmount > 0) ...[
            const SizedBox(height: 6),
            _summaryRow(
              'Diskon',
              '- ${OrderModel.formatRupiah(order.discountAmount)}',
              valueColor: AppTheme.errorRed,
            ),
          ],
          const Divider(height: 16),
          _summaryRow(
            'Total Tagihan',
            OrderModel.formatRupiah(order.totalAmount),
            isBold: true,
            fontSize: 16,
          ),
          const SizedBox(height: 6),
          _summaryRow(
            'Terbayar',
            OrderModel.formatRupiah(order.paidAmount),
            valueColor: AppTheme.successGreen,
          ),
          const SizedBox(height: 6),
          _summaryRow(
            'Sisa Tagihan',
            OrderModel.formatRupiah(order.remainingAmount),
            isBold: true,
            fontSize: 15,
            valueColor: order.remainingAmount > 0 ? AppTheme.errorRed : AppTheme.successGreen,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status Pembayaran:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
          if (order.remainingAmount > 0 && order.status != 'cancelled') ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openPaymentDialog(order),
                icon: const Icon(Icons.point_of_sale_rounded, size: 18),
                label: const Text('Catat Pembayaran Kasir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(OrderModel order) {
    final paymentsAsync = ref.watch(orderPaymentsProvider(order.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Transaksi Pembayaran',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: 'Perbarui riwayat pembayaran',
              onPressed: () => ref.invalidate(orderPaymentsProvider(order.id)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        paymentsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gagal memuat pembayaran: ${err.toString().replaceAll('Exception: ', '')}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.errorRed),
                  ),
                ),
              ],
            ),
          ),
          data: (payments) {
            if (payments.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Belum ada transaksi pembayaran untuk pesanan ini.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Column(
              children: payments.map((payment) => _buildPaymentCard(payment, order)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPaymentCard(PaymentModel payment, OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(payment.methodIcon, size: 18, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                payment.methodLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: payment.statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  payment.statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: payment.statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Waktu: ${_formatDateTime(payment.paidAt)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                PaymentModel.formatRupiah(payment.amount),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          if (payment.referenceNumber != null && payment.referenceNumber!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ref: ${payment.referenceNumber}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
          if (payment.receivedByName != null) ...[
            const SizedBox(height: 2),
            Text(
              'Diterima oleh: ${payment.receivedByName}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
          if (payment.notes != null && payment.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Catatan: ${payment.notes}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey),
            ),
          ],
          // Refunds section if any
          if (payment.refunds.isNotEmpty) ...[
            const Divider(height: 14),
            const Text(
              'Riwayat Refund Terkait:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
            ),
            const SizedBox(height: 4),
            ...payment.refunds.map(
              (refItem) => Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.subdirectory_arrow_right, size: 14, color: AppTheme.errorRed),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${PaymentModel.formatRupiah(refItem.amount)} (${refItem.reason}) • ${_formatDateTime(refItem.refundedAt)}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.errorRed),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Refund button if refundable and order not cancelled
          if (payment.netAmount > 0 && order.status != 'cancelled') ...[
            const Divider(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openRefundDialog(payment, order),
                icon: const Icon(Icons.assignment_return_outlined, size: 14, color: AppTheme.errorRed),
                label: Text(
                  'Refund (${PaymentModel.formatRupiah(payment.netAmount)})',
                  style: const TextStyle(fontSize: 12, color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTile(OrderStatusLogModel log) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Ke ${log.newStatus.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${_formatDateTime(log.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                if (log.notes != null && log.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.notes!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
