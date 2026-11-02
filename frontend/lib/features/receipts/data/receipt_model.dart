class ReceiptItemModel {
  final String serviceName;
  final String priceType;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  ReceiptItemModel({
    required this.serviceName,
    required this.priceType,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  factory ReceiptItemModel.fromJson(Map<String, dynamic> json) {
    return ReceiptItemModel(
      serviceName: json['service_name'] ?? '',
      priceType: json['price_type'] ?? '',
      unit: json['unit'] ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'],
    );
  }
}

class ReceiptPaymentModel {
  final String id;
  final double amount;
  final String paymentMethod;
  final DateTime paidAt;
  final String? receivedByName;
  final String? referenceNumber;

  ReceiptPaymentModel({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.paidAt,
    this.receivedByName,
    this.referenceNumber,
  });

  factory ReceiptPaymentModel.fromJson(Map<String, dynamic> json) {
    return ReceiptPaymentModel(
      id: json['id'] ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['payment_method'] ?? '',
      paidAt: DateTime.tryParse(json['paid_at'] ?? '') ?? DateTime.now(),
      receivedByName: json['received_by_name'],
      referenceNumber: json['reference_number'],
    );
  }
}

class ReceiptModel {
  final String orderId;
  final String orderNumber;
  final String status;
  final String statusLabel;
  final String paymentStatus;
  final String paymentStatusLabel;
  final DateTime receivedAt;
  final DateTime? estimatedCompletionAt;
  final DateTime? completedAt;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String outletName;
  final String? outletPhone;
  final String? outletAddress;
  final String tenantName;
  final String? cashierName;
  final List<ReceiptItemModel> items;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final List<ReceiptPaymentModel> payments;
  final String trackingToken;
  final String trackingUrl;
  final DateTime? receiptPrintedAt;
  final int reprintCount;

  ReceiptModel({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.paymentStatus,
    required this.paymentStatusLabel,
    required this.receivedAt,
    this.estimatedCompletionAt,
    this.completedAt,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    required this.outletName,
    this.outletPhone,
    this.outletAddress,
    required this.tenantName,
    this.cashierName,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.payments,
    required this.trackingToken,
    required this.trackingUrl,
    this.receiptPrintedAt,
    required this.reprintCount,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    return ReceiptModel(
      orderId: json['order_id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      statusLabel: json['status_label'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      paymentStatusLabel: json['payment_status_label'] ?? '',
      receivedAt: DateTime.tryParse(json['received_at'] ?? '') ?? DateTime.now(),
      estimatedCompletionAt: json['estimated_completion_at'] != null
          ? DateTime.tryParse(json['estimated_completion_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      customerName: json['customer_name'] ?? 'Pelanggan Umum',
      customerPhone: json['customer_phone'],
      customerAddress: json['customer_address'],
      outletName: json['outlet_name'] ?? 'Laundry Outlet',
      outletPhone: json['outlet_phone'],
      outletAddress: json['outlet_address'],
      tenantName: json['tenant_name'] ?? 'LaundryTrack',
      cashierName: json['cashier_name'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ReceiptItemModel.fromJson(e))
              .toList() ??
          [],
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      discountAmount:
          double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      totalAmount:
          double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      paidAmount:
          double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0.0,
      remainingAmount:
          double.tryParse(json['remaining_amount']?.toString() ?? '0') ?? 0.0,
      payments: (json['payments'] as List<dynamic>?)
              ?.map((e) => ReceiptPaymentModel.fromJson(e))
              .toList() ??
          [],
      trackingToken: json['tracking_token'] ?? '',
      trackingUrl: json['tracking_url'] ?? '',
      receiptPrintedAt: json['receipt_printed_at'] != null
          ? DateTime.tryParse(json['receipt_printed_at'])
          : null,
      reprintCount: json['reprint_count'] ?? 0,
    );
  }
}
