class ServiceModel {
  final String id;
  final String tenantId;
  final String name;
  final String? description;
  final String priceType; // "per_kg" | "per_item"
  final String unit; // "kg", "pcs", etc.
  final double price;
  final int? estimatedDurationHours;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceModel({
    required this.id,
    required this.tenantId,
    required this.name,
    this.description,
    required this.priceType,
    required this.unit,
    required this.price,
    this.estimatedDurationHours,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      priceType: json['price_type'] as String? ?? 'per_kg',
      unit: json['unit'] as String? ?? 'kg',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      estimatedDurationHours: json['estimated_duration_hours'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty) 'description': description,
      'price_type': priceType,
      'unit': unit,
      'price': price.toStringAsFixed(2),
      if (estimatedDurationHours != null) 'estimated_duration_hours': estimatedDurationHours,
      'is_active': isActive,
    };
  }

  String get formattedPrice {
    final formattedNumber = price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    return 'Rp $formattedNumber / $unit';
  }
}
