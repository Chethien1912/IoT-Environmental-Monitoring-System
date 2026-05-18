#include "DisplayUI.h"

namespace {
constexpr uint16_t C_BG      = 0x0841;
constexpr uint16_t C_PANEL   = 0x10A2;
constexpr uint16_t C_LINE    = 0x39E7;
constexpr uint16_t C_TEMP    = 0xFB8C;
constexpr uint16_t C_HUMID   = 0x4E9F;
constexpr uint16_t C_CO      = 0xFFC0;
constexpr uint16_t C_NO2     = 0x07E0;

constexpr uint16_t C_WHITE   = 0xFFFF;
constexpr uint16_t C_BLACK   = 0xFFFF;
constexpr uint16_t C_GREY    = 0x7BEF;
constexpr uint16_t C_RED     = 0x07FF;
constexpr uint16_t C_BLUE    = 0xFFE0;
constexpr uint16_t C_YELLOW  = 0x001F;
constexpr uint16_t C_GREEN   = 0x07E0;
constexpr uint16_t C_CYAN    = 0xF800;  

constexpr uint16_t C_OFF_BG      = C_WHITE;
constexpr uint16_t C_OFF_TEXT    = C_GREY;
constexpr uint16_t C_OFF_BORDER  = C_BLACK;

constexpr uint16_t C_ON      = C_GREEN;
constexpr uint16_t C_AUTO    = C_CYAN;
constexpr uint16_t C_MANUAL  = C_GREY;

constexpr int TX_MIN = 200, TX_MAX = 3700;
constexpr int TY_MIN = 240, TY_MAX = 3800;
constexpr int SW = 320, SH = 240;

constexpr unsigned long DEBOUNCE_MS = 180;
}
// Đây là constructor của class DisplayUI, tức là hàm được chạy khi tạo một đối tượng DisplayUI
DisplayUI::DisplayUI(TFT_eSPI* tft, XPT2046_Touchscreen* touch)
    : _tft(tft), _touch(touch) {}
    //Chức năng của nó là nhận màn hình TFT và module cảm ứng từ bên ngoài, rồi lưu lại vào biến thành viên _tft và _touch để các hàm khác trong DisplayUI sử dụng.

void DisplayUI::begin() {
  _tft->init();
  _tft->setRotation(1);
  _tft->fillScreen(C_BG);
  _layoutDirty = true;
}

void DisplayUI::update() {
  handleTouch();

  if (millis() - _lastDraw < 80) return;

  const bool force = _layoutDirty;
  _layoutDirty = false;

  switch (_screen) {
    case Screen::Dashboard:         drawDashboard(force); break;
    case Screen::TimeSettings:      drawTimeSettings(force); break;
    case Screen::ThresholdSettings: drawThresholdSettings(force); break;
  }

  _prev = _state;
  _prevTimeEdit = _timeEdit;
  _prevThresholdEdit = _thresholdEdit;
  _lastDraw = millis();
}

void DisplayUI::invalidate() { _layoutDirty = true; }

void DisplayUI::setState(const DeviceState& state) { _state = state; } // Hàm này dùng để cập nhật trạng thái thiết bị mới cho giao diện. Nói đơn giản: nó nhận một biến DeviceState từ bên ngoài, rồi copy vào biến _state bên trong class DisplayUI.
void DisplayUI::setMetricHistory(MetricType metric, const MetricHistory& history) {
  _history[static_cast<uint8_t>(metric)] = history;
}
void DisplayUI::setTimeEditState(const TimeEditState& state) { _timeEdit = state; }
void DisplayUI::setThresholdEditState(const ThresholdEditState& state) { _thresholdEdit = state; }

bool DisplayUI::consumeRelayToggle(uint8_t& relayIndex) {
  if (_pendingRelay < 0) return false;
  relayIndex = static_cast<uint8_t>(_pendingRelay);
  _pendingRelay = -1;
  return true;
}

