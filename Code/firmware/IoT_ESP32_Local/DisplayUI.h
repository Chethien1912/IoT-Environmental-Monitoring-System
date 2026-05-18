#ifndef DISPLAY_UI_H
#define DISPLAY_UI_H

#include <TFT_eSPI.h>
#include <XPT2046_Touchscreen.h>
#include "DeviceState.h"

struct MetricHistory {
  static constexpr uint8_t kMaxPoints = 36;
  float values[kMaxPoints] = {};
  uint8_t count = 0;
};

struct TimeEditState {
  int day    = 1;
  int month  = 1;
  int year   = 2024;
  int hour   = 0;
  int minute = 0;
  int second = 0;
};

enum class MetricType : uint8_t {
  Temperature = 0,
  Humidity    = 1,
  Co          = 2,
  No2         = 3,
  Count       = 4
};

struct ThresholdEditState {
  MetricType metric = MetricType::Temperature;
  float value       = 35.0f;
  float step        = 0.5f;
  float minValue    = 0.0f;
  float maxValue    = 100.0f;
  String title      = "NGUONG";
  String unit       = "C";
  unsigned int decimals = 1;
};

class DisplayUI {
 public:
  DisplayUI(TFT_eSPI* tft, XPT2046_Touchscreen* touch);

  void begin();
  void update();
  void invalidate();//ép UI vẽ lại toàn bộ ở lần update tiếp theo.

  void setState(const DeviceState& state);
  void setMetricHistory(MetricType metric, const MetricHistory& history);
  void setTimeEditState(const TimeEditState& state);
  void setThresholdEditState(const ThresholdEditState& state);

  bool consumeRelayToggle(uint8_t& relayIndex); // báo người dùng vừa bấm relay nào
  bool consumeModeToggle(); // báo người dùng vừa bấm đổi chế độ Auto/Manual.
  bool consumeWifiDisconnect(); // báo người dùng bấm ngắt WiFi.

  bool consumeTimeAdjust(int& fieldIndex, int& delta); // báo người dùng bấm + hoặc - ở trường ngày/tháng/năm/giờ/phút/giây.
  bool consumeTimeSave(); // báo người dùng bấm nút [Cai gio] để lưu thời gian đã chỉnh.

  bool consumeThresholdOpen(MetricType& metric); // báo người dùng bấm nút [NGUONG] trên card cảm biến nào, để mở cài đặt ngưỡng tương ứng.
  bool consumeThresholdAdjust(int& delta); // báo người dùng bấm + hoặc - để chỉnh ngưỡng, chỉ valid khi đang mở cài đặt ngưỡng.
  bool consumeThresholdSave(); // báo người dùng bấm nút [Luu] để lưu ngưỡng đã chỉnh, chỉ valid khi đang mở cài đặt ngưỡng.

  bool consumeBack(); // báo người dùng bấm nút [<] để quay
  bool isTimeSettingsOpen() const;

 private:
  enum class Screen : uint8_t {
    Dashboard, // màn hình chính.
    TimeSettings, //màn hình cài đặt thời gian.
    ThresholdSettings // màn hình cài đặt ngưỡng.
  };

  TFT_eSPI*            _tft;
  XPT2046_Touchscreen* _touch;
  uint16_t relayColor(uint8_t idx) const;
  DeviceState        _state;
  DeviceState        _prev;
  MetricHistory      _history[static_cast<uint8_t>(MetricType::Count)];
  TimeEditState      _timeEdit;
  TimeEditState      _prevTimeEdit;
  ThresholdEditState _thresholdEdit;
  ThresholdEditState _prevThresholdEdit;

  Screen _screen = Screen::Dashboard;

  bool _layoutDirty = true;
  unsigned long _lastDraw  = 0;
  unsigned long _lastTouch = 0;
  bool _held = false;

  int  _pendingRelay = -1;
  bool _pendingMode = false;
  bool _pendingWifiDisconnect = false;

  int  _pendingAdjField = -1;
  int  _pendingAdjDelta = 0;
  bool _pendingTimeSave = false;

  int  _pendingThresholdOpen = -1;
  int  _pendingThresholdDelta = 0;
  bool _pendingThresholdSave = false;

  bool _pendingBack = false;

  void drawDashboard(bool force);
  void drawHeader(bool force);
  void drawSensorRow(bool force);
  void drawRelayRow(bool force);
  void drawModeButton(bool force);

  void drawTimeSettings(bool force);
  void drawTimeField(int x, int y, int w, int h,
                     const char* label, int value, bool force);

  void drawThresholdSettings(bool force);

  void handleTouch();
  bool hitTest(int tx, int ty, int x, int y, int w, int h) const;
};

#endif
