import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../tracking/data/tracking_repository.dart';
import '../../tracking/presentation/tracking_provider.dart';
import '../data/receipt_repository.dart';
import 'receipt_provider.dart';

class ReceiptShareDialog extends ConsumerStatefulWidget {
  final String orderId;

  const ReceiptShareDialog({
    super.key,
    required this.orderId,
  });

  @override
  ConsumerState<ReceiptShareDialog> createState() => _ReceiptShareDialogState();
}

class _ReceiptShareDialogState extends ConsumerState<ReceiptShareDialog> {
  bool _isRegenerating = false;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleThermalPrint(String orderId) async {
    final receiptRepo = ref.read(receiptRepositoryProvider);
    final url = receiptRepo.getThermalHtmlUrl(orderId, width: 58);
    final uri = Uri.parse(url);

    try {
      await receiptRepo.recordReprint(
        orderId,
        printType: 'thermal',
        notes: 'Cetak thermal kasir',
      );
      ref.invalidate(receiptDetailProvider(orderId));

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Tidak dapat membuka antarmuka cetak printer', isError: true);
      }
    } catch (e) {
      _showSnack('Gagal mencatat cetak nota: $e', isError: true);
    }
  }

  Future<void> _handlePdfDownload(String orderId) async {
    final receiptRepo = ref.read(receiptRepositoryProvider);
    final url = receiptRepo.getPdfUrl(orderId);
    final uri = Uri.parse(url);

    try {
      await receiptRepo.recordReprint(
        orderId,
        printType: 'pdf',
        notes: 'Unduh berkas PDF nota',
      );
      ref.invalidate(receiptDetailProvider(orderId));

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Tidak dapat mengunduh berkas PDF', isError: true);
      }
    } catch (e) {
      _showSnack('Gagal memproses PDF: $e', isError: true);
    }
  }

  Future<void> _handleCopyLink(String trackingUrl) async {
    await Clipboard.setData(ClipboardData(text: trackingUrl));
    _showSnack('Link pelacakan publik disalin ke clipboard!');
  }

  Future<void> _handleWhatsAppShare(
    String orderId,
    String? customerPhone,
    String whatsappText,
  ) async {
    final receiptRepo = ref.read(receiptRepositoryProvider);
    try {
      await receiptRepo.recordReprint(
        orderId,
        printType: 'digital',
        notes: 'Bagikan nota via WhatsApp',
      );
      ref.invalidate(receiptDetailProvider(orderId));

      String waUrl;
      final encodedText = Uri.encodeComponent(whatsappText);
      if (customerPhone != null && customerPhone.isNotEmpty) {
        final cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), '');
        final formattedPhone = cleanPhone.startsWith('0')
            ? '62${cleanPhone.substring(1)}'
            : cleanPhone.startsWith('8')
                ? '62$cleanPhone'
                : cleanPhone;
        waUrl = 'https://wa.me/$formattedPhone?text=$encodedText';
      } else {
        waUrl = 'https://api.whatsapp.com/send?text=$encodedText';
      }

      final uri = Uri.parse(waUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Tidak dapat membuka aplikasi WhatsApp', isError: true);
      }
    } catch (e) {
      _showSnack('Gagal membagikan ke WhatsApp: $e', isError: true);
    }
  }

  Future<void> _handleRegenerateToken(String orderId) async {
    setState(() => _isRegenerating = true);
    try {
      final trackingRepo = ref.read(trackingRepositoryProvider);
      await trackingRepo.regenerateTrackingLink(orderId);
      ref.invalidate(trackingLinkProvider(orderId));
      ref.invalidate(receiptDetailProvider(orderId));
      _showSnack('Tautan pelacakan baru berhasil di-generate!');
    } catch (e) {
      _showSnack('Gagal meregenerasi tautan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiptAsync = ref.watch(receiptDetailProvider(widget.orderId));
    final trackingLinkAsync = ref.watch(trackingLinkProvider(widget.orderId));
    final currencyFormatter =
        NumberFormat.currency(symbol: 'Rp ', decimalDigits: 0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: receiptAsync.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Menyiapkan nota...'),
                  ],
                ),
              ),
            ),
            error: (err, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Gagal Memuat Nota: $err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
              ],
            ),
            data: (receipt) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Nota #${receipt.orderNumber}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Order Summary Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Pelanggan: ${receipt.customerName}',
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: receipt.remainingAmount <= 0
                                    ? Colors.green.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: receipt.remainingAmount <= 0
                                      ? Colors.green.shade200
                                      : Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                receipt.paymentStatusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: receipt.remainingAmount <= 0
                                      ? Colors.green.shade800
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Total: ${currencyFormatter.format(receipt.totalAmount)}  •  Sisa: ${currencyFormatter.format(receipt.remainingAmount)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (receipt.reprintCount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.history,
                                  size: 14, color: Colors.blueGrey),
                              const SizedBox(width: 4),
                              Text(
                                'Dicetak ulang ${receipt.reprintCount} kali',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Pilihan Cetak & Berbagi:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _handleThermalPrint(receipt.orderId),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Cetak Thermal (58mm)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _handlePdfDownload(receipt.orderId),
                        icon: const Icon(Icons.picture_as_pdf_outlined,
                            size: 18),
                        label: const Text('Unduh PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: BorderSide(color: Colors.deepOrange.shade300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      trackingLinkAsync.when(
                        loading: () => ElevatedButton.icon(
                          onPressed: null,
                          icon: const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          label: const Text('Menyiapkan WhatsApp...'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                        error: (err, stack) => const SizedBox.shrink(),
                        data: (link) => ElevatedButton.icon(
                          onPressed: () => _handleWhatsAppShare(
                            receipt.orderId,
                            receipt.customerPhone,
                            link.whatsappShareText,
                          ),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('Kirim WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      trackingLinkAsync.when(
                        loading: () => OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          label: const Text('Salin Link Tracking'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                        error: (err, stack) => const SizedBox.shrink(),
                        data: (link) => OutlinedButton.icon(
                          onPressed: () => _handleCopyLink(link.trackingUrl),
                          icon: const Icon(Icons.copy_outlined, size: 18),
                          label: const Text('Salin Link Tracking'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  // Secondary Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _isRegenerating
                            ? null
                            : () => _handleRegenerateToken(receipt.orderId),
                        icon: _isRegenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          'Perbarui Tautan Pelacakan',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
