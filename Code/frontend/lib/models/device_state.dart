class DeviceState {
  const DeviceState({
    required this.id,
    required this.name,
    required this.type,
    required this.hardwareId,
    required this.isOnline,
    required this.lastSeen,
    required this.createdAt,
    required this.ownerId,
    required this.ownerUsername,
    required this.desiredRelay1On,
    required this.desiredRelay2On,
    required this.desiredRelay3On,
    required this.desiredRelay4On,
    required this.controlMode,
    required this.automationSettings,
    required this.pendingRtcVersion,
    required this.pendingRtcPayload,
    required this.lastTelemetry,
  });

  final String id;
  final String name;
  final String type;
  final String hardwareId;
  final bool isOnline;
  final String lastSeen;
  final String createdAt;
  final int ownerId;
  final String ownerUsername;
  final bool desiredRelay1On;
  final bool desiredRelay2On;
  final bool desiredRelay3On;
  final bool desiredRelay4On;
  final String controlMode;
  final Map<String, dynamic> automationSettings;
  final int pendingRtcVersion;
  final Map<String, dynamic> pendingRtcPayload;
  final Map<String, dynamic> lastTelemetry;

  DeviceState copyWith({
    String? id,
    String? name,
    String? type,
    String? hardwareId,
    bool? isOnline,
    String? lastSeen,
    String? createdAt,
    int? ownerId,
    String? ownerUsername,
    bool? desiredRelay1On,
    bool? desiredRelay2On,
    bool? desiredRelay3On,
    bool? desiredRelay4On,
    String? controlMode,
    Map<String, dynamic>? automationSettings,
    int? pendingRtcVersion,
    Map<String, dynamic>? pendingRtcPayload,
    Map<String, dynamic>? lastTelemetry,
  }) {
    return DeviceState(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      hardwareId: hardwareId ?? this.hardwareId,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      ownerId: ownerId ?? this.ownerId,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      desiredRelay1On: desiredRelay1On ?? this.desiredRelay1On,
      desiredRelay2On: desiredRelay2On ?? this.desiredRelay2On,
      desiredRelay3On: desiredRelay3On ?? this.desiredRelay3On,
      desiredRelay4On: desiredRelay4On ?? this.desiredRelay4On,
      controlMode: controlMode ?? this.controlMode,
      automationSettings: automationSettings ?? this.automationSettings,
      pendingRtcVersion: pendingRtcVersion ?? this.pendingRtcVersion,
      pendingRtcPayload: pendingRtcPayload ?? this.pendingRtcPayload,
      lastTelemetry: lastTelemetry ?? this.lastTelemetry,
    );
  }

  double get temperatureC {
    final value = lastTelemetry['temp'] ?? lastTelemetry['temperatureC'];
    return value is num ? value.toDouble() : 0;
  }

  double get humidityPercent {
    final value = lastTelemetry['humidity'] ?? lastTelemetry['humidityPercent'];
    return value is num ? value.toDouble() : 0;
  }

  double get coPpm {
    final value = lastTelemetry['co'] ?? lastTelemetry['coPpm'];
    return value is num ? value.toDouble() : 0;
  }

  double get no2Ppm {
    final value = lastTelemetry['no2'] ?? lastTelemetry['no2Ppm'];
    return value is num ? value.toDouble() : 0;
  }

  bool get relay1On =>
      lastTelemetry['relay1On'] == true || lastTelemetry['relay1On'] == 1;

  bool get relay2On =>
      lastTelemetry['relay2On'] == true || lastTelemetry['relay2On'] == 1;

  bool get relay3On =>
      lastTelemetry['relay3On'] == true || lastTelemetry['relay3On'] == 1;

  bool get relay4On =>
      lastTelemetry['relay4On'] == true || lastTelemetry['relay4On'] == 1;

  bool get buzzerOn =>
      lastTelemetry['buzzerOn'] == true ||
      lastTelemetry['buzzerOn'] == 1 ||
      relay4On;

  String get rtcDateText {
    final value = lastTelemetry['dateText'];
    return value is String ? value : '--/--/----';
  }

  String get rtcTimeText {
    final value = lastTelemetry['timeText'];
    return value is String ? value : '--:--:--';
  }

  factory DeviceState.fromJson(Map<String, dynamic> json) {
    String asString(dynamic value) => value is String ? value : '';
    bool asBool(dynamic value) => value is bool ? value : value == 1;
    int asInt(dynamic value) => value is num ? value.toInt() : 0;

    final telemetry = json['last_telemetry'] is Map<String, dynamic>
        ? json['last_telemetry'] as Map<String, dynamic>
        : <String, dynamic>{};
    final owner = json['owner'] is Map<String, dynamic>
        ? json['owner'] as Map<String, dynamic>
        : <String, dynamic>{};
    final pendingRtc = json['pending_rtc_payload'] is Map<String, dynamic>
        ? json['pending_rtc_payload'] as Map<String, dynamic>
        : <String, dynamic>{};
    final automationSettings = json['automation_settings'] is Map<String, dynamic>
        ? json['automation_settings'] as Map<String, dynamic>
        : <String, dynamic>{};

    return DeviceState(
      id: asString(json['id']),
      name: asString(json['name']),
      type: asString(json['type']),
      hardwareId: asString(json['hardware_id']),
      isOnline: asBool(json['is_online']),
      lastSeen: asString(json['last_seen']),
      createdAt: asString(json['created_at']),
      ownerId: asInt(owner['id']),
      ownerUsername: asString(owner['username']),
      desiredRelay1On: asBool(json['desired_relay1']),
      desiredRelay2On: asBool(json['desired_relay2']),
      desiredRelay3On: asBool(json['desired_relay3']),
      desiredRelay4On: asBool(json['desired_relay4']),
      controlMode: asString(json['control_mode']),
      automationSettings: automationSettings,
      pendingRtcVersion: asInt(json['pending_rtc_version']),
      pendingRtcPayload: pendingRtc,
      lastTelemetry: telemetry,
    );
  }
}
