import 'dart:async';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/auth_session.dart';
import '../models/device_state.dart';
import '../models/telemetry_entry.dart';
import '../services/api_client.dart';
import '../widgets/dashboard_chrome.dart';
import 'metric_detail_page.dart';

class DeviceDetailPage extends StatefulWidget {
  const DeviceDetailPage({
    super.key,
    required this.api,
    required this.session,
    required this.deviceId,
    this.onLogout,
  });

  final ApiClient api;
  final AuthSession session;
  final String deviceId;
  final Future<void> Function()? onLogout;

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  Timer? _clockTicker;
  io.Socket? _socket;
  final TextEditingController _hardwareIdController = TextEditingController();

  DeviceState? _device;
  List<TelemetryEntry> _entries = const [];
  bool _loading = true;
  bool _syncingRtc = false;
  bool _savingHardwareId = false;
  bool _loggingOutFromDevice = false;
  String? _error;

  int _currentIndex = 0;
  String _selectedMetricKey = 'temperatureC';
  DateTime? _rtcBaseDateTime;
  DateTime? _rtcBaseCapturedAt;
  DateTime? _selectedRtcDateTime;
  DateTime _appNow = DateTime.now();
  String _liveRtcDateText = '--/--/----';
  String _liveRtcTimeText = '--:--:--';
  String _controlMode = 'manual';
  Map<String, dynamic> _automationSettings = {};
  bool _hasPendingAutomationEdits = false;
  bool _hasPendingHardwareIdEdit = false;

  @override
  void initState() {
    super.initState();
    _startClockTicker();
    _fetchAll();
    _connectRealtime();
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _socket?.dispose();
    _hardwareIdController.dispose();
    super.dispose();
  }

  void _connectRealtime() {
    final socket = io.io(
      widget.api.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': widget.session.accessToken})
          .build(),
    );

    socket.onConnect((_) {
      socket.emit('subscribe:device', {'deviceId': widget.deviceId});
    });

    bool isCurrentDevice(dynamic payload) {
      final data = payload is Map ? Map<String, dynamic>.from(payload) : null;
      return data != null && data['deviceId'] == widget.deviceId && mounted;
    }

    void handleTelemetry(dynamic payload) {
      final data = payload is Map ? Map<String, dynamic>.from(payload) : null;
      if (data == null || data['deviceId'] != widget.deviceId || !mounted) {
        return;
      }

      final telemetry = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : null;
      final current = _device;
      if (telemetry == null || current == null) {
        _fetchAll(silent: true);
        return;
      }

      final timestamp = data['timestamp'] is String
          ? data['timestamp'] as String
          : DateTime.now().toIso8601String();
      final updated = current.copyWith(
        isOnline: true,
        lastSeen: timestamp,
        desiredRelay1On:
            _boolFromTelemetry(telemetry['relay1On']) ?? current.desiredRelay1On,
        desiredRelay2On:
            _boolFromTelemetry(telemetry['relay2On']) ?? current.desiredRelay2On,
        desiredRelay3On:
            _boolFromTelemetry(telemetry['relay3On']) ?? current.desiredRelay3On,
        lastTelemetry: telemetry,
      );
      _syncLiveRtcFromDevice(updated);
      setState(() {
        _device = updated;
        _entries = _appendRealtimeEntry(_entries, telemetry, timestamp);
        _loading = false;
        _error = null;
      });
    }

    void refresh(dynamic payload) {
      if (!isCurrentDevice(payload)) {
        return;
      }
      _fetchAll(silent: true);
    }

    socket.on('telemetry', handleTelemetry);
    socket.on('device:status', refresh);
    socket.on('command:ack', refresh);
    socket.onConnectError((error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    });

    socket.connect();
    _socket = socket;
  }

  List<TelemetryEntry> _appendRealtimeEntry(
    List<TelemetryEntry> entries,
    Map<String, dynamic> telemetry,
    String timestamp,
  ) {
    final next = <TelemetryEntry>[
      ...entries,
      TelemetryEntry(
        id: DateTime.now().millisecondsSinceEpoch,
        receivedAt: timestamp,
        payload: telemetry,
      ),
    ];
    const maxRealtimeEntries = 1200;
    if (next.length <= maxRealtimeEntries) {
      return next;
    }
    return next.sublist(next.length - maxRealtimeEntries);
  }

  bool? _boolFromTelemetry(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  void _startClockTicker() {
    _clockTicker?.cancel();
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final nextAppNow = DateTime.now();
      final base = _rtcBaseDateTime;
      final capturedAt = _rtcBaseCapturedAt;
      if (!mounted) {
        return;
      }

      if (base == null || capturedAt == null) {
        setState(() {
          _appNow = nextAppNow;
        });
        return;
      }

      final elapsed = nextAppNow.difference(capturedAt).inSeconds;
      final current = base.add(Duration(seconds: elapsed));
      final nextDate = _formatDate(current);
      final nextTime = _formatTime(current);
      if (_liveRtcDateText == nextDate &&
          _liveRtcTimeText == nextTime &&
          _appNow.second == nextAppNow.second &&
          _appNow.minute == nextAppNow.minute &&
          _appNow.hour == nextAppNow.hour &&
          _appNow.day == nextAppNow.day &&
          _appNow.month == nextAppNow.month &&
          _appNow.year == nextAppNow.year) {
        return;
      }

      setState(() {
        _appNow = nextAppNow;
        _liveRtcDateText = nextDate;
        _liveRtcTimeText = nextTime;
      });
    });
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final results = await Future.wait([
        widget.api.fetchDeviceState(widget.deviceId),
        widget.api.fetchTelemetryHistory(
          widget.deviceId,
          limit: 288,
          fromIso: dayStart,
        ),
      ]);

