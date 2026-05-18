import 'package:flutter/material.dart';

class RelayCard extends StatelessWidget {
  const RelayCard({
    super.key,
    required this.label,
    required this.desiredOn,
    required this.actualOn,
    required this.accentColor,
    required this.onChanged,
  });

  final String label;
  final bool desiredOn;
  final bool actualOn;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isSynced = desiredOn == actualOn;
    final bool isOn = actualOn;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOn
              ? [
                  accentColor.withValues(alpha: 0.18),
                  accentColor.withValues(alpha: 0.08),
                ]
              : const [
                  Color(0xFFFFFCF4),
                  Color(0xFFF3EEE3),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentColor.withValues(alpha: isOn ? 0.42 : 0.18)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isOn ? 0.14 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isOn ? accentColor : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isOn ? Icons.flash_on_rounded : Icons.power_settings_new_rounded,
              color: isOn ? Colors.white : accentColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isSynced
                      ? (isOn
                          ? 'Trang thai that tren TFT: dang bat'
                          : 'Trang thai that tren TFT: dang tat')
                      : 'Dang cho ESP32 va TFT ap dung lenh moi',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSynced
                        ? (isOn
                            ? accentColor.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.05))
                        : const Color(0xFFEFBF4A).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isSynced ? (isOn ? 'TFT ON' : 'TFT OFF') : 'DANG DONG BO',
                    style: TextStyle(
                      color: isSynced
                          ? (isOn ? accentColor : Colors.black87)
                          : const Color(0xFF9A6700),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lenh tren app: ${desiredOn ? 'BAT' : 'TAT'}',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Trang thai thuc te: ${actualOn ? 'BAT' : 'TAT'}',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: desiredOn,
            activeColor: accentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