bool DisplayUI::consumeModeToggle() {
  if (!_pendingMode) return false;
  _pendingMode = false;
  return true;
}

bool DisplayUI::consumeWifiDisconnect() {
  if (!_pendingWifiDisconnect) return false;
  _pendingWifiDisconnect = false;
  return true;
}

bool DisplayUI::consumeTimeAdjust(int& fieldIndex, int& delta) {
  if (_pendingAdjField < 0) return false;
  fieldIndex = _pendingAdjField;
  delta      = _pendingAdjDelta;
  _pendingAdjField = -1;
  _pendingAdjDelta = 0;
  return true;
}

bool DisplayUI::consumeTimeSave() {
  if (!_pendingTimeSave) return false;
  _pendingTimeSave = false;
  return true;
}

bool DisplayUI::consumeThresholdOpen(MetricType& metric) {
  if (_pendingThresholdOpen < 0) return false;
  metric = static_cast<MetricType>(_pendingThresholdOpen);
  _pendingThresholdOpen = -1;
  return true;
}

bool DisplayUI::consumeThresholdAdjust(int& delta) {
  if (_pendingThresholdDelta == 0) return false;
  delta = _pendingThresholdDelta;
  _pendingThresholdDelta = 0;
  return true;
}

bool DisplayUI::consumeThresholdSave() {
  if (!_pendingThresholdSave) return false;
  _pendingThresholdSave = false;
  return true;
}

bool DisplayUI::consumeBack() {
  if (!_pendingBack) return false;
  _pendingBack = false;
  return true;
}

bool DisplayUI::isTimeSettingsOpen() const {
  return _screen == Screen::TimeSettings;
}

void DisplayUI::drawDashboard(bool force) {
  if (force) _tft->fillScreen(C_BG);
  drawHeader(force); // tiêu đề, WiFi, giờ/ngày, nút cài giờ
  drawSensorRow(force); // nhiệt độ, độ ẩm, CO, NO2.
  drawRelayRow(force); // trạng thái relay 1/2/3 và buzzer.
  drawModeButton(force); // nút hiển thị chế độ Auto/Manual, bấm vào để đổi chế độ.
}

void DisplayUI::drawHeader(bool force) {
  const bool timeChanged = (_state.timeText != _prev.timeText);
  const bool dateChanged = (_state.dateText != _prev.dateText);
  const bool wifiChanged = (_state.wifiConnected != _prev.wifiConnected);

  if (!force && !timeChanged && !dateChanged && !wifiChanged) return;

  if (force) {
    _tft->fillRect(0, 0, SW, 38, C_PANEL);
    _tft->drawFastHLine(0, 38, SW, C_LINE);

    // vùng trái: title + online/offline
    _tft->fillRect(0, 0, 110, 38, C_PANEL);

    // vùng giữa: giờ/ngày, tránh đè nút [Cai gio]
    _tft->fillRect(112, 2, 120, 36, C_PANEL);

    // nút cài giờ
    _tft->setTextDatum(MR_DATUM);
    _tft->setTextColor(C_BLACK, C_PANEL);
    _tft->drawString("[Cai gio]", 314, 19, 1);
  } else {
    // chỉ xóa đúng vùng cần update
    _tft->fillRect(0, 0, 110, 38, C_PANEL);
    _tft->fillRect(112, 2, 120, 36, C_PANEL);
  }

  // tiêu đề
  _tft->setTextDatum(TL_DATUM);
  _tft->setTextColor(C_WHITE, C_PANEL);
  _tft->drawString("IoT Monitor", 8, 5, 2);

  // trạng thái WiFi
  _tft->setTextColor(_state.wifiConnected ? C_RED : C_BLACK, C_PANEL);
  _tft->drawString(_state.wifiConnected ? "ONLINE" : "OFFLINE", 8, 24, 1);
  _tft->setTextColor(C_BLACK, C_PANEL);
  _tft->drawString("[NGAT]", 62, 24, 1);

  // giờ / ngày
  _tft->setTextDatum(MR_DATUM);
  _tft->setTextColor(C_WHITE, C_PANEL);
  _tft->drawString(_state.timeText, 228, 13, 2);

  _tft->setTextColor(C_GREY, C_PANEL);
  _tft->drawString(_state.dateText, 228, 30, 1);
}

