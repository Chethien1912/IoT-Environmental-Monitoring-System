class TelemetryEntry {
  const TelemetryEntry({
    required this.id,
    required this.receivedAt,
    required this.payload,
  });

  final int id;
  final String receivedAt;
  final Map<String, dynamic> payload;

  double metricValue(String metricKey) {
    final candidates = <String>[
      metricKey,
      if (metricKey == 'temperatureC') 'temp',
      if (metricKey == 'humidityPercent') 'humidity',
      if (metricKey == 'coPpm') 'co',
      if (metricKey == 'no2Ppm') 'no2',
    ];

    for (final key in candidates) {
      final dynamic value = payload[key];
      if (value is num) {
        return value.toDouble();
      }
    }
    return 0;
  }

  factory TelemetryEntry.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) => value is num ? value.toInt() : 0;
    String asString(dynamic value) => value is String ? value : '';

    final payload = json['payload'];
    return TelemetryEntry(
      id: asInt(json['id']),
      receivedAt: asString(json['received_at']),
      payload: payload is Map<String, dynamic> ? payload : <String, dynamic>{},
    );
  }
}
