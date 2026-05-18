import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/device_summary.dart';
import '../services/api_client.dart';
import '../widgets/dashboard_chrome.dart';
import 'device_detail_page.dart';
import 'user_management_page.dart';

class DeviceListPage extends StatefulWidget {
  const DeviceListPage({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
  });

  final ApiClient api;
  final AuthSession session;
  final Future<void> Function() onLogout;

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  final _name = TextEditingController();
  final _type = TextEditingController(text: 'esp32');
  final _hardwareId = TextEditingController();

  List<DeviceSummary> _devices = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _hardwareId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final devices = await widget.api.fetchDevices();
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = devices;
        _loading = false;
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

  Future<void> _showCreateDeviceDialog() async {
    _name.clear();
    _type.text = 'esp32';
    _hardwareId.clear();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Tạo thiết bị mới',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên thiết bị'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _type,
              decoration: const InputDecoration(labelText: 'Loại thiết bị'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hardwareId,
              decoration: const InputDecoration(
                labelText: 'Hardware ID / MAC (tùy chọn)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final result = await widget.api.addDevice(
                  name: _name.text.trim(),
                  type: _type.text.trim().isEmpty ? 'esp32' : _type.text.trim(),
                  hardwareId: _hardwareId.text.trim(),
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                await _load();
                if (!context.mounted) {
                  return;
                }
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text(
                      'Thông tin firmware',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: SelectableText(
                      'Device ID: ${result['id']}\n'
                      'Device Secret: ${result['deviceSecret']}\n'
                      'Hardware ID: ${result['hardwareId'] ?? ''}\n\n'
                      'Liên kết Hardware ID với MAC ESP32 và nhập Backend URL trong portal WiFi của board để bắt đầu đồng bộ.',
                      style: const TextStyle(color: Colors.white),
                    ),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Đóng'),
                      ),
                    ],
                  ),
                );
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error.toString().replaceFirst('Exception: ', '')),
                  ),
                );
              }
            },
            child: const Text('Tạo thiết bị'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 760;
    final pagePadding = isCompact ? 14.0 : 18.0;
    final cardWidth = isCompact ? double.infinity : (screenWidth - pagePadding * 2 - 16) / 2;
    final onlineCount = _devices.where((device) => device.isOnline).length;

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.all(pagePadding),
              children: [
                ShellHero(
                  title: 'IoTapp',
                  subtitle: '${widget.session.user.username} | ${widget.session.user.role}',
                  badges: [
                    '${_devices.length} thiết bị',
                    '$onlineCount đang online',
                  ],
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppPalette.cyan, AppPalette.blue],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          onPressed: () => widget.onLogout(),
                          icon: const Icon(Icons.logout_rounded, color: AppPalette.midnight),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 16 : 22),
                SectionTitle(
                  title: 'Danh sách thiết bị',
                  trailing: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (widget.session.user.role == 'admin')
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserManagementPage(
                                  api: widget.api,
                                  session: widget.session,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.manage_accounts_rounded),
                          label: const Text('Người dùng'),
                        ),
                      FilledButton.icon(
                        onPressed: _showCreateDeviceDialog,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Thêm thiết bị'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _MessagePanel(message: _error!, isError: true)
                else if (_devices.isEmpty)
                  const _MessagePanel(
                    message: 'Chưa có thiết bị nào. Hãy thêm thiết bị để liên kết board ESP32.',
                  )
                else
                  Wrap(
                    spacing: isCompact ? 14 : 16,
                    runSpacing: isCompact ? 14 : 16,
                    children: _devices.map((device) {
                      return SizedBox(
                        width: cardWidth,
                        child: _DeviceShowcaseCard(
                          device: device,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeviceDetailPage(
                                  api: widget.api,
                                  session: widget.session,
                                  deviceId: device.id,
                                  onLogout: widget.onLogout,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceShowcaseCard extends StatelessWidget {
  const _DeviceShowcaseCard({
    required this.device,
    required this.onTap,
  });

  final DeviceSummary device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 620;
    final accent = device.isOnline ? AppPalette.cyan : AppPalette.danger;
    final end = device.isOnline ? AppPalette.blue : const Color(0xFF3A1A33);

    return InkWell(
      borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
      onTap: onTap,
      child: Ink(
        decoration: glassPanelDecoration(
          colors: [
            accent.withValues(alpha: 0.22),
            const Color(0xE6152239),
            end.withValues(alpha: 0.30),
          ],
          radius: isCompact ? 24 : 32,
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 18 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: isCompact ? 50 : 58,
                    height: isCompact ? 50 : 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isCompact ? 18 : 20),
                      gradient: LinearGradient(
                        colors: [accent, end],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.memory_rounded,
                      color: Colors.white,
                      size: isCompact ? 24 : 28,
                    ),
                  ),
                  SizedBox(width: isCompact ? 12 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isCompact ? 19 : 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          device.hardwareId.isEmpty ? 'Hardware chưa liên kết' : device.hardwareId,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.68)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 10 : 12,
                      vertical: isCompact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: device.isOnline
                          ? AppPalette.success.withValues(alpha: 0.15)
                          : AppPalette.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      device.isOnline ? 'ĐANG ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: device.isOnline ? AppPalette.success : AppPalette.danger,
                        fontWeight: FontWeight.w800,
                        fontSize: isCompact ? 11 : 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 16 : 20),
              Wrap(
                spacing: isCompact ? 10 : 12,
                runSpacing: isCompact ? 10 : 12,
                children: [
                  PillInfo(
                    label: 'Nhiệt độ',
                    value: '${device.temperatureC.toStringAsFixed(1)}°C',
                    accent: AppPalette.amber,
                  ),
                  PillInfo(
                    label: 'Độ ẩm',
                    value: '${device.humidityPercent.toStringAsFixed(1)} %',
                    accent: AppPalette.mint,
                  ),
                  PillInfo(
                    label: 'Chủ sở hữu',
                    value: device.ownerUsername.isEmpty ? '--' : device.ownerUsername,
                    accent: AppPalette.violet,
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 14 : 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Device ID: ${device.id}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppPalette.danger : AppPalette.cyan;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: glassPanelDecoration(
        colors: [
          color.withValues(alpha: 0.16),
          const Color(0xCC111C34),
        ],
        radius: 28,
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white, height: 1.5),
      ),
    );
  }
}