static void drawSensorCard(TFT_eSPI* tft,
                           int x, int y, int w, int h,
                           const char* label, const String& val,
                           uint16_t accent, bool force) {
  //const String& val Là chuỗi giá trị cảm biến sẽ hiển thị ở giữa card. uint16_t accent Vẽ viền card Vẽ chữ label                       
  if (force) {
    tft->fillRoundRect(x, y, w, h, 8, 0x10A2);
    tft->drawRoundRect(x, y, w, h, 8, accent);

    tft->setTextDatum(TL_DATUM);
    tft->setTextColor(accent, 0x10A2);
    tft->drawString(label, x + 6, y + 4, 1);

    tft->setTextDatum(TR_DATUM);
    tft->setTextColor(0x7BEF, 0x10A2);
    tft->drawString("[NGUONG]", x + w - 6, y + 4, 1);
  } else {
    tft->fillRect(x + 4, y + 16, w - 8, h - 20, 0x10A2);
  }

  tft->setTextDatum(MC_DATUM);
  tft->setTextColor(C_WHITE, 0x10A2);
  tft->drawString(val, x + w / 2, y + h / 2 + 6, 2);
}

void DisplayUI::drawSensorRow(bool force) {
  const bool tempChg = force || (_state.temperatureC != _prev.temperatureC);
  const bool humChg  = force || (_state.humidityPercent != _prev.humidityPercent);
  const bool coChg   = force || (_state.coPpm != _prev.coPpm);
  const bool no2Chg  = force || (_state.no2Ppm != _prev.no2Ppm);

  if (tempChg) {
    String v = isnan(_state.temperatureC) ? "--.-" : String(_state.temperatureC, 1); // Nếu giá trị là NAN, hiển thị "--.- C". Nếu có giá trị, hiển thị một chữ số thập phân, ví dụ "30.5 C".
    v += " C";
    drawSensorCard(_tft, 4, 42, 153, 37, "NHIET DO", v, C_TEMP, force);
  }
  if (humChg) {
    String v = isnan(_state.humidityPercent) ? "--.-" : String(_state.humidityPercent, 1);
    v += " %";
    drawSensorCard(_tft, 163, 42, 153, 37, "DO AM", v, C_HUMID, force);
  }
  if (coChg) {
    String v = isnan(_state.coPpm) ? "---" : String(_state.coPpm, 2);
    v += " ppm";
    drawSensorCard(_tft, 4, 83, 153, 37, "CO", v, C_CO, force);
  }
  if (no2Chg) {
    String v = isnan(_state.no2Ppm) ? "--.-" : String(_state.no2Ppm, 3);
    v += " ppm";
    drawSensorCard(_tft, 163, 83, 153, 37, "NO2", v, C_NO2, force);
  }
}

static void drawRelayCard(TFT_eSPI* tft,
                          int x, int y, int w, int h,
                          const char* label, bool on, bool force,
                          uint16_t onColor) {
  const uint16_t bg       = on ? onColor      : C_OFF_BG;
  const uint16_t border   = on ? C_BLACK      : C_OFF_BORDER;
  const uint16_t labelCol = on ? C_BLACK      : C_OFF_TEXT;
  const uint16_t stateCol = on ? C_BLACK      : C_OFF_TEXT;

  if (force) {
    tft->fillRoundRect(x, y, w, h, 8, bg); // 8 là bán kính bo góc của card relay
    tft->drawRoundRect(x, y, w, h, 8, border); // vẽ viền card relay, màu viền phụ thuộc vào trạng thái on/off của relay
  } else {
    tft->fillRoundRect(x + 1, y + 1, w - 2, h - 2, 7, bg);
    tft->drawRoundRect(x, y, w, h, 8, border);
  }

  tft->setTextDatum(MC_DATUM); // canh giữa cả 2 chiều
  tft->setTextColor(labelCol, bg);
  tft->drawString(label, x + w / 2, y + h / 2 - 7, 1);

  tft->setTextColor(stateCol, bg);
  tft->drawString(on ? "BAT" : "TAT", x + w / 2, y + h / 2 + 6, 2);
}