      if (!mounted) {
        return;
      }

      final device = results[0] as DeviceState;
      final entries = results[1] as List<TelemetryEntry>;
      _syncLiveRtcFromDevice(device);
      _syncAutomationFromDevice(device);
      _syncHardwareIdFromDevice(device);
      setState(() {
        _device = device;
        _entries = entries;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _syncLiveRtcFromDevice(DeviceState device) {
    final parsed = _parseDeviceRtc(device);
    if (parsed == null) {
      return;
    }
    _rtcBaseDateTime = parsed;
    _rtcBaseCapturedAt = DateTime.now();
    _liveRtcDateText = _formatDate(parsed);
    _liveRtcTimeText = _formatTime(parsed);
    _selectedRtcDateTime ??= parsed;
  }

  void _syncAutomationFromDevice(DeviceState device, {bool force = false}) {
    if (_hasPendingAutomationEdits && !force) {
      return;
    }
    _controlMode = device.controlMode == 'auto' ? 'auto' : 'manual';
    _automationSettings =
        _sanitizeAutomationSettings(device.automationSettings);
  }

  void _syncHardwareIdFromDevice(DeviceState device, {bool force = false}) {
    if (_hasPendingHardwareIdEdit && !force) {
      return;
    }

    final nextValue = device.hardwareId;
    if (_hardwareIdController.text != nextValue) {
      _hardwareIdController.text = nextValue;
    }
  }

  Map<String, dynamic> _ensureConfig(String key) {
    final source = _automationSettings[key];
    return _asStringDynamicMap(source);
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), item),
      );
    }
    return <String, dynamic>{};
  }

  double _toDouble(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? fallback;
  }

  double _clampDouble(
    dynamic value, {
    required double min,
    required double max,
    required double fallback,
  }) {
    return _toDouble(value, fallback).clamp(min, max).toDouble();
  }

  Map<String, dynamic> _sanitizeAutomationSettings(
      Map<String, dynamic> source) {
    final relay1 = _asStringDynamicMap(source['relay1']);
    final relay2 = _asStringDynamicMap(source['relay2']);
    final relay3 = _asStringDynamicMap(source['relay3']);
    final buzzer = _asStringDynamicMap(source['buzzer']);

    return {
      ...source,
      'relay1': {
        ...relay1,
        'threshold': _clampDouble(
          relay1['threshold'],
          min: 0,
          max: 80,
          fallback: 35,
        ),
      },
      'relay2': {
        ...relay2,
        'threshold': _clampDouble(
          relay2['threshold'],
          min: 0,
          max: 100,
          fallback: 70,
        ),
      },
      'relay3': {
        ...relay3,
        'coThreshold': _clampDouble(
          relay3['coThreshold'],
          min: 0,
          max: 1000,
          fallback: 50,
        ),
        'no2Threshold': _clampDouble(
          relay3['no2Threshold'],
          min: 0,
          max: 15,
          fallback: 0.5,
        ),
      },
      'buzzer': {
        ...buzzer,
        'temperatureThreshold': _clampDouble(
          buzzer['temperatureThreshold'],
          min: 0,
          max: 80,
          fallback: 38,
        ),
        'humidityThreshold': _clampDouble(
          buzzer['humidityThreshold'],
          min: 0,
          max: 100,
          fallback: 80,
        ),
        'coThreshold': _clampDouble(
          buzzer['coThreshold'],
          min: 0,
          max: 1000,
          fallback: 100,
        ),
        'no2Threshold': _clampDouble(
          buzzer['no2Threshold'],
          min: 0,
          max: 15,
          fallback: 1,
        ),
      },
    };
  }

  double _metricThreshold(String metricKey) {
    final relay1 = _ensureConfig('relay1');
    final relay2 = _ensureConfig('relay2');
    final relay3 = _ensureConfig('relay3');
    switch (metricKey) {
      case 'temperatureC':
        return (relay1['threshold'] ?? 35).toDouble();
      case 'humidityPercent':
        return (relay2['threshold'] ?? 70).toDouble();
      case 'coPpm':
        return (relay3['coThreshold'] ?? 50).toDouble();
      case 'no2Ppm':
        return (relay3['no2Threshold'] ?? 0.5).toDouble();
      default:
        return 100;
    }
  }

  DateTime? _parseDeviceRtc(DeviceState device) {
    final dateParts = device.rtcDateText.split('/');
    final timeParts = device.rtcTimeText.split(':');
    if (dateParts.length != 3 || timeParts.length != 3) {
      return null;
    }

    final day = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final year = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    final second = int.tryParse(timeParts[2]);

    if ([day, month, year, hour, minute, second].contains(null)) {
      return null;
    }

    return DateTime(year!, month!, day!, hour!, minute!, second!);
  }

  String _formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year.toString().padLeft(4, '0')}';
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';
  }

  String get _appDateText => _formatDate(_appNow);
  String get _appTimeText => _formatTime(_appNow);
  Future<void> _updateRelay({
    bool? relay1,
    bool? relay2,
    bool? relay3,
    bool? relay4,
  }) async {
    if (_device == null) {
      return;
    }

    try {
      final updated = await widget.api.updateRelayState(
        widget.deviceId,
        relay1On: relay1,
        relay2On: relay2,
        relay3On: relay3,
        relay4On: relay4,
      );
      if (!mounted) {
        return;
      }
      _syncLiveRtcFromDevice(updated);
      setState(() => _device = updated);
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _pickRtcDate() async {
    final initial = _selectedRtcDateTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2099),
      builder: _pickerThemeBuilder,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      final current = _selectedRtcDateTime ?? DateTime.now();
      _selectedRtcDateTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
        current.second,
      );
    });
  }

  Future<void> _pickRtcTime() async {
    final initial = _selectedRtcDateTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: _pickerThemeBuilder,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      final current = _selectedRtcDateTime ?? DateTime.now();
      _selectedRtcDateTime = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
        current.second,
      );
    });
  }

  Widget _pickerThemeBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppPalette.cyan,
          onPrimary: AppPalette.midnight,
          surface: AppPalette.panel,
          onSurface: Colors.white,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Future<void> _syncRtcWithBoard() async {
    final selected = _selectedRtcDateTime;
    if (selected == null) {
      _showError('Chua co thoi gian de dong bo.');
      return;
    }

    setState(() => _syncingRtc = true);
    try {
      final updated = await widget.api.syncRtc(widget.deviceId, selected);
      if (!mounted) {
        return;
      }

      _syncLiveRtcFromDevice(updated);
      setState(() => _device = updated);
      _showInfoSnackBar('Da gui lenh dong bo thoi gian cho ESP32.');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _syncingRtc = false);
      }
    }
  }

  void _useCurrentSystemTime() {
    setState(() {
      _selectedRtcDateTime = DateTime.now();
    });
  }

  Future<void> _saveAutomation() async {
    if (_device == null) {
      return;
    }

    try {
      final updated = await widget.api.updateAutomationSettings(
        widget.deviceId,
        controlMode: _controlMode,
        automationSettings: _automationSettings,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _hasPendingAutomationEdits = false;
        _syncAutomationFromDevice(updated, force: true);
        _device = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu chế độ và cài đặt automation.')),
      );
    } catch (error) {
      _showError(error);
    }
  }

  void _setControlMode(String mode) {
    setState(() {
      _hasPendingAutomationEdits = true;
      _controlMode = mode == 'auto' ? 'auto' : 'manual';
    });
  }

  Future<void> _saveHardwareId() async {
    if (_device == null) {
      return;
    }

    final hardwareId = _hardwareIdController.text.trim();
    if (hardwareId.isEmpty) {
      _showError('Hãy nhập MAC / Hardware ID để liên kết board.');
      return;
    }

    setState(() => _savingHardwareId = true);
    try {
      final updated =
          await widget.api.bindHardwareId(widget.deviceId, hardwareId);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasPendingHardwareIdEdit = false;
        _syncHardwareIdFromDevice(updated, force: true);
        _device = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu MAC và liên kết với board.')),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _savingHardwareId = false);
      }
    }
  }

  Future<void> _clearHardwareId({bool showMessage = true}) async {
    if (_device == null) {
      return;
    }

    setState(() => _savingHardwareId = true);
    try {
      final updated = await widget.api.unbindHardwareId(widget.deviceId);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasPendingHardwareIdEdit = false;
        _syncHardwareIdFromDevice(updated, force: true);
        _device = updated;
      });
      if (showMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Đã ngắt liên kết MAC. Lần sau cần nhập lại MAC để dùng board này.'),
          ),
        );
      }
    } catch (error) {
      _showError(error);
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _savingHardwareId = false);
      }
    }
  }

  Future<void> _logoutFromCurrentDevice() async {
    if (widget.onLogout == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất khỏi board?'),
        content: const Text(
          'Tài khoản hiện tại sẽ đăng xuất và MAC của board này cũng bị gỡ liên kết. Lần đăng nhập sau cần nhập lại MAC để kết nối lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _loggingOutFromDevice = true);
    try {
      if ((_device?.hardwareId ?? '').isNotEmpty) {
        await _clearHardwareId(showMessage: false);
      }

      await widget.api.deleteDevice(widget.deviceId);

      await widget.onLogout!.call();
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() => _loggingOutFromDevice = false);
      }
    }
  }

  void _updateAutomationValue(
    String outputKey,
    String fieldKey,
    dynamic value,
  ) {
    final nextOutput = _ensureConfig(outputKey);
    nextOutput[fieldKey] = value;
    setState(() {
      _hasPendingAutomationEdits = true;
      _automationSettings = Map<String, dynamic>.from(_automationSettings)
        ..[outputKey] = nextOutput;
    });
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    final message = error.toString().replaceFirst('Exception: ', '');
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF0F2138),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  List<MetricDescriptor> _metrics(DeviceState? device) {
    return [
      MetricDescriptor(
        title: 'Nhiet do',
        value: device?.temperatureC ?? 0,
        unit: 'C',
        color: AppPalette.amber,
        icon: Icons.thermostat_rounded,
        telemetryKey: 'temperatureC',
        decimals: 1,
        safeUpperBound: _metricThreshold('temperatureC'),
      ),
      MetricDescriptor(
        title: 'Do am',
        value: device?.humidityPercent ?? 0,
        unit: '%',
        color: AppPalette.mint,
        icon: Icons.water_drop_rounded,
        telemetryKey: 'humidityPercent',
        decimals: 1,
        safeUpperBound: _metricThreshold('humidityPercent'),
      ),
      MetricDescriptor(
        title: 'CO',
        value: device?.coPpm ?? 0,
        unit: 'ppm',
        color: AppPalette.coral,
        icon: Icons.cloud_rounded,
        telemetryKey: 'coPpm',
        decimals: 2,
        safeUpperBound: _metricThreshold('coPpm'),
      ),
      MetricDescriptor(
        title: 'NO2',
        value: device?.no2Ppm ?? 0,
        unit: 'ppm',
        color: AppPalette.violet,
        icon: Icons.blur_on_rounded,
        telemetryKey: 'no2Ppm',
        decimals: 3,
        safeUpperBound: _metricThreshold('no2Ppm'),
      ),
    ];
  }

  MetricDescriptor get _selectedMetric {
    final list = _metrics(_device);
    return list.firstWhere(
      (metric) => metric.telemetryKey == _selectedMetricKey,
      orElse: () => list.first,
    );
  }

  int _airScore(DeviceState? device) {
    if (device == null) {
      return 0;
    }

    final tempScore = 100 -
        ((device.temperatureC / _metricThreshold('temperatureC')) * 30).round();
    final humidityScore = 100 -
        ((device.humidityPercent / _metricThreshold('humidityPercent')) * 20)
            .round();
    final coScore =
        100 - ((device.coPpm / _metricThreshold('coPpm')) * 30).round();
    final no2Score =
        100 - ((device.no2Ppm / _metricThreshold('no2Ppm')) * 20).round();
    final score =
        ((tempScore + humidityScore + coScore + no2Score) / 4).round();
    return score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final rtcDate = _liveRtcDateText == '--/--/----'
        ? (device?.rtcDateText ?? '--/--/----')
        : _liveRtcDateText;
    final rtcTime = _liveRtcTimeText == '--:--:--'
        ? (device?.rtcTimeText ?? '--:--:--')
        : _liveRtcTimeText;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(device),
              Expanded(
                child: _buildPageBody(device, rtcDate, rtcTime),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(DeviceState? device) {
    final title = device?.name ?? 'Chi tiết thiết bị';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Chọn thiết bị'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (widget.onLogout != null) ...[
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed:
                  _loggingOutFromDevice ? null : _logoutFromCurrentDevice,
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                _loggingOutFromDevice ? 'Đang xử lý...' : 'Đăng xuất',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageBody(DeviceState? device, String rtcDate, String rtcTime) {
    if (_loading && device == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && device == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: const TextStyle(color: AppPalette.danger),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    switch (_currentIndex) {
      case 1:
        return _buildAlertPageVi(device);
      case 2:
        return _buildSettingsPage(device, rtcDate, rtcTime);
      case 3:
        return _buildUserPage(device);
      default:
        return RefreshIndicator(
          onRefresh: _fetchAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
            children: [
              _buildHero(device, rtcDate, rtcTime),
              const SizedBox(height: 18),
              _buildMetricSection(device),
              const SizedBox(height: 18),
              _buildRelaySection(device),
              const SizedBox(height: 28),
            ],
          ),
        );
    }
  }

  Widget _buildHero(DeviceState? device, String rtcDate, String rtcTime) {
    final score = _airScore(device);
    final isCompact = MediaQuery.sizeOf(context).width < 520;
    final hardwareLabel = device == null || device.hardwareId.isEmpty
        ? 'Hardware ID chưa liên kết'
        : device.hardwareId;

    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 18),
      decoration: glassPanelDecoration(
        colors: const [
          Color(0xFF183D68),
          Color(0xFF121D39),
          Color(0xFF140F26),
        ],
        radius: 28,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: isCompact ? 48 : 52,
                height: isCompact ? 48 : 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [
                      AppPalette.cyan,
                      AppPalette.blue,
                      AppPalette.violet,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.sensors_rounded,
                  color: Colors.white,
                  size: isCompact ? 24 : 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device?.name ?? 'ESP32 Device',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isCompact ? 20 : 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hardwareLabel,
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 12,
                  vertical: isCompact ? 7 : 8,
                ),
                decoration: BoxDecoration(
                  color: (device?.isOnline ?? false)
                      ? AppPalette.success.withValues(alpha: 0.16)
                      : AppPalette.danger.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  (device?.isOnline ?? false) ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    color: (device?.isOnline ?? false)
                        ? AppPalette.success
                        : AppPalette.danger,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 340;
              final ringSize = constraints.maxWidth < 420
                  ? 138.0
                  : constraints.maxWidth < 640
                      ? 162.0
                      : constraints.maxWidth < 960
                          ? 190.0
                          : 240.0;
              final infoSpacing = constraints.maxWidth < 420 ? 12.0 : 16.0;
              final heroInfo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MetricHeadline(
                    title: 'Giờ ứng dụng',
                    value: '$_appTimeText | $_appDateText',
                  ),
                  SizedBox(height: infoSpacing),
                  MetricHeadline(
                    title: 'RTC trên board',
                    value: '$rtcTime | $rtcDate',
                  ),
                  SizedBox(height: infoSpacing),
                  MetricHeadline(
                    title: 'Chủ sở hữu',
                    value: device == null || device.ownerUsername.isEmpty
                        ? 'Chưa có owner'
                        : device.ownerUsername,
                  ),
                ],
              );
              final heroRing = SizedBox(
                width: sideBySide ? ringSize : double.infinity,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: ScoreRingPainter(score: score),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$score',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ringSize < 150 ? 36 : 48,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Chỉ số không khí',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: ringSize < 150 ? 13 : 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              if (!sideBySide) {
                return Column(
                  children: [
                    heroRing,
                    SizedBox(height: infoSpacing),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: heroInfo,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heroRing,
                  SizedBox(width: infoSpacing),
                  Expanded(child: heroInfo),
                ],
              );
              return Flex(
                direction: sideBySide ? Axis.horizontal : Axis.vertical,
                crossAxisAlignment: sideBySide
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: sideBySide ? ringSize : double.infinity,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: CustomPaint(
                        painter: ScoreRingPainter(score: score),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$score',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: ringSize < 150 ? 36 : 48,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                'Chỉ số không khí',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.68),
                                  fontSize: ringSize < 150 ? 13 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: sideBySide ? infoSpacing : 0,
                    height: sideBySide ? 0 : infoSpacing,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MetricHeadline(
                          title: 'Giờ ứng dụng',
                          value: '$_appTimeText | $_appDateText',
                        ),
                        SizedBox(height: infoSpacing),
                        MetricHeadline(
                          title: 'RTC trên board',
                          value: '$rtcTime | $rtcDate',
                        ),
                        const SizedBox(height: 18),
                        MetricHeadline(
                          title: 'Chủ sở hữu',
                          value: device == null || device.ownerUsername.isEmpty
                              ? 'Chưa có owner'
                              : device.ownerUsername,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSection(DeviceState? device) {
    final metrics = _metrics(device);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'Thẻ cảm biến',
          subtitle: 'Chạm vào từng thông số để xem biểu đồ màu và cường độ.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: metrics.map((metric) {
            final selected = metric.telemetryKey == _selectedMetricKey;
            final progress = metric.safeUpperBound <= 0
                ? 0.0
                : (metric.value / metric.safeUpperBound).clamp(0.0, 1.0);
            final width = MediaQuery.sizeOf(context).width < 760
                ? double.infinity
                : (MediaQuery.sizeOf(context).width - 52) / 2;
            return SizedBox(
              width: width,
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedMetricKey = metric.telemetryKey);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MetricDetailPage(
                        deviceName: device?.name ?? 'ESP32 Device',
                        rtcDate: _liveRtcDateText == '--/--/----'
                            ? (device?.rtcDateText ?? '--/--/----')
                            : _liveRtcDateText,
                        metric: metric,
                        entries: _entries,
                      ),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  padding: const EdgeInsets.all(16),
                  decoration: glassPanelDecoration(
                    colors: [
                      metric.color.withValues(alpha: selected ? 0.32 : 0.18),
                      const Color(0xE613223A),
                      const Color(0xE60A1324),
                    ],
                    radius: 24,
                    borderColor: selected
                        ? metric.color.withValues(alpha: 0.38)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: metric.color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(metric.icon, color: metric.color),
                          ),
                          const Spacer(),
                          Text(
                            '${(progress * 100).round()}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        metric.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            metric.displayValue,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              metric.unit,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: progress,
                          backgroundColor: Colors.white.withValues(alpha: 0.08),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(metric.color),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Chạm để xem biểu đồ chi tiết',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRelaySection(DeviceState? device) {
    final buzzerOn = device?.buzzerOn ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'Điều khiển relay',
          subtitle:
              'App chỉ điều khiển 3 relay. Buzzer trên board tự động bật khi vượt ngưỡng cảnh báo.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            PillInfo(
              label: 'Mode',
              value: _controlMode.toUpperCase(),
              accent:
                  _controlMode == 'auto' ? AppPalette.cyan : AppPalette.amber,
            ),
            PillInfo(
              label: 'Buzzer',
              value: buzzerOn ? 'Đang cảnh báo' : 'Tự động',
              accent: buzzerOn ? AppPalette.amber : AppPalette.mint,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _buildRelayCard(
              title: 'Relay 1',
              subtitle: 'Ngưỡng nhiệt độ',
              icon: Icons.air_rounded,
              isOn: device?.relay1On ?? false,
              activeColor: AppPalette.cyan,
              onChanged: () => _updateRelay(
                relay1: !(device?.relay1On ?? false),
              ),
            ),
            _buildRelayCard(
              title: 'Relay 2',
              subtitle: 'Ngưỡng độ ẩm',
              icon: Icons.notifications_active_rounded,
              isOn: device?.relay2On ?? false,
              activeColor: AppPalette.coral,
              onChanged: () => _updateRelay(
                relay2: !(device?.relay2On ?? false),
              ),
            ),
            _buildRelayCard(
              title: 'Relay 3',
              subtitle: 'Ngưỡng CO / NO2',
              icon: Icons.lightbulb_rounded,
              isOn: device?.relay3On ?? false,
              activeColor: AppPalette.violet,
              onChanged: () => _updateRelay(
                relay3: !(device?.relay3On ?? false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelayCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isOn,
    required Color activeColor,
    VoidCallback? onChanged,
    bool enabled = true,
  }) {
    final isCompact = MediaQuery.sizeOf(context).width < 760;
    final width = isCompact
        ? double.infinity
        : (MediaQuery.sizeOf(context).width - 56) / 3;
    final manualEnabled =
        enabled && _controlMode == 'manual' && onChanged != null;
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: manualEnabled ? onChanged : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          padding: EdgeInsets.all(isCompact ? 16 : 18),
          decoration: glassPanelDecoration(
            colors: isOn
                ? [
                    activeColor.withValues(alpha: 0.38),
                    activeColor.withValues(alpha: 0.18),
                    const Color(0xE6132035),
                  ]
                : [
                    const Color(0xE614223A),
                    const Color(0xE60A1324),
                  ],
            radius: isCompact ? 24 : 28,
            borderColor: isOn
                ? activeColor.withValues(alpha: 0.42)
                : Colors.white.withValues(alpha: 0.08),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: isCompact ? 42 : 48,
                    height: isCompact ? 42 : 48,
                    decoration: BoxDecoration(
                      color: isOn
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
                    ),
                    child: Icon(icon, color: isOn ? Colors.white : activeColor),
                  ),
                  const Spacer(),
                  Switch(
                    value: isOn,
                    onChanged: manualEnabled ? (_) => onChanged!() : null,
                    activeColor: Colors.white,
                    activeTrackColor: activeColor,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 14 : 18),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 18 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
              ),
              SizedBox(height: isCompact ? 14 : 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isOn
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  manualEnabled
                      ? (isOn ? 'Đang bật' : 'Đang tắt')
                      : enabled
                          ? 'Auto control'
                          : (isOn ? 'Đang cảnh báo' : 'Bình thường'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertPageVi(DeviceState? device) {
    final notices = _buildNoticesVi(device);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle(
          title: 'Thông báo & cảnh báo',
          subtitle: 'Tổng hợp các trạng thái quan trọng của board.',
        ),
        const SizedBox(height: 18),
        ...notices.map((notice) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: glassPanelDecoration(
              colors: [
                notice.color.withValues(alpha: 0.18),
                const Color(0xE6132138),
              ],
              radius: 26,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: notice.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(notice.icon, color: notice.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice.message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<_NoticeItem> _buildNoticesVi(DeviceState? device) {
    if (device == null) {
      return const [
        _NoticeItem(
          title: 'Đang tải dữ liệu',
          message: 'Thông tin board sẽ hiện sau khi backend trả dữ liệu.',
          color: AppPalette.cyan,
          icon: Icons.hourglass_top_rounded,
        ),
      ];
    }

    final notices = <_NoticeItem>[
      _NoticeItem(
        title: device.isOnline ? 'Board đang online' : 'Board đang offline',
        message: device.isOnline
            ? 'ESP32 đang gửi dữ liệu và có thể nhận lệnh relay hoặc đồng bộ RTC.'
            : 'Chưa nhận dữ liệu mới từ board. Hãy kiểm tra WiFi, backend bridge hoặc liên kết MAC.',
        color: device.isOnline ? AppPalette.success : AppPalette.danger,
        icon: device.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
      ),
    ];

    for (final metric in _metrics(device)) {
      final ratio = metric.safeUpperBound <= 0
          ? 0.0
          : metric.value / metric.safeUpperBound;
      if (ratio >= 1) {
        notices.add(
          _NoticeItem(
            title: '${metric.title} vượt ngưỡng',
            message:
                'Giá trị ${metric.displayValue} ${metric.unit} đã vượt mức tham chiếu ${metric.safeUpperBound.toStringAsFixed(metric.decimals)} ${metric.unit}.',
            color: AppPalette.danger,
            icon: metric.icon,
          ),
        );
      }
    }

    if (notices.length == 1) {
      notices.add(
        const _NoticeItem(
          title: 'Hệ thống ổn định',
          message:
              'Chưa phát hiện cảm biến nào vượt ngưỡng trong phiên hiện tại.',
          color: AppPalette.mint,
          icon: Icons.verified_rounded,
        ),
      );
    }

    return notices;
  }

  Widget _buildAnalyticsPreview(DeviceState? device) {
    final metric = _selectedMetric;
    final points = buildHourlySeries(_entries, metric.telemetryKey);
    final peak = points.fold<double>(
      0.0,
      (maxValue, point) => point.value > maxValue ? point.value : maxValue,
    );
    final progress = metric.safeUpperBound <= 0
        ? 0.0
        : (metric.value / metric.safeUpperBound).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 920;
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: glassPanelDecoration(radius: 32),
          child: Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      title: 'Analytics preview',
                      subtitle: 'Metric dang duoc nhan manh: ${metric.title}.',
                      trailing: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MetricDetailPage(
                                deviceName: device?.name ?? 'ESP32 Device',
                                rtcDate: _liveRtcDateText == '--/--/----'
                                    ? (device?.rtcDateText ?? '--/--/----')
                                    : _liveRtcDateText,
                                metric: metric,
                                entries: _entries,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Mo full view'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 260,
                      child: CustomPaint(
                        painter: LineChartPainter(
                          points: points,
                          color: metric.color,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        PillInfo(
                          label: 'Hien tai',
                          value: '${metric.displayValue} ${metric.unit}',
                          accent: metric.color,
                        ),
                        PillInfo(
                          label: 'Cao nhat',
                          value:
                              '${peak.toStringAsFixed(metric.decimals)} ${metric.unit}',
                          accent: AppPalette.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: stacked ? 0 : 18, height: stacked ? 18 : 0),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    IntensityRing(
                      progress: progress,
                      label: '${metric.title} intensity',
                      valueLabel: '${(progress * 100).round()}%',
                      color: metric.color,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nhan xet nhanh',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            progress >= 0.85
                                ? '${metric.title} dang gan vuot nguong, nen mo detail chart de theo doi them.'
                                : '${metric.title} dang o muc on dinh, card mau va vong intensity dang giup nhin nhanh hon.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertPage(DeviceState? device) {
    final notices = _buildNotices(device);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle(
          title: 'Thông báo & cảnh báo',
          subtitle:
              'Tổng hợp các trạng thái quan trọng của board và telemetry.',
        ),
        const SizedBox(height: 18),
        ...notices.map((notice) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: glassPanelDecoration(
              colors: [
                notice.color.withValues(alpha: 0.18),
                const Color(0xE6132138),
              ],
              radius: 26,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: notice.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(notice.icon, color: notice.color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notice.message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<_NoticeItem> _buildNotices(DeviceState? device) {
    if (device == null) {
      return const [
        _NoticeItem(
          title: 'Đang tải dữ liệu',
          message: 'Thông tin board sẽ hiện sau khi backend trả dữ liệu.',
          color: AppPalette.cyan,
          icon: Icons.hourglass_top_rounded,
        ),
      ];
    }

    final notices = <_NoticeItem>[
      _NoticeItem(
        title: device.isOnline ? 'Board đang online' : 'Board đang offline',
        message: device.isOnline
            ? 'ESP32 đang gửi dữ liệu và có thể nhận lệnh relay hoặc đồng bộ RTC.'
            : 'Chưa nhận dữ liệu mới từ board. Hãy kiểm tra WiFi, backend bridge hoặc liên kết MAC.',
        color: device.isOnline ? AppPalette.success : AppPalette.danger,
        icon: device.isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
      ),
    ];

    for (final metric in _metrics(device)) {
      final ratio = metric.safeUpperBound <= 0
          ? 0.0
          : metric.value / metric.safeUpperBound;
      if (ratio >= 1) {
        notices.add(
          _NoticeItem(
            title: '${metric.title} vượt ngưỡng',
            message:
                'Giá trị ${metric.displayValue} ${metric.unit} đã vượt mức tham chiếu ${metric.safeUpperBound.toStringAsFixed(metric.decimals)} ${metric.unit}.',
            color: AppPalette.danger,
            icon: metric.icon,
          ),
        );
      }
    }

    if (notices.length == 1) {
      notices.add(
        const _NoticeItem(
          title: 'Hệ thống ổn định',
          message:
              'Chưa phát hiện cảm biến nào vượt ngưỡng trong phiên hiện tại.',
          color: AppPalette.mint,
          icon: Icons.verified_rounded,
        ),
      );
    }

    return notices;
  }

  Widget _buildSettingsPage(
      DeviceState? device, String rtcDate, String rtcTime) {
    final selectedRtc = _selectedRtcDateTime ?? DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle(
          title: 'Cài đặt',
          subtitle:
              'App hiển thị theo giờ máy. Board ESP32 giữ giờ bằng DS3231 và sẽ tự động đồng bộ NTP khi có WiFi.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: glassPanelDecoration(
            colors: const [
              Color(0xFF1B3F6A),
              Color(0xFF121D39),
              Color(0xFF0D1528),
            ],
            radius: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppPalette.cyan.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: AppPalette.cyan,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RTC sync for ESP32',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Chọn ngày giờ tháng năm và gửi lệnh đồng bộ trực tiếp cho board.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Khuyến nghị: app dùng giờ hệ thống của điện thoại hoặc máy tính, còn board sẽ giữ DS3231 để chạy ổn định khi mất mạng và tự lấy lại NTP khi WiFi hoạt động.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  PillInfo(
                    label: 'App hiện tại',
                    value: '$_appTimeText | $_appDateText',
                    accent: AppPalette.mint,
                  ),
                  PillInfo(
                    label: 'RTC trên board',
                    value: '$rtcTime | $rtcDate',
                    accent: AppPalette.cyan,
                  ),
                  PillInfo(
                    label: 'Giờ chờ đồng bộ',
                    value:
                        '${_formatDate(selectedRtc)} | ${_formatTime(selectedRtc)}',
                    accent: AppPalette.violet,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _settingActionChip(
                    icon: Icons.calendar_month_rounded,
                    label: _formatDate(selectedRtc),
                    onTap: _pickRtcDate,
                  ),
                  _settingActionChip(
                    icon: Icons.access_time_rounded,
                    label: _formatTime(selectedRtc),
                    onTap: _pickRtcTime,
                  ),
                  _settingActionChip(
                    icon: Icons.bolt_rounded,
                    label: 'Lấy giờ máy',
                    onTap: _useCurrentSystemTime,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _syncingRtc ? null : _syncRtcWithBoard,
                  icon: const Icon(Icons.cloud_sync_rounded),
                  label: Text(
                    _syncingRtc
                        ? 'Đang gửi lệnh sync...'
                        : 'Đồng bộ thời gian cho ESP32',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: glassPanelDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'Chế độ điều khiển',
                subtitle:
                    '<Auto tự điều khiển theo ngưỡng>__<Manual cho phép bật tắt bằng tay>',
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'manual',
                    icon: Icon(Icons.tune_rounded),
                    label: Text('Manual'),
                  ),
                  ButtonSegment<String>(
                    value: 'auto',
                    icon: Icon(Icons.auto_mode_rounded),
                    label: Text('Auto'),
                  ),
                ],
                selected: <String>{_controlMode},
                onSelectionChanged: (values) {
                  if (values.isNotEmpty) {
                    _setControlMode(values.first);
                  }
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveAutomation,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Lưu chế độ manual và automation'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: glassPanelDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'Ngưỡng tự động',
              ),
              const SizedBox(height: 18),
              _buildOutputAutomationCard(
                title: 'Relay 1',
                subtitle: 'Tự động theo nhiệt độ',
                color: AppPalette.cyan,
                outputKey: 'relay1',
                sliders: [
                  _AutomationSliderSpec(
                    label: 'Nhiet do',
                    fieldKey: 'threshold',
                    min: 0,
                    max: 80,
                    color: AppPalette.cyan,
                    suffix: 'C',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildOutputAutomationCard(
                title: 'Relay 2',
                subtitle: 'Tự động theo độ ẩm',
                color: AppPalette.coral,
                outputKey: 'relay2',
                sliders: [
                  _AutomationSliderSpec(
                    label: 'Do am',
                    fieldKey: 'threshold',
                    min: 0,
                    max: 100,
                    color: AppPalette.coral,
                    suffix: '%',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildOutputAutomationCard(
                title: 'Relay 3',
                subtitle: 'Tự động theo CO / NO2',
                color: AppPalette.violet,
                outputKey: 'relay3',
                sliders: [
                  _AutomationSliderSpec(
                    label: 'CO',
                    fieldKey: 'coThreshold',
                    min: 0,
                    max: 1000,
                    color: AppPalette.violet,
                    suffix: 'ppm',
                  ),
                  _AutomationSliderSpec(
                    label: 'NO2',
                    fieldKey: 'no2Threshold',
                    min: 0,
                    max: 15,
                    color: AppPalette.violet,
                    suffix: 'ppm',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: glassPanelDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'Thông tin phần cứng',
                subtitle:
                    'MAC đang liên kết với board. Có thể đổi MAC hoặc gỡ liên kết tại đây.',
              ),
              const SizedBox(height: 16),
              _infoRow('Device ID', device?.id ?? '--'),
              _infoRow('Loại', device?.type ?? '--'),
              _infoRow(
                'MAC / Hardware',
                device == null || device.hardwareId.isEmpty
                    ? '--'
                    : device.hardwareId,
              ),
              _infoRow('Lần cuối online', device?.lastSeen ?? '--'),
              const SizedBox(height: 12),
              TextField(
                controller: _hardwareIdController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'MAC / Hardware ID',
                  hintText: 'VD: F0:24:F9:EB:6D:94',
                ),
                onChanged: (_) {
                  if (_hasPendingHardwareIdEdit) {
                    return;
                  }
                  setState(() => _hasPendingHardwareIdEdit = true);
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: _savingHardwareId ? null : _saveHardwareId,
                    icon: const Icon(Icons.link_rounded),
                    label: Text(
                      _savingHardwareId ? 'Đang lưu...' : 'Lưu MAC',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        _savingHardwareId ? null : () => _clearHardwareId(),
                    icon: const Icon(Icons.link_off_rounded),
                    label: const Text('Gỡ liên kết'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppPalette.cyan, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserPage(DeviceState? device) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: glassPanelDecoration(
            colors: const [
              Color(0xFF183F6B),
              Color(0xFF101C37),
              Color(0xFF140F26),
            ],
            radius: 32,
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [AppPalette.cyan, AppPalette.blue],
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.user.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Role: ${widget.session.user.role}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: glassPanelDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'Tài khoản',
                subtitle: 'Thông tin session hiện tại và board đang xem.',
              ),
              const SizedBox(height: 16),
              _infoRow('Ngày tạo', widget.session.user.createdAt),
              _infoRow(
                'Trạng thái',
                widget.session.user.isActive ? 'Active' : 'Inactive',
              ),
              _infoRow('Chủ thiết bị', device?.ownerUsername ?? '--'),
              _infoRow(
                'Thiết bị online',
                (device?.isOnline ?? false) ? 'Yes' : 'No',
              ),
              if (widget.onLogout != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _loggingOutFromDevice ? null : _logoutFromCurrentDevice,
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      _loggingOutFromDevice
                          ? 'Dang xu ly dang xuat...'
                          : 'Đăng xuất khỏi board này',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Khi đăng xuất, app sẽ gỡ liên kết MAC của board hiện tại. Lần sau đăng nhập cần nhập lại MAC để kết nối.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputAutomationCard({
    required String title,
    required String subtitle,
    required Color color,
    required String outputKey,
    required List<_AutomationSliderSpec> sliders,
  }) {
    final config = _ensureConfig(outputKey);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
          ),
          const SizedBox(height: 12),
          ...sliders.map((slider) {
            final currentValue = _clampDouble(
              config[slider.fieldKey],
              min: slider.min,
              max: slider.max,
              fallback: slider.min,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${slider.label}: ${currentValue.toStringAsFixed(slider.max <= 10 ? 1 : 0)} ${slider.suffix}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Slider(
                  value: currentValue,
                  min: slider.min,
                  max: slider.max,
                  activeColor: slider.color,
                  inactiveColor: Colors.white.withValues(alpha: 0.12),
                  onChanged: (value) {
                    _updateAutomationValue(outputKey, slider.fieldKey, value);
                  },
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final items = const [
      _NavItem(icon: Icons.home_rounded, label: 'Trang chủ'),
      _NavItem(icon: Icons.notifications_rounded, label: 'Cảnh báo'),
      _NavItem(icon: Icons.settings_rounded, label: 'Cài đặt'),
      _NavItem(icon: Icons.person_rounded, label: 'Tài khoản'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: glassPanelDecoration(
          colors: const [Color(0xEE111C34), Color(0xEE0A1324)],
          radius: 20,
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == _currentIndex;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => setState(() => _currentIndex = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? const LinearGradient(
                            colors: [AppPalette.cyan, AppPalette.blue],
                          )
                        : null,
                    color: selected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: selected ? AppPalette.midnight : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          color:
                              selected ? AppPalette.midnight : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NoticeItem {
  const _NoticeItem({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _AutomationSliderSpec {
  const _AutomationSliderSpec({
    required this.label,
    required this.fieldKey,
    required this.min,
    required this.max,
    required this.color,
    required this.suffix,
  });

  final String label;
  final String fieldKey;
  final double min;
  final double max;
  final Color color;
  final String suffix;
}
