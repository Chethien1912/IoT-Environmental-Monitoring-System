import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/device_state.dart';
import '../models/device_summary.dart';
import '../models/telemetry_entry.dart';
import '../models/user_account.dart';

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrlCandidates = _resolveBaseUrls(baseUrl),
        _activeBaseUrl = _resolveBaseUrls(baseUrl).first;
  final http.Client _client;
  List<String> _baseUrlCandidates;
  String _activeBaseUrl;
  String? _accessToken;
  String? _refreshToken;

  String get baseUrl => _activeBaseUrl;

  static List<String> _resolveBaseUrls(String? explicitBaseUrl) {
    if (explicitBaseUrl != null && explicitBaseUrl.trim().isNotEmpty) {
      return [explicitBaseUrl.trim()];
    }

    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return [configuredBaseUrl];
    }

    if (kIsWeb) {
      return ['http://localhost:3000'];
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return ['http://192.168.1.21:3000', 'http://10.0.2.2:3000'];
    }

    return ['http://localhost:3000'];
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  void setBaseUrl(String? baseUrl) {
    final normalized = baseUrl == null ? '' : _normalizeBaseUrl(baseUrl);
    final defaults = _resolveBaseUrls(null);
    if (normalized.isEmpty) {
      _baseUrlCandidates = defaults;
      _activeBaseUrl = defaults.first;
      return;
    }

    _activeBaseUrl = normalized;
    _baseUrlCandidates = <String>[
      normalized,
      ...defaults.where((candidate) => candidate != normalized),
    ];
  }

  Uri _uri(String baseUrl, String path) => Uri.parse('$baseUrl$path');

  Future<http.Response> _withBaseUrlFallback(
    Future<http.Response> Function(String baseUrl) send,
  ) async {
    final orderedCandidates = <String>[
      _activeBaseUrl,
      ..._baseUrlCandidates.where((candidate) => candidate != _activeBaseUrl),
    ];

    Exception? lastError;
    for (final candidate in orderedCandidates) {
      try {
        final response =
            await send(candidate).timeout(const Duration(seconds: 5));
        _activeBaseUrl = candidate;
        return response;
      } on SocketException catch (error) {
        lastError = Exception(error.message);
      } on http.ClientException catch (error) {
        lastError = Exception(error.message);
      } on TimeoutException {
        lastError = Exception('Request timed out');
      }
    }

    throw lastError ?? Exception('Cannot connect to backend');
  }

  Map<String, String> _headers({bool json = false}) {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  void applySession(AuthSession session) {
    _accessToken = session.accessToken;
    _refreshToken = session.refreshToken;
  }

  void clearSession() {
    _accessToken = null;
    _refreshToken = null;
  }

  dynamic _decodeBody(http.Response response) {
    return jsonDecode(response.body);
  }

  Exception _buildException(http.Response response, String fallbackMessage) {
    try {
      final payload = _decodeBody(response);
      if (payload is Map<String, dynamic> && payload['error'] is String) {
        return Exception(payload['error'] as String);
      }
    } catch (_) {}
    return Exception(fallbackMessage);
  }

  Map<String, dynamic> _unwrapSuccessMap(
      http.Response response, String fallbackMessage) {
    final payload = _decodeBody(response);
    if (payload is! Map<String, dynamic>) {
      throw Exception(fallbackMessage);
    }
    if (payload['success'] != true) {
      throw _buildException(response, fallbackMessage);
    }
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception(fallbackMessage);
  }

  List<dynamic> _unwrapSuccessList(
      http.Response response, String fallbackMessage) {
    final payload = _decodeBody(response);
    if (payload is! Map<String, dynamic>) {
      throw Exception(fallbackMessage);
    }
    if (payload['success'] != true) {
      throw _buildException(response, fallbackMessage);
    }
    final data = payload['data'];
    if (data is List<dynamic>) {
      return data;
    }
    throw Exception(fallbackMessage);
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.post(
        _uri(baseUrl, '/api/auth/login'),
        headers: _headers(json: true),
        body: jsonEncode({'username': username, 'password': password}),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to login');
    }

    final session = AuthSession.fromJson(
        _unwrapSuccessMap(response, 'Invalid login payload'));
    applySession(session);
    return session;
  }

  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.post(
        _uri(baseUrl, '/api/auth/register'),
        headers: _headers(json: true),
        body: jsonEncode({'username': username, 'password': password}),
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildException(response, 'Failed to register');
    }

    final session = AuthSession.fromJson(
      _unwrapSuccessMap(response, 'Invalid register payload'),
    );
    applySession(session);
    return session;
  }

  Future<void> logout() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      clearSession();
      return;
    }

    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.post(
        _uri(baseUrl, '/api/auth/logout'),
        headers: _headers(json: true),
        body: jsonEncode({'refreshToken': refreshToken}),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to logout');
    }

    clearSession();
  }

  Future<List<DeviceSummary>> fetchDevices() async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.get(
        _uri(baseUrl, '/api/devices'),
        headers: _headers(),
      ),
    );
    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to load devices');
    }

    final list = _unwrapSuccessList(response, 'Failed to parse devices');
    return list
        .map((item) => DeviceSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DeviceState> fetchDeviceState(String deviceId) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.get(
        _uri(baseUrl, '/api/devices/$deviceId'),
        headers: _headers(),
      ),
    );
    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to load device state');
    }

    return DeviceState.fromJson(
      _unwrapSuccessMap(response, 'Failed to parse device state'),
    );
  }

  Future<Map<String, dynamic>> addDevice({
    required String name,
    required String type,
    String? hardwareId,
  }) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.post(
        _uri(baseUrl, '/api/devices'),
        headers: _headers(json: true),
        body: jsonEncode({
          'name': name,
          'type': type,
          if (hardwareId != null && hardwareId.trim().isNotEmpty)
            'hardwareId': hardwareId.trim(),
        }),
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildException(response, 'Failed to add device');
    }

    return _unwrapSuccessMap(response, 'Failed to parse device');
  }

  Future<Map<String, dynamic>> sendCommand(
    String deviceId,
    String action, {
    Map<String, dynamic>? params,
  }) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.post(
        _uri(baseUrl, '/api/devices/$deviceId/command'),
        headers: _headers(json: true),
        body: jsonEncode({
          'action': action,
          'params': params ?? <String, dynamic>{},
        }),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to send command');
    }

    return _unwrapSuccessMap(response, 'Failed to parse command response');
  }

  Future<DeviceState> updateRelayState(
    String deviceId, {
    bool? relay1On,
    bool? relay2On,
    bool? relay3On,
    bool? relay4On,
  }) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.put(
        _uri(baseUrl, '/api/devices/$deviceId/control-state'),
        headers: _headers(json: true),
        body: jsonEncode({
          if (relay1On != null) 'desiredRelay1On': relay1On,
          if (relay2On != null) 'desiredRelay2On': relay2On,
          if (relay3On != null) 'desiredRelay3On': relay3On,
          if (relay4On != null) 'desiredRelay4On': relay4On,
        }),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to update relay state');
    }

    return DeviceState.fromJson(
      _unwrapSuccessMap(response, 'Failed to parse relay state response'),
    );
  }

  Future<DeviceState> updateAutomationSettings(
    String deviceId, {
    required String controlMode,
    required Map<String, dynamic> automationSettings,
  }) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.put(
        _uri(baseUrl, '/api/devices/$deviceId/automation'),
        headers: _headers(json: true),
        body: jsonEncode({
          'controlMode': controlMode,
          'automationSettings': automationSettings,
        }),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to update automation settings');
    }

    return DeviceState.fromJson(
      _unwrapSuccessMap(
          response, 'Failed to parse automation settings response'),
    );
  }

  Future<DeviceState> bindHardwareId(String deviceId, String hardwareId) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.put(
        _uri(baseUrl, '/api/devices/$deviceId/hardware'),
        headers: _headers(json: true),
        body: jsonEncode({
          'hardwareId': hardwareId.trim(),
        }),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to bind hardware ID');
    }

    return DeviceState.fromJson(
      _unwrapSuccessMap(response, 'Failed to parse hardware binding response'),
    );
  }

  Future<DeviceState> unbindHardwareId(String deviceId) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.put(
        _uri(baseUrl, '/api/devices/$deviceId/hardware'),
        headers: _headers(json: true),
        body: jsonEncode({'hardwareId': ''}),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to unbind hardware ID');
    }

    return DeviceState.fromJson(
      _unwrapSuccessMap(response, 'Failed to parse hardware unbind response'),
    );
  }

  Future<DeviceState> syncRtc(String deviceId, DateTime dateTime) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.put(
        _uri(baseUrl, '/api/devices/$deviceId/rtc-sync'),
        headers: _headers(json: true),
        body: jsonEncode({
          'dateTimeIso': dateTime.toIso8601String(),
        }),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to sync RTC');
    }

    return DeviceState.fromJson(
      _unwrapSuccessMap(response, 'Failed to parse RTC sync response'),
    );
  }

  Future<List<TelemetryEntry>> fetchTelemetryHistory(
    String deviceId, {
    int limit = 120,
    String? fromIso,
  }) async {
    final uriPath =
        StringBuffer('/api/devices/$deviceId/telemetry?limit=$limit');
    if (fromIso != null && fromIso.trim().isNotEmpty) {
      uriPath.write('&from=${Uri.encodeQueryComponent(fromIso)}');
    }

    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.get(
        _uri(baseUrl, uriPath.toString()),
        headers: _headers(),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to load telemetry history');
    }

    final list =
        _unwrapSuccessList(response, 'Failed to parse telemetry history');
    return list
        .map((item) => TelemetryEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserAccount>> fetchUsers() async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.get(
        _uri(baseUrl, '/api/users'),
        headers: _headers(),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to load users');
    }

    final list = _unwrapSuccessList(response, 'Failed to parse users');
    return list
        .map((item) => UserAccount.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserAccount> createUser({
    required String username,
    required String password,
    required String role,
  }) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.post(
        _uri(baseUrl, '/api/users'),
        headers: _headers(json: true),
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
          'role': role,
        }),
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildException(response, 'Failed to create user');
    }

    return UserAccount.fromJson(
      _unwrapSuccessMap(response, 'Failed to parse created user'),
    );
  }

  Future<UserAccount> updateUser(
    int userId, {
    String? username,
    String? role,
    bool? isActive,
  }) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.put(
        _uri(baseUrl, '/api/users/$userId'),
        headers: _headers(json: true),
        body: jsonEncode({
          if (username != null) 'username': username.trim(),
          if (role != null) 'role': role,
          if (isActive != null) 'is_active': isActive,
        }),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to update user');
    }

    return UserAccount.fromJson(
      _unwrapSuccessMap(response, 'Failed to parse updated user'),
    );
  }

  Future<void> resetUserPassword(int userId, String newPassword) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.put(
        _uri(baseUrl, '/api/users/$userId/reset-password'),
        headers: _headers(json: true),
        body: jsonEncode({'newPassword': newPassword}),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to reset password');
    }
  }

  Future<void> deleteUser(int userId) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.delete(
        _uri(baseUrl, '/api/users/$userId'),
        headers: _headers(),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to delete user');
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    final response = await _withBaseUrlFallback(
      (baseUrl) => _client.delete(
        _uri(baseUrl, '/api/devices/$deviceId'),
        headers: _headers(),
      ),
    );

    if (response.statusCode != 200) {
      throw _buildException(response, 'Failed to delete device');
    }
  }
}