void DisplayUI::drawRelayRow(bool force) {
  const bool r1Chg = force || (_state.relay1On != _prev.relay1On);
  const bool r2Chg = force || (_state.relay2On != _prev.relay2On);
  const bool r3Chg = force || (_state.relay3On != _prev.relay3On);
  const bool bzChg = force || (_state.buzzerOn != _prev.buzzerOn);

  if (r1Chg) drawRelayCard(_tft, 4,   124, 73, 56, "R1-NHIET", _state.relay1On, force, relayColor(0));
  if (r2Chg) drawRelayCard(_tft, 82,  124, 73, 56, "R2-AM",    _state.relay2On, force, relayColor(1));
  if (r3Chg) drawRelayCard(_tft, 160, 124, 73, 56, "R3-KHI",   _state.relay3On, force, relayColor(2));
  if (bzChg) drawRelayCard(_tft, 238, 124, 78, 56, "BUZZER",   _state.buzzerOn, force, relayColor(3));
}

void DisplayUI::drawModeButton(bool force) {
  const bool modeChg = force || (_state.mode != _prev.mode);
  if (!modeChg) return;

  const bool isAuto = (_state.mode == ControlMode::Auto);

  const uint16_t bg      = isAuto ? C_CYAN  : C_WHITE;
  const uint16_t border  = isAuto ? C_BLACK : C_GREY;
  const uint16_t textCol = isAuto ? C_BLACK : C_GREY;
  const uint16_t subCol  = isAuto ? C_BLACK : C_GREY;

  const String label = isAuto ? "CHE DO: TU DONG" : "CHE DO: THU CONG";
  const String sub   = isAuto ? "(Relay tu dong theo nguong)" : "(Nhan de chuyen Tu dong)";

  _tft->fillRoundRect(4, 185, 312, 50, 10, bg);
  _tft->drawRoundRect(4, 185, 312, 50, 10, border);

  _tft->setTextDatum(MC_DATUM);
  _tft->setTextColor(textCol, bg);
  _tft->drawString(label, 160, 205, 2);

  _tft->setTextColor(subCol, bg);
  _tft->drawString(sub, 160, 224, 1);
}

void DisplayUI::drawTimeSettings(bool force) {
  if (force) {
    _tft->fillScreen(C_BG);

    _tft->fillRect(0, 0, SW, 38, C_PANEL);
    _tft->drawFastHLine(0, 38, SW, C_LINE);

    _tft->setTextDatum(ML_DATUM);
    _tft->setTextColor(C_BLACK, C_PANEL);
    _tft->drawString("< BACK", 8, 19, 2);

    _tft->setTextDatum(MC_DATUM);
    _tft->setTextColor(C_BLACK, C_PANEL);
    _tft->drawString("CAI DAT THOI GIAN", 200, 19, 2);

    _tft->fillRoundRect(230, 190, 86, 44, 8, C_CYAN);
    _tft->drawRoundRect(230, 190, 86, 44, 8, C_BLACK);
    _tft->setTextDatum(MC_DATUM);
    _tft->setTextColor(C_BLACK, C_CYAN);
    _tft->drawString("LUU", 273, 212, 2);
  }

  const bool anyChange = force ||
    (_timeEdit.day    != _prevTimeEdit.day) ||
    (_timeEdit.month  != _prevTimeEdit.month) ||
    (_timeEdit.year   != _prevTimeEdit.year) ||
    (_timeEdit.hour   != _prevTimeEdit.hour) ||
    (_timeEdit.minute != _prevTimeEdit.minute) ||
    (_timeEdit.second != _prevTimeEdit.second);

  if (!anyChange) return;

  drawTimeField(4,   44, 68, 70, "Ngay",  _timeEdit.day,    force);
  drawTimeField(76,  44, 68, 70, "Thang", _timeEdit.month,  force);
  drawTimeField(148, 44, 78, 70, "Nam",   _timeEdit.year,   force);
  drawTimeField(4,  122,100, 62, "Gio",   _timeEdit.hour,   force);
  drawTimeField(110,122,100, 62, "Phut",  _timeEdit.minute, force);
  drawTimeField(216,122,100, 62, "Giay",  _timeEdit.second, force);
}

