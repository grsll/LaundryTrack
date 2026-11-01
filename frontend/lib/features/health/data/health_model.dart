class HealthModel {
  final String status;
  final String appName;
  final String environment;
  final String version;
  final String database;
  final String timestamp;

  const HealthModel({
    required this.status,
    required this.appName,
    required this.environment,
    required this.version,
    required this.database,
    required this.timestamp,
  });

  factory HealthModel.fromJson(Map<String, dynamic> json) {
    return HealthModel(
      status: json['status'] as String? ?? 'unknown',
      appName: json['app_name'] as String? ?? '',
      environment: json['environment'] as String? ?? '',
      version: json['version'] as String? ?? '',
      database: json['database'] as String? ?? 'unknown',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}
