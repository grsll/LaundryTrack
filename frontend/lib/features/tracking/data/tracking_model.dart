class PublicTrackingItemModel {
  final String serviceName;
  final String priceType;
  final String unit;
  final double quantity;
  final double unitPrice;
  final double subtotal;
  final String? notes;

  PublicTrackingItemModel({
    required this.serviceName,
    required this.priceType,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.notes,
  });

  factory PublicTrackingItemModel.fromJson(Map<String, dynamic> json) {
    return PublicTrackingItemModel(
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

class PublicTrackingTimelineModel {
  final String status;
  final String statusLabel;
  final DateTime timestamp;
  final String? notes;

  PublicTrackingTimelineModel({
    required this.status,
    required this.statusLabel,
    required this.timestamp,
    this.notes,
  });

  factory PublicTrackingTimelineModel.fromJson(Map<String, dynamic> json) {
    return PublicTrackingTimelineModel(
      status: json['status'] ?? '',
      statusLabel: json['status_label'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      notes: json['notes'],
    );
  }
}

class PublicTrackingModel {
  final String orderNumber;
  final String status;
  final String statusLabel;
  final String paymentStatus;
  final String paymentStatusLabel;
  final String customerNameMasked;
  final String customerPhoneMasked;
  final DateTime receivedAt;
  final DateTime? estimatedCompletionAt;
  final DateTime? completedAt;
  final DateTime? deliveredAt;
  final String outletName;
  final String? outletPhone;
  final String? outletAddress;
  final List<PublicTrackingItemModel> items;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final List<PublicTrackingTimelineModel> timeline;

  PublicTrackingModel({
    required this.orderNumber,
    required this.status,
    required this.statusLabel,
    required this.paymentStatus,
    required this.paymentStatusLabel,
    required this.customerNameMasked,
    required this.customerPhoneMasked,
    required this.receivedAt,
    this.estimatedCompletionAt,
    this.completedAt,
    this.deliveredAt,
    required this.outletName,
    this.outletPhone,
    this.outletAddress,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.timeline,
  });

  factory PublicTrackingModel.fromJson(Map<String, dynamic> json) {
    return PublicTrackingModel(
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      statusLabel: json['status_label'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      paymentStatusLabel: json['payment_status_label'] ?? '',
      customerNameMasked: json['customer_name_masked'] ?? 'Pelanggan',
      customerPhoneMasked: json['customer_phone_masked'] ?? '',
      receivedAt: DateTime.tryParse(json['received_at'] ?? '') ?? DateTime.now(),
      estimatedCompletionAt: json['estimated_completion_at'] != null
          ? DateTime.tryParse(json['estimated_completion_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'])
          : null,
      outletName: json['outlet_name'] ?? 'Laundry Outlet',
      outletPhone: json['outlet_phone'],
      outletAddress: json['outlet_address'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PublicTrackingItemModel.fromJson(e))
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
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) => PublicTrackingTimelineModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class TrackingLinkModel {
  final String orderId;
  final String orderNumber;
  final String trackingToken;
  final String trackingUrl;
  final String whatsappShareText;

  TrackingLinkModel({
    required this.orderId,
    required this.orderNumber,
    required this.trackingToken,
    required this.trackingUrl,
    required this.whatsappShareText,
  });

  factory TrackingLinkModel.fromJson(Map<String, dynamic> json) {
    return TrackingLinkModel(
      orderId: json['order_id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      trackingToken: json['tracking_token'] ?? '',
      trackingUrl: json['tracking_url'] ?? '',
      whatsappShareText: json['whatsapp_share_text'] ?? '',
    );
  }
}