void DisplayUI::drawTimeField(int x, int y, int w, int h,
                              const char* label, int value, bool force) {
  constexpr int BTN_H = 14;
  const int topY = y + 16;
  const int botY = y + h - BTN_H - 4;

  if (force) {
    _tft->fillRoundRect(x, y, w, h, 8, C_PANEL);
    _tft->drawRoundRect(x, y, w, h, 8, C_LINE);

    _tft->fillRoundRect(x + 4, topY, w - 8, BTN_H, 5, 0x0340);
    _tft->drawRoundRect(x + 4, topY, w - 8, BTN_H, 5, C_ON);

    _tft->fillRoundRect(x + 4, botY, w - 8, BTN_H, 5, 0x2000);
    _tft->drawRoundRect(x + 4, botY, w - 8, BTN_H, 5, C_RED);

    _tft->setTextDatum(MC_DATUM);
    _tft->setTextColor(C_GREY, C_PANEL);
    _tft->drawString(label, x + w / 2, y + 8, 1);

    _tft->setTextColor(C_ON, 0x0340);
    _tft->drawString("+", x + w / 2, topY + BTN_H / 2, 2);

    _tft->setTextColor(C_RED, 0x2000);
    _tft->drawString("-", x + w / 2, botY + BTN_H / 2, 2);
  }

  // Chỉ xóa đúng vùng giữa nút + và nút -, không đè lên viền nút -
  const int valueTop = topY + BTN_H + 2;
  const int valueBottom = botY - 2;
  const int valueH = valueBottom - valueTop;

  _tft->fillRect(x + 4, valueTop, w - 8, valueH, C_PANEL);
  _tft->setTextDatum(MC_DATUM);
  _tft->setTextColor(C_WHITE, C_PANEL);
  _tft->drawString(String(value), x + w / 2, valueTop + valueH / 2, 2);
}

