#ifndef DEVICE_STATE_H
#define DEVICE_STATE_H

#include <Arduino.h>

// Chế độ điều khiển relay
enum class ControlMode : uint8_t {
  Manual = 0,
  Auto   = 1
};

struct DeviceState {
  float temperatureC    = NAN;
  float humidityPercent = NAN;
  float coPpm           = NAN;
  float no2Ppm          = NAN;
  String dateText       = "--/--/----";
  String timeText       = "--:--:--";
  bool relay1On         = false;   // Relay 1 – nhiệt độ
  bool relay2On         = false;   // Relay 2 – độ ẩm
  bool relay3On         = false;   // Relay 3 – CO / NO2
  bool buzzerOn         = false;   // Còi cảnh báo
  bool wifiConnected    = false;   // WiFi online/offline
  ControlMode mode      = ControlMode::Manual;
};

#endif