class DeviceSummary {
  const DeviceSummary({
    required this.id,
    required this.name,
    required this.type,
    required this.hardwareId,
    required this.isOnline,
    required this.lastSeen,
    required this.temperatureC,
    required this.humidityPercent,
    required this.ownerUsername,
  });

  final String id;
  final String name;
  final String type;
  final String hardwareId;
  final bool isOnline;
  final String lastSeen;
  final double temperatureC;
  final double humidityPercent;
  final String ownerUsername;

  factory DeviceSummary.fromJson(Map<String, dynamic> json) {
    String asString(dynamic value) => value is String ? value : '';
    bool asBool(dynamic value) => value is bool ? value : value == 1;
    double asDouble(dynamic value) => value is num ? value.toDouble() : 0;

    final telemetry =
        json['last_telemetry'] is Map<String, dynamic> ? json['last_telemetry'] as Map<String, dynamic> : const {};
    final owner = json['owner'] is Map<String, dynamic> ? json['owner'] as Map<String, dynamic> : const {};

    return DeviceSummary(
      id: asString(json['id']),
      name: asString(json['name']),
      type: asString(json['type']),
      hardwareId: asString(json['hardware_id']),
      isOnline: asBool(json['is_online']),
      lastSeen: asString(json['last_seen']),
      temperatureC: asDouble(telemetry['temp'] ?? telemetry['temperatureC']),
      humidityPercent:
          asDouble(telemetry['humidity'] ?? telemetry['humidityPercent']),
      ownerUsername: asString(owner['username']),
    );
  }
}