void DisplayUI::drawThresholdSettings(bool force) {
  const bool changed = force ||
                       (_thresholdEdit.value != _prevThresholdEdit.value) ||
                       (_thresholdEdit.title != _prevThresholdEdit.title) ||
                       (_thresholdEdit.unit  != _prevThresholdEdit.unit);

  if (!changed) return;

  if (force) {
    _tft->fillScreen(C_BG);

    _tft->fillRect(0, 0, SW, 38, C_PANEL);
    _tft->drawFastHLine(0, 38, SW, C_LINE);

    _tft->setTextDatum(ML_DATUM);
    _tft->setTextColor(C_WHITE, C_PANEL);
    _tft->drawString("< BACK", 8, 19, 2);

    _tft->setTextDatum(MC_DATUM);
    _tft->setTextColor(C_AUTO, C_PANEL);
    _tft->drawString("CAI DAT NGUONG", 200, 19, 2);

    _tft->fillRoundRect(230, 190, 86, 44, 8, 0x0340);
    _tft->drawRoundRect(230, 190, 86, 44, 8, C_WHITE);
    _tft->setTextDatum(MC_DATUM);
    _tft->setTextColor(C_WHITE, 0x0340);
    _tft->drawString("LUU", 273, 212, 2);

    _tft->fillRoundRect(20, 60, 280, 110, 10, C_PANEL);
    _tft->drawRoundRect(20, 60, 280, 110, 10, C_LINE);

    _tft->fillRoundRect(36, 125, 90, 28, 8, 0x2000);
    _tft->drawRoundRect(36, 125, 90, 28, 8, C_RED);

    _tft->fillRoundRect(194, 125, 90, 28, 8, 0x0340);
    _tft->drawRoundRect(194, 125, 90, 28, 8, C_ON);

    _tft->setTextDatum(MC_DATUM);
    _tft->setTextColor(C_RED, 0x2000);
    _tft->drawString("-", 81, 139, 4);

    _tft->setTextColor(C_ON, 0x0340);
    _tft->drawString("+", 239, 139, 4);
  }

  _tft->fillRect(40, 72, 240, 45, C_PANEL);
  _tft->setTextDatum(MC_DATUM);
  _tft->setTextColor(C_WHITE, C_PANEL);
  _tft->drawString(_thresholdEdit.title, 160, 80, 2);

  const String valueText =
      String(_thresholdEdit.value, static_cast<unsigned int>(_thresholdEdit.decimals))
      + " " + _thresholdEdit.unit;

  _tft->fillRect(60, 96, 200, 22, C_PANEL);
  _tft->setTextColor(C_AUTO, C_PANEL);
  _tft->drawString(valueText, 160, 108, 4);

  _tft->fillRect(40, 160, 240, 18, C_PANEL);
  _tft->setTextColor(C_GREY, C_PANEL);
  _tft->drawString("Nhan +/- de thay doi nguong", 160, 168, 1);
}
//--Hàm này dùng để kiểm tra điểm chạm có nằm trong một vùng hình chữ nhật hay không--//
// Các tham số: tx, ty là tọa độ điểm chạm; x, y là tọa độ góc trên bên trái của hình chữ nhật; w, h là chiều rộng và chiều cao của hình chữ nhật. Hàm trả về true nếu điểm chạm nằm trong hình chữ nhật, ngược lại trả về false.
bool DisplayUI::hitTest(int tx, int ty, int x, int y, int w, int h) const {
  return tx >= x && tx <= x + w && ty >= y && ty <= y + h;
}

