import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/telemetry_entry.dart';
import '../widgets/dashboard_chrome.dart';

class MetricDescriptor {
  const MetricDescriptor({
    required this.title,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
    required this.telemetryKey,
    required this.decimals,
    required this.safeUpperBound,
  });

  final String title;
  final double value;
  final String unit;
  final Color color;
  final IconData icon;
  final String telemetryKey;
  final int decimals;
  final double safeUpperBound;

  String get displayValue => value.toStringAsFixed(decimals);
}

class MetricDetailPage extends StatelessWidget {
  const MetricDetailPage({
    super.key,
    required this.deviceName,
    required this.rtcDate,
    required this.metric,
    required this.entries,
  });

  final String deviceName;
  final String rtcDate;
  final MetricDescriptor metric;
  final List<TelemetryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final points = buildHourlySeries(entries, metric.telemetryKey);
    final peak = points.fold<double>(0.0, (maxValue, point) => math.max(maxValue, point.value));
    final average = points.isEmpty
        ? 0.0
        : points.map((point) => point.value).reduce((a, b) => a + b) / points.length;
    final intensity = metric.safeUpperBound <= 0
        ? 0.0
        : (metric.value / metric.safeUpperBound).clamp(0.0, 1.0);

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      metric.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: glassPanelDecoration(
                  colors: [
                    metric.color.withValues(alpha: 0.24),
                    const Color(0xE614223C),
                    const Color(0xE60D1528),
                  ],
                  radius: 34,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceName,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${metric.displayValue} ${metric.unit}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  height: 1.0,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Phân tích trong ngày $rtcDate',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: metric.color.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(metric.icon, color: metric.color, size: 34),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        PillInfo(
                          label: 'Hiện tại',
                          value: '${metric.displayValue} ${metric.unit}',
                          accent: metric.color,
                        ),
                        PillInfo(
                          label: 'Trung bình',
                          value: '${average.toStringAsFixed(1)} ${metric.unit}',
                          accent: AppPalette.cyan,
                        ),
                        PillInfo(
                          label: 'Cao nhất',
                          value: '${peak.toStringAsFixed(1)} ${metric.unit}',
                          accent: AppPalette.amber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 900;
                  return Flex(
                    direction: stacked ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: glassPanelDecoration(radius: 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionTitle(
                                title: 'Biểu đồ xu hướng',
                                subtitle: 'Điểm trung bình theo từng giờ trong ngày.',
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 320,
                                child: CustomPaint(
                                  painter: LineChartPainter(
                                    points: points,
                                    color: metric.color,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: stacked ? 0 : 18, height: stacked ? 18 : 0),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: glassPanelDecoration(radius: 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SectionTitle(
                                title: 'Cường độ',
                                subtitle:
                                    'So sánh với mức cảnh báo để người dùng nhìn nhanh.',
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: IntensityRing(
                                  progress: intensity,
                                  label: 'Cường độ hiện tại',
                                  valueLabel: '${(intensity * 100).round()}%',
                                  color: metric.color,
                                ),
                              ),
                              const SizedBox(height: 20),
                              PillInfo(
                                label: 'Mức tham chiếu',
                                value: '${metric.safeUpperBound.toStringAsFixed(metric.decimals)} ${metric.unit}',
                                accent: metric.color,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                intensity >= 0.85
                                    ? 'Chỉ số đang ở vùng cao, nên theo dõi sát.'
                                    : intensity >= 0.6
                                        ? 'Chỉ số đang trong vùng cần chú ý.'
                                        : 'Chỉ số hiện tại đang ở vùng ổn định.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  height: 1.55,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: glassPanelDecoration(radius: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      title: 'Chi tiết theo giờ',
                      subtitle: points.isEmpty
                          ? 'Hôm nay chưa có dữ liệu để hiển thị.'
                          : 'Danh sách từng mốc giờ và độ mạnh của dữ liệu.',
                    ),
                    const SizedBox(height: 16),
                    if (points.isEmpty)
                      Text(
                        'Chưa có dữ liệu cho chỉ số này trong hôm nay.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                      )
                    else
                      ...points.map((point) {
                        final progress = peak == 0 ? 0.0 : point.value / peak;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 54,
                                child: Text(
                                  point.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 10,
                                    value: progress,
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    valueColor: AlwaysStoppedAnimation<Color>(metric.color),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  point.value.toStringAsFixed(metric.decimals),
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
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<HourlyPoint> buildHourlySeries(List<TelemetryEntry> entries, String metricKey) {
  final buckets = <int, List<double>>{};
  for (final entry in entries) {
    final time = DateTime.tryParse(entry.receivedAt)?.toLocal();
    if (time == null) {
      continue;
    }
    final value = entry.metricValue(metricKey);
    buckets.putIfAbsent(time.hour, () => <double>[]).add(value);
  }

  final points = <HourlyPoint>[];
  final sortedEntries = buckets.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  for (final item in sortedEntries) {
    final values = item.value;
    if (values.isEmpty) {
      continue;
    }
    final average = values.reduce((a, b) => a + b) / values.length;
    points.add(HourlyPoint(label: '${item.key.toString().padLeft(2, '0')}:00', value: average));
  }
  return points;
}
