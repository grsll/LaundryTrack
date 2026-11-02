import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class RefundModel {
  final String id;
  final String tenantId;
  final String outletId;
  final String paymentId;
  final String orderId;
  final String? refundedById;
  final String? refundedByName;
  final double amount;
  final String reason;
  final DateTime refundedAt;
  final DateTime createdAt;

  const RefundModel({
    required this.id,
    required this.tenantId,
    required this.outletId,
    required this.paymentId,
    required this.orderId,
    this.refundedById,
    this.refundedByName,
    required this.amount,
    required this.reason,
    required this.refundedAt,
    required this.createdAt,
  });

  factory RefundModel.fromJson(Map<String, dynamic> json) {
    return RefundModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      outletId: json['outlet_id'] as String,
      paymentId: json['payment_id'] as String,
      orderId: json['order_id'] as String,
      refundedById: json['refunded_by_id'] as String?,
      refundedByName: json['refunded_by_name'] as String?,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      reason: json['reason'] as String? ?? '',
      refundedAt: DateTime.tryParse(json['refunded_at'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'outlet_id': outletId,
      'payment_id': paymentId,
      'order_id': orderId,
      'refunded_by_id': refundedById,
      'refunded_by_name': refundedByName,
      'amount': amount,
      'reason': reason,
      'refunded_at': refundedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is RefundModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class PaymentModel {
  final String id;
  final String tenantId;
  final String outletId;
  final String orderId;
  final String? receivedById;
  final String? receivedByName;
  final double amount;
  final String paymentMethod;
  final String? referenceNumber;
  final String status;
  final DateTime paidAt;
  final String? notes;
  final DateTime createdAt;
  final List<RefundModel> refunds;
  final double totalRefunded;
  final double netAmount;

  const PaymentModel({
    required this.id,
    required this.tenantId,
    required this.outletId,
    required this.orderId,
    this.receivedById,
    this.receivedByName,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    required this.status,
    required this.paidAt,
    this.notes,
    required this.createdAt,
    this.refunds = const [],
    this.totalRefunded = 0.0,
    this.netAmount = 0.0,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final refundsList = (json['refunds'] as List<dynamic>?)
            ?.map((r) => RefundModel.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    final amt = double.tryParse(json['amount'].toString()) ?? 0.0;
    final totRef = double.tryParse(json['total_refunded']?.toString() ?? '0') ?? 0.0;
    final net = double.tryParse(json['net_amount']?.toString() ?? '0') ?? (amt - totRef);

    return PaymentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      outletId: json['outlet_id'] as String,
      orderId: json['order_id'] as String,
      receivedById: json['received_by_id'] as String?,
      receivedByName: json['received_by_name'] as String?,
      amount: amt,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      referenceNumber: json['reference_number'] as String?,
      status: json['status'] as String? ?? 'paid',
      paidAt: DateTime.tryParse(json['paid_at'] as String? ?? '') ?? DateTime.now(),
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      refunds: refundsList,
      totalRefunded: totRef,
      netAmount: net,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'outlet_id': outletId,
      'order_id': orderId,
      'received_by_id': receivedById,
      'received_by_name': receivedByName,
      'amount': amount,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'status': status,
      'paid_at': paidAt.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'refunds': refunds.map((r) => r.toJson()).toList(),
      'total_refunded': totalRefunded,
      'net_amount': netAmount,
    };
  }

  String get methodLabel {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'bank_transfer':
        return 'Transfer Bank';
      case 'debit':
        return 'Kartu Debit';
      default:
        return paymentMethod;
    }
  }

  IconData get methodIcon {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return Icons.payments_outlined;
      case 'qris':
        return Icons.qr_code_2_rounded;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
      case 'debit':
        return Icons.credit_card_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Lunas';
      case 'partially_refunded':
        return 'Refund Sebagian';
      case 'refunded':
        return 'Direfund';
      default:
        return status;
    }
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppTheme.successGreen;
      case 'partially_refunded':
        return AppTheme.warningOrange;
      case 'refunded':
        return AppTheme.errorRed;
      default:
        return AppTheme.textSecondary;
    }
  }

  static String formatRupiah(double value) {
    final isNegative = value < 0;
    final absVal = value.abs();
    final parts = absVal.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(parts[i]);
    }
    return '${isNegative ? "-Rp " : "Rp "}${buffer.toString()}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PaymentModel && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
