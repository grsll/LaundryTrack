import 'package:flutter/material.dart';

class OrderItemModel {
  final String id;
  final String? serviceId;
  final String serviceNameSnapshot;
  final String priceTypeSnapshot;
  final String unitSnapshot;
  final double unitPriceSnapshot;
  final double quantity;
  final double subtotal;
  final String? notes;
  final DateTime createdAt;

  const OrderItemModel({
    required this.id,
    this.serviceId,
    required this.serviceNameSnapshot,
    required this.priceTypeSnapshot,
    required this.unitSnapshot,
    required this.unitPriceSnapshot,
    required this.quantity,
    required this.subtotal,
    this.notes,
    required this.createdAt,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      serviceId: json['service_id'] as String?,
      serviceNameSnapshot: json['service_name_snapshot'] as String? ?? 'Layanan',
      priceTypeSnapshot: json['price_type_snapshot'] as String? ?? 'per_kg',
      unitSnapshot: json['unit_snapshot'] as String? ?? 'kg',
      unitPriceSnapshot: double.tryParse(json['unit_price_snapshot']?.toString() ?? '0') ?? 0.0,
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service_id': serviceId,
      'quantity': quantity.toStringAsFixed(2),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}

class OrderStatusLogModel {
  final String id;
  final String? previousStatus;
  final String newStatus;
  final String? notes;
  final String? changedById;
  final String? changedByName;
  final DateTime createdAt;

  const OrderStatusLogModel({
    required this.id,
    this.previousStatus,
    required this.newStatus,
    this.notes,
    this.changedById,
    this.changedByName,
    required this.createdAt,
  });

  factory OrderStatusLogModel.fromJson(Map<String, dynamic> json) {
    return OrderStatusLogModel(
      id: json['id'] as String,
      previousStatus: json['previous_status'] as String?,
      newStatus: json['new_status'] as String? ?? 'received',
      notes: json['notes'] as String?,
      changedById: json['changed_by_id'] as String?,
      changedByName: json['changed_by_name'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class OrderModel {
  final String id;
  final String tenantId;
  final String outletId;
  final String? outletName;
  final String customerId;
  final String? customerName;
  final String? customerPhone;
  final String orderNumber;
  final String status;
  final String paymentStatus;
  final DateTime receivedAt;
  final DateTime? estimatedCompletionAt;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String? notes;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final int itemsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItemModel> items;
  final List<OrderStatusLogModel> statusLogs;

  const OrderModel({
    required this.id,
    required this.tenantId,
    required this.outletId,
    this.outletName,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.receivedAt,
    this.estimatedCompletionAt,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    this.notes,
    this.cancellationReason,
    this.cancelledAt,
    required this.itemsCount,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.statusLogs = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>?;
    final rawLogs = json['status_logs'] as List<dynamic>?;

    return OrderModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      outletId: json['outlet_id'] as String,
      outletName: json['outlet_name'] as String?,
      customerId: json['customer_id'] as String,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String? ?? 'received',
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      receivedAt: DateTime.tryParse(json['received_at']?.toString() ?? '') ?? DateTime.now(),
      estimatedCompletionAt: DateTime.tryParse(json['estimated_completion_at']?.toString() ?? ''),
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0.0,
      remainingAmount: double.tryParse(json['remaining_amount']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledAt: DateTime.tryParse(json['cancelled_at']?.toString() ?? ''),
      itemsCount: json['items_count'] as int? ?? (rawItems?.length ?? 0),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      items: rawItems != null
          ? rawItems.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
      statusLogs: rawLogs != null
          ? rawLogs.map((e) => OrderStatusLogModel.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }

  // Indonesian Status Label
  String get statusLabel {
    switch (status) {
      case 'received':
        return 'Diterima';
      case 'washing':
        return 'Proses Cuci';
      case 'drying':
        return 'Pengeringan';
      case 'ironing':
        return 'Setrika';
      case 'packaging':
        return 'Pengepakan';
      case 'ready':
        return 'Siap Diambil';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  // Status Badge Colors
  Color get statusColor {
    switch (status) {
      case 'received':
        return const Color(0xFF2563EB); // Blue
      case 'washing':
        return const Color(0xFF0284C7); // Sky Blue
      case 'drying':
        return const Color(0xFF0D9488); // Teal
      case 'ironing':
        return const Color(0xFFD97706); // Amber
      case 'packaging':
        return const Color(0xFF7C3AED); // Purple
      case 'ready':
        return const Color(0xFF059669); // Emerald
      case 'completed':
        return const Color(0xFF16A34A); // Green
      case 'cancelled':
        return const Color(0xFFDC2626); // Red
      default:
        return Colors.grey;
    }
  }

  // Next status recommendation in normal pipeline
  String? get nextPipelineStatus {
    switch (status) {
      case 'received':
        return 'washing';
      case 'washing':
        return 'drying';
      case 'drying':
        return 'ironing';
      case 'ironing':
        return 'packaging';
      case 'packaging':
        return 'ready';
      case 'ready':
        return 'completed';
      default:
        return null;
    }
  }

  String? get nextPipelineLabel {
    final next = nextPipelineStatus;
    if (next == null) return null;
    switch (next) {
      case 'washing':
        return 'Mulai Cuci';
      case 'drying':
        return 'Mulai Keringkan';
      case 'ironing':
        return 'Mulai Setrika';
      case 'packaging':
        return 'Mulai Kemas';
      case 'ready':
        return 'Tandai Siap';
      case 'completed':
        return 'Selesaikan Pesanan';
      default:
        return next;
    }
  }

  // Indonesian Payment Status
  String get paymentStatusLabel {
    switch (paymentStatus) {
      case 'unpaid':
        return 'Belum Lunas';
      case 'partial':
        return 'Sebagian';
      case 'paid':
        return 'Lunas';
      case 'refunded':
        return 'Dikembalikan';
      default:
        return paymentStatus;
    }
  }

  Color get paymentStatusColor {
    switch (paymentStatus) {
      case 'paid':
        return const Color(0xFF16A34A);
      case 'partial':
        return const Color(0xFFD97706);
      case 'unpaid':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  static String formatRupiah(double value) {
    if (value < 0) {
      return '-${formatRupiah(value.abs())}';
    }
    final parts = value.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts.length - 1; i >= 0; i--) {
      buffer.write(parts[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return 'Rp${buffer.toString().split('').reversed.join('')}';
  }
}