void DisplayUI::handleTouch() {
  // _touch->tirqTouched() trả về true nếu có sự kiện chạm mới (tức là vừa chạm xuống màn hình). _touch->touched() trả về true nếu màn hình đang được chạm (tức là ngón tay vẫn chạm trên màn hình). Kết hợp hai điều kiện này, đoạn code đầu tiên kiểm tra xem có một lần chạm mới nào không. Nếu không có chạm mới và màn hình    không đang được chạm, thì nó sẽ reset trạng thái _held và cập nhật thời gian chạm cuối cùng.
  if (!(_touch->tirqTouched() && _touch->touched())) {
    if (_held) {
      _lastTouch = millis();
    }
    _held = false;
    return;
  }
  //Nếu không có chạm, hàm reset: _held = false và cập nhật _lastTouch = millis() để ghi lại thời điểm cuối cùng không còn chạm.
  if (_held) {
    return;
  }

  if (millis() - _lastTouch < DEBOUNCE_MS) return;// Chống Bấm Quá Nhanh
  //---Cảm ứng XPT2046 trả về tọa độ thô, ví dụ khoảng 200 -> 3700--//
  //---Code dùng map() để đổi về tọa độ màn hình--//
  TS_Point p = _touch->getPoint();
  int tx = constrain(map(p.x, TX_MIN, TX_MAX, 1, SW), 1, SW);
  int ty = constrain(map(p.y, TY_MIN, TY_MAX, 1, SH), 1, SH);

  _held = true;
  _lastTouch = millis();

  if (_screen == Screen::Dashboard) {
    if (ty <= 38 && tx >= 58 && tx <= 112) {
      _pendingWifiDisconnect = true;
      return;
    }

    if (hitTest(tx, ty, 4, 42, 153, 37)) {
      _pendingThresholdOpen = static_cast<int>(MetricType::Temperature);
      _screen = Screen::ThresholdSettings;
      invalidate();
      return;
    }
    if (hitTest(tx, ty, 163, 42, 153, 37)) {
      _pendingThresholdOpen = static_cast<int>(MetricType::Humidity);
      _screen = Screen::ThresholdSettings;
      invalidate();
      return;
    }
    if (hitTest(tx, ty, 4, 83, 153, 37)) {
      _pendingThresholdOpen = static_cast<int>(MetricType::Co);
      _screen = Screen::ThresholdSettings;
      invalidate();
      return;
    }
    if (hitTest(tx, ty, 163, 83, 153, 37)) {
      _pendingThresholdOpen = static_cast<int>(MetricType::No2);
      _screen = Screen::ThresholdSettings;
      invalidate();
      return;
    }

    if (ty >= 124 && ty <= 180) {
      if      (hitTest(tx, ty,   4, 124, 73, 56)) _pendingRelay = 0;
      else if (hitTest(tx, ty,  82, 124, 73, 56)) _pendingRelay = 1;
      else if (hitTest(tx, ty, 160, 124, 73, 56)) _pendingRelay = 2;
    }
    else if (ty >= 185 && ty <= 235) {
      _pendingMode = true;
    }
    else if (ty <= 38 && tx >= 240) {
      _screen = Screen::TimeSettings;
      invalidate();
    }
  }
  else if (_screen == Screen::TimeSettings) {
    if (ty <= 38 && tx <= 92) {
      _pendingBack = true;
      _screen = Screen::Dashboard;
      invalidate();
      return;
    }

    if (hitTest(tx, ty, 230, 190, 86, 44)) {
      _pendingTimeSave = true;
      _screen = Screen::Dashboard;
      invalidate();
      return;
    }

    struct Field { int x, y, w, h, idx; };
    const Field fields[] = {
      { 4,   44,  68, 70, 0 },
      { 76,  44,  68, 70, 1 },
      { 148, 44,  78, 70, 2 },
      { 4,   122, 100, 62, 3 },
      { 110, 122, 100, 62, 4 },
      { 216, 122, 100, 62, 5 },
    };

    constexpr int BTN_H = 14;
    for (const auto& f : fields) {
      if (!hitTest(tx, ty, f.x, f.y, f.w, f.h)) continue;

      const int topY = f.y + 16;
      const int botY = f.y + f.h - BTN_H - 4;

      if (ty >= topY && ty <= topY + BTN_H) {
        _pendingAdjField = f.idx;
        _pendingAdjDelta = +1;
      } else if (ty >= botY && ty <= botY + BTN_H) {
        _pendingAdjField = f.idx;
        _pendingAdjDelta = -1;
      }
      break;
    }
  }
  else if (_screen == Screen::ThresholdSettings) {
    if (ty <= 38 && tx <= 92) {
      _pendingBack = true;
      _screen = Screen::Dashboard;
      invalidate();
      return;
    }

    if (hitTest(tx, ty, 230, 190, 86, 44)) {
      _pendingThresholdSave = true;
      _screen = Screen::Dashboard;
      invalidate();
      return;
    }

    if (hitTest(tx, ty, 36, 125, 90, 28)) {
      _pendingThresholdDelta = -1;
      return;
    }

    if (hitTest(tx, ty, 194, 125, 90, 28)) {
      _pendingThresholdDelta = +1;
      return;
    }
  }
}
uint16_t DisplayUI::relayColor(uint8_t idx) const {
  switch (idx) {
    case 0: return C_RED;     // Relay 1
    case 1: return C_BLUE;    // Relay 2
    case 2: return C_YELLOW;  // Relay 3
    case 3: return C_GREEN;   // Buzzer
    default: return C_BLACK;  // sửa lỗi C_OFF không tồn tại
  }
}
