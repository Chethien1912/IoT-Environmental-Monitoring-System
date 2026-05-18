#include "AppController.h"
#include <HTTPClient.h>
#include <ctype.h>
#include <WiFi.h>

// Pin mapping
namespace {
constexpr int PIN_TOUCH_IRQ  = 36;
constexpr int PIN_TOUCH_MOSI = 32;
constexpr int PIN_TOUCH_MISO = 39;
constexpr int PIN_TOUCH_CLK  = 25;
constexpr int PIN_TOUCH_CS   = 33;

constexpr int PIN_CO_ADC  = 34;
constexpr int PIN_NO2_ADC = 35;

constexpr bool DEMO_GAS_VALUES = false;

constexpr unsigned long RTC_INTERVAL_MS     = 1000UL;//đọc RTC mỗi 1000 ms.
constexpr unsigned long SHT_INTERVAL_MS     = 1500UL;//đọc SHT31 mỗi 1500 ms.
constexpr unsigned long GAS_INTERVAL_MS     = 1500UL;//đọc CO và NO2 mỗi 1500 ms.
constexpr unsigned long CONTROL_INTERVAL_MS = 80UL;//
constexpr unsigned long UI_INTERVAL_MS      = 20UL;
constexpr unsigned long WIFI_INTERVAL_MS    = 20UL;
constexpr unsigned long LOG_INTERVAL_MS     = 3000UL;
constexpr unsigned long TELEMETRY_SYNC_MS   = 1500UL;
constexpr unsigned long BACKEND_POLL_MS     = 1500UL;
constexpr unsigned long BACKEND_WARN_MS     = 20000UL;
constexpr unsigned long NTP_RETRY_MS        = 60000UL;
constexpr unsigned long NTP_SYNC_MS         = 10UL * 60UL * 1000UL;

constexpr long NTP_GMT_OFFSET_SEC      = 7L * 3600L;
constexpr int  NTP_DAYLIGHT_OFFSET_SEC = 0;

constexpr uint32_t TASK_STACK_UI      = 8192;
constexpr uint32_t TASK_STACK_CONTROL = 4096;
constexpr uint32_t TASK_STACK_SENSOR  = 4096;
constexpr uint32_t TASK_STACK_WIFI    = 6144;

constexpr UBaseType_t TASK_PRIORITY_UI      = 4;
constexpr UBaseType_t TASK_PRIORITY_CONTROL = 2;
constexpr UBaseType_t TASK_PRIORITY_SENSOR  = 1;
constexpr UBaseType_t TASK_PRIORITY_WIFI    = 1;

constexpr BaseType_t TASK_CORE_UI      = 1;
constexpr BaseType_t TASK_CORE_CONTROL = 1;
constexpr BaseType_t TASK_CORE_SENSOR  = 0;
constexpr BaseType_t TASK_CORE_WIFI    = 0;

float randomFloat(float minValue, float maxValue) {
  return minValue + (static_cast<float>(random(0, 10001)) / 10000.0f) * (maxValue - minValue);
}

float randomDemoCoPpm() {
  return randomFloat(0.85f, 1.15f);
}

float randomDemoNo2Ppm() {
  return static_cast<float>(random(0, 3)) / 1000.0f;
}
}

AppController::AppController()
    : _touchSPI(VSPI),
      _touch(PIN_TOUCH_CS, PIN_TOUCH_IRQ),
      _ui(&_tft, &_touch),
      _co(PIN_CO_ADC),
      _no2(PIN_NO2_ADC) {
}

void AppController::begin() {
  Serial.begin(115200);
  delay(300);
  Serial.println("[APP] Khoi dong...");

  _stateMutex = xSemaphoreCreateMutex();

  _wifi.begin();
  _state.wifiConnected = _wifi.isConnected();   // thêm dòng này
  _macAddress = _wifi.LaySoMac();

  _relay.begin();
  _sht.begin();

  analogReadResolution(12);
  _co.begin();
  _no2.begin();
  randomSeed(static_cast<uint32_t>(micros()) ^
             static_cast<uint32_t>(analogRead(PIN_CO_ADC)) ^
             (static_cast<uint32_t>(analogRead(PIN_NO2_ADC)) << 12));

  _rtc.begin();
  if (!_rtc.isValid()) {
    _rtc.setManual(1, 1, 1, 2026, 0, 0, 0);
    Serial.println("[RTC] Dat gio mac dinh 01/01/2026 00:00:00");
  }

  _rtc.readFromDS3231();
  _state.dateText = formatDate();
  _state.timeText = formatTime();
  refreshTimeEdit();

  _touchSPI.begin(PIN_TOUCH_CLK, PIN_TOUCH_MISO, PIN_TOUCH_MOSI, PIN_TOUCH_CS);
  _touch.begin(_touchSPI);
  _touch.setRotation(1);

  _ui.setState(_state);
  _ui.setTimeEditState(_timeEdit);
  _ui.setThresholdEditState(_thresholdEdit);
  _ui.begin();

  Serial.println("[APP] San sang.");
}

void AppController::startTasks() {
  xTaskCreatePinnedToCore(taskUI,      "taskUI",      TASK_STACK_UI,      this, TASK_PRIORITY_UI,      &_taskUIHandle,     TASK_CORE_UI);
  xTaskCreatePinnedToCore(taskControl, "taskControl", TASK_STACK_CONTROL, this, TASK_PRIORITY_CONTROL, &_taskCtrlHandle,   TASK_CORE_CONTROL);
  xTaskCreatePinnedToCore(taskSensors, "taskSensors", TASK_STACK_SENSOR,  this, TASK_PRIORITY_SENSOR,  &_taskSensorHandle, TASK_CORE_SENSOR);
  xTaskCreatePinnedToCore(taskWifi,    "taskWifi",    TASK_STACK_WIFI,    this, TASK_PRIORITY_WIFI,    &_taskWifiHandle,   TASK_CORE_WIFI);
}

void AppController::taskUI(void* pv) {
  AppController* self = static_cast<AppController*>(pv);
  while(1) {
    self->runUI();
    vTaskDelay(pdMS_TO_TICKS(UI_INTERVAL_MS));
  }
}

void AppController::taskSensors(void* pv) {
  AppController* self = static_cast<AppController*>(pv);
  while(1) {
    self->runSensors();
    vTaskDelay(pdMS_TO_TICKS(20));
  }
}

void AppController::taskControl(void* pv) {
  AppController* self = static_cast<AppController*>(pv);
  while(1) {
    self->runControl();
    vTaskDelay(pdMS_TO_TICKS(CONTROL_INTERVAL_MS));
  }
}

void AppController::taskWifi(void* pv) {
  AppController* self = static_cast<AppController*>(pv);
  while(1) {
    self->runWifi();
    vTaskDelay(pdMS_TO_TICKS(WIFI_INTERVAL_MS));
  }
}

void AppController::runUI() {
  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
    _ui.setState(_state);
    _ui.setTimeEditState(_timeEdit);
    _ui.setThresholdEditState(_thresholdEdit);
    xSemaphoreGive(_stateMutex);
  }

  _ui.update();
  handleTouch();
}

void AppController::runSensors() {
  const unsigned long now = millis();

  if (now - _lastRtcMs >= RTC_INTERVAL_MS) {
    _lastRtcMs = now;
    readRtc();
  }

  if (now - _lastShtMs >= SHT_INTERVAL_MS) {
    _lastShtMs = now;
    readTempHumidity();
  }

  if (now - _lastGasMs >= GAS_INTERVAL_MS) {
    _lastGasMs = now;
    readGasSensors();
  }

  logSerial();
}

void AppController::runControl() {
  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(10)) != pdTRUE) return;

  if (_state.mode == ControlMode::Auto) {
    applyAutomation();
  }

  updateBuzzer();
  syncStateFromRelay();

  xSemaphoreGive(_stateMutex);
}

void AppController::runWifi() {
  _wifi.handle();
  _wifi.process();
  syncRtcFromNtpIfNeeded();

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(2)) == pdTRUE) {
    _state.wifiConnected = _wifi.isConnected();
    xSemaphoreGive(_stateMutex);
  }

  processBackendSync();
}

void AppController::readRtc() {
  _rtc.readFromDS3231();

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(10)) != pdTRUE) return;

  _state.dateText = formatDate();
  _state.timeText = formatTime();

  if (!_ui.isTimeSettingsOpen()) {
    refreshTimeEdit();
  }

  xSemaphoreGive(_stateMutex);
}

void AppController::readTempHumidity() {
  _sht.read();

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(10)) != pdTRUE) return;

  _state.temperatureC    = _sht.temperature;
  _state.humidityPercent = _sht.humidity;

  xSemaphoreGive(_stateMutex);
}

void AppController::readGasSensors() {
  // Hai hàm này vẫn có delay nội bộ, nhưng nay đã chạy ở task nền ưu tiên thấp
  const float co  = DEMO_GAS_VALUES ? randomDemoCoPpm() : _co.readPpm();
  const float no2 = DEMO_GAS_VALUES ? randomDemoNo2Ppm() : _no2.readPpm();

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(10)) != pdTRUE) return;

  _state.coPpm  = co;
  _state.no2Ppm = no2;

  xSemaphoreGive(_stateMutex);
}

void AppController::applyAutomation() {
  if (!isnan(_state.temperatureC)) {
    _relay.setRelay1(_state.temperatureC >= _thresholds.temp);
  }

  if (!isnan(_state.humidityPercent)) {
    _relay.setRelay2(_state.humidityPercent >= _thresholds.humid);
  }

  const bool gasAlarm = (!isnan(_state.coPpm)  && _state.coPpm  >= _thresholds.co) ||
                        (!isnan(_state.no2Ppm) && _state.no2Ppm >= _thresholds.no2);
  _relay.setRelay3(gasAlarm);
}

void AppController::updateBuzzer() {
  bool alarm = false;

  if (!isnan(_state.temperatureC) && _state.temperatureC >= _thresholds.temp) {
    alarm = true;
  }
  if (!isnan(_state.humidityPercent) &&
      _state.humidityPercent >= _thresholds.humid) {
    alarm = true;
  }
  if (!isnan(_state.coPpm) && _state.coPpm >= _thresholds.co) {
    alarm = true;
  }
  if (!isnan(_state.no2Ppm) && _state.no2Ppm >= _thresholds.no2) {
    alarm = true;
  }

  _relay.setBuzzer(alarm);
  _state.buzzerOn = alarm;
}

void AppController::handleTouch() {
  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(10)) != pdTRUE) return;

  bool runtimeChanged = false;
  bool telemetryChanged = false;

  uint8_t relayIdx = 0;
  if (_state.mode == ControlMode::Manual && _ui.consumeRelayToggle(relayIdx)) {
    if (relayIdx == 0) _relay.setRelay1(!_relay.k1);
    else if (relayIdx == 1) _relay.setRelay2(!_relay.k2);
    else if (relayIdx == 2) _relay.setRelay3(!_relay.k3);
    syncStateFromRelay();
    runtimeChanged = true;
    telemetryChanged = true;
  }

  if (_ui.consumeModeToggle()) {
    _state.mode = (_state.mode == ControlMode::Manual)
                  ? ControlMode::Auto
                  : ControlMode::Manual;

    if (_state.mode == ControlMode::Manual) {
      _relay.setRelay1(false);
      _relay.setRelay2(false);
      _relay.setRelay3(false);
      syncStateFromRelay();
    }

    runtimeChanged = true;
    telemetryChanged = true;
    Serial.printf("[APP] Che do: %s\n",
                  _state.mode == ControlMode::Auto ? "TU DONG" : "THU CONG");
  }

  if (_ui.consumeWifiDisconnect()) {
    _wifi.disconnectSavedWifi();
    _state.wifiConnected = false;
    telemetryChanged = true;
  }

  MetricType metric;
  if (_ui.consumeThresholdOpen(metric)) {
    openThresholdEditor(metric);
  }

  int thresholdDelta = 0;
  if (_ui.consumeThresholdAdjust(thresholdDelta)) {
    applyThresholdAdjust(thresholdDelta);
  }

  if (_ui.consumeThresholdSave()) {
    saveThresholdEdit();
    runtimeChanged = true;
    telemetryChanged = true;
    Serial.println("[THRESHOLD] Da luu nguong moi.");
  }

  int fi = 0, delta = 0;
  if (_ui.consumeTimeAdjust(fi, delta)) {
    applyTimeAdjust(fi, delta);
  }

  if (_ui.consumeTimeSave()) {
    struct tm t = {};
    t.tm_year = _timeEdit.year  - 1900;
    t.tm_mon  = _timeEdit.month - 1;
    t.tm_mday = _timeEdit.day;
    t.tm_hour = _timeEdit.hour;
    t.tm_min  = _timeEdit.minute;
    t.tm_sec  = _timeEdit.second;
    mktime(&t);

    _rtc.setManual(
      t.tm_wday,
      _timeEdit.day, _timeEdit.month, _timeEdit.year,
      _timeEdit.hour, _timeEdit.minute, _timeEdit.second
    );

    _state.dateText = formatDate();
    _state.timeText = formatTime();
    telemetryChanged = true;

    Serial.println("[RTC] Da luu thoi gian moi.");
  }

  _ui.consumeBack();

  xSemaphoreGive(_stateMutex);

  if (runtimeChanged) {
    _runtimeDirty = true;
  }
  if (telemetryChanged) {
    _telemetryDirty = true;
  }
}

void AppController::syncStateFromRelay() {
  _state.relay1On = _relay.k1;
  _state.relay2On = _relay.k2;
  _state.relay3On = _relay.k3;
  _state.buzzerOn = _relay.buzzer;
}

void AppController::syncRtcFromNtpIfNeeded() {
  const bool wifiConnected = _wifi.isConnected();
  const unsigned long now = millis();
  const bool justConnected = wifiConnected && !_lastWifiConnected;
  _lastWifiConnected = wifiConnected;

  if (!wifiConnected) {
    return;
  }

  if (!justConnected) {
    if (_lastNtpSyncMs > 0 && now - _lastNtpSyncMs < NTP_SYNC_MS) {
      return;
    }
    if (_lastNtpSyncMs == 0 && now - _lastNtpAttemptMs < NTP_RETRY_MS) {
      return;
    }
  }

  _lastNtpAttemptMs = now;
  if (!_rtc.syncFromNtp(NTP_GMT_OFFSET_SEC, NTP_DAYLIGHT_OFFSET_SEC)) {
    Serial.println("[RTC] Khong lay duoc NTP, tam thoi giu thoi gian DS3231.");
    return;
  }

  _lastNtpSyncMs = now;
  Serial.println("[RTC] Da dong bo NTP va cap nhat lai DS3231.");

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(20)) == pdTRUE) {
    _state.dateText = formatDate();
    _state.timeText = formatTime();
    if (!_ui.isTimeSettingsOpen()) {
      refreshTimeEdit();
    }
    xSemaphoreGive(_stateMutex);
  }

  _telemetryDirty = true;
}

void AppController::processBackendSync() {
  if (!_wifi.isConnected()) {
    return;
  }

  const String baseUrl = _wifi.getBackendBaseUrl();
  const unsigned long now = millis();
  if (baseUrl.isEmpty()) {
    if (now - _lastBackendWarnMs >= BACKEND_WARN_MS) {
      _lastBackendWarnMs = now;
      Serial.println("[BACKEND] Chua cau hinh Backend URL trong portal WiFi.");
    }
    return;
  }

  if (_runtimeDirty && now - _lastRuntimePushMs >= 100UL) {
    _lastRuntimePushMs = now;
    if (pushRuntimeState(baseUrl)) {
      _runtimeDirty = false;
    }
  }

  if ((_telemetryDirty || now - _lastTelemetrySyncMs >= TELEMETRY_SYNC_MS) && pushTelemetry(baseUrl)) {
    _telemetryDirty = false;
    _lastTelemetrySyncMs = now;
  }

  if (now - _lastBackendPollMs >= BACKEND_POLL_MS) {
    pullBackendState(baseUrl);
    _lastBackendPollMs = now;
  }
}

bool AppController::pushTelemetry(const String& baseUrl) {
  float temperatureC = NAN;
  float humidityPercent = NAN;
  float coPpm = NAN;
  float no2Ppm = NAN;
  float thresholdTemp = _thresholds.temp;
  float thresholdHumid = _thresholds.humid;
  float thresholdCo = _thresholds.co;
  float thresholdNo2 = _thresholds.no2;
  String dateText = "--/--/----";
  String timeText = "--:--:--";
  String controlMode = "manual";
  bool relay1On = false;
  bool relay2On = false;
  bool relay3On = false;
  bool buzzerOn = false;
  bool wifiConnected = false;

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(20)) == pdTRUE) {
    temperatureC = _state.temperatureC;
    humidityPercent = _state.humidityPercent;
    coPpm = _state.coPpm;
    no2Ppm = _state.no2Ppm;
    dateText = _state.dateText;
    timeText = _state.timeText;
    relay1On = _state.relay1On;
    relay2On = _state.relay2On;
    relay3On = _state.relay3On;
    buzzerOn = _state.buzzerOn;
    wifiConnected = _state.wifiConnected;
    controlMode = _state.mode == ControlMode::Auto ? "auto" : "manual";
    thresholdTemp = _thresholds.temp;
    thresholdHumid = _thresholds.humid;
    thresholdCo = _thresholds.co;
    thresholdNo2 = _thresholds.no2;
    xSemaphoreGive(_stateMutex);
  }

  HTTPClient http;
  http.begin(buildUrl(baseUrl, "/api/telemetry"));
  http.addHeader("Content-Type", "application/json");

  String body;
  body.reserve(384);
  body += "{\"deviceMac\":\"";
  body += _macAddress;
  body += "\",\"temperatureC\":";
  body += isnan(temperatureC) ? "null" : String(temperatureC, 2);
  body += ",\"humidityPercent\":";
  body += isnan(humidityPercent) ? "null" : String(humidityPercent, 2);
  body += ",\"coPpm\":";
  body += isnan(coPpm) ? "null" : String(coPpm, 2);
  body += ",\"no2Ppm\":";
  body += isnan(no2Ppm) ? "null" : String(no2Ppm, 3);
  body += ",\"dateText\":\"";
  body += dateText;
  body += "\",\"timeText\":\"";
  body += timeText;
  body += "\",\"relay1On\":";
  body += relay1On ? "true" : "false";
  body += ",\"relay2On\":";
  body += relay2On ? "true" : "false";
  body += ",\"relay3On\":";
  body += relay3On ? "true" : "false";
  body += ",\"buzzerOn\":";
  body += buzzerOn ? "true" : "false";
  body += ",\"wifiConnected\":";
  body += wifiConnected ? "true" : "false";
  body += ",\"controlMode\":\"";
  body += controlMode;
  body += "\",\"thresholds\":{\"temp\":";
  body += String(thresholdTemp, 1);
  body += ",\"humid\":";
  body += String(thresholdHumid, 1);
  body += ",\"co\":";
  body += String(thresholdCo, 1);
  body += ",\"no2\":";
  body += String(thresholdNo2, 2);
  body += "}}";

  const int code = http.POST(body);
  if (code != 200 && code != 202) {
    Serial.printf("[BACKEND] Telemetry POST loi: %d\n", code);
    http.end();
    return false;
  }

  http.end();
  return true;
}

bool AppController::pushRuntimeState(const String& baseUrl) {
  String controlMode = "manual";
  bool relay1On = false;
  bool relay2On = false;
  bool relay3On = false;
  float thresholdTemp = _thresholds.temp;
  float thresholdHumid = _thresholds.humid;
  float thresholdCo = _thresholds.co;
  float thresholdNo2 = _thresholds.no2;

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(20)) == pdTRUE) {
    //Cần phải copy trước khi gửi do các task cahy song song có thể thay đổi trạng thái trong lúc đang xây dựng payload
    controlMode = _state.mode == ControlMode::Auto ? "auto" : "manual";
    relay1On = _state.relay1On;
    relay2On = _state.relay2On;
    relay3On = _state.relay3On;
    thresholdTemp = _thresholds.temp;
    thresholdHumid = _thresholds.humid;
    thresholdCo = _thresholds.co;
    thresholdNo2 = _thresholds.no2;
    xSemaphoreGive(_stateMutex);
  }

  HTTPClient http;
  http.begin(buildUrl(baseUrl, "/api/device-local-control"));
  http.addHeader("Content-Type", "application/json");

  String body;
  body.reserve(256);
  body += "{\"deviceMac\":\"";
  body += _macAddress;
  body += "\",\"relay1On\":";
  body += relay1On ? "true" : "false";
  body += ",\"relay2On\":";
  body += relay2On ? "true" : "false";
  body += ",\"relay3On\":";
  body += relay3On ? "true" : "false";
  body += ",\"controlMode\":\"";
  body += controlMode;
  body += "\",\"thresholds\":{\"temp\":";
  body += String(thresholdTemp, 1);
  body += ",\"humid\":";
  body += String(thresholdHumid, 1);
  body += ",\"co\":";
  body += String(thresholdCo, 1);
  body += ",\"no2\":";
  body += String(thresholdNo2, 2);
  body += "}}";

  const int code = http.POST(body);
  if (code != 200) {
    Serial.printf("[BACKEND] Runtime sync loi: %d\n", code);
    http.end();
    return false;
  }

  http.end();
  return true;
}

void AppController::pullBackendState(const String& baseUrl) {
  HTTPClient http;
  http.begin(buildUrl(baseUrl, String("/api/device-state?deviceMac=") + _macAddress));
  const int code = http.GET();
  if (code != 200) {
    if (code > 0) {
      Serial.printf("[BACKEND] Device state GET loi: %d\n", code);
    }
    http.end();
    return;
  }

  const String response = http.getString();
  http.end();

  const String data = jsonExtractObject(response, "data");
  if (data.isEmpty()) {
    return;
  }

  const String relay1Cfg = jsonExtractObject(jsonExtractObject(data, "automationSettings"), "relay1");
  const String relay2Cfg = jsonExtractObject(jsonExtractObject(data, "automationSettings"), "relay2");
  const String relay3Cfg = jsonExtractObject(jsonExtractObject(data, "automationSettings"), "relay3");
  const String pendingRtc = jsonExtractObject(data, "pendingRtc");

  const bool desiredRelay1 = jsonGetBool(data, "desiredRelay1On", false);
  const bool desiredRelay2 = jsonGetBool(data, "desiredRelay2On", false);
  const bool desiredRelay3 = jsonGetBool(data, "desiredRelay3On", false);
  const String controlModeText = jsonGetString(data, "controlMode", "manual");
  const float nextTempThreshold = jsonGetNumber(relay1Cfg, "threshold", _thresholds.temp);
  const float nextHumidThreshold = jsonGetNumber(relay2Cfg, "threshold", _thresholds.humid);
  const float nextCoThreshold = jsonGetNumber(relay3Cfg, "coThreshold", _thresholds.co);
  const float nextNo2Threshold = jsonGetNumber(relay3Cfg, "no2Threshold", _thresholds.no2);
  const int pendingRtcVersion = jsonGetInt(data, "pendingRtcVersion", 0);

  bool shouldAckRtc = false;
  int rtcVersionToAck = 0;
  bool telemetryChanged = false;

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(30)) == pdTRUE) {
    const bool prevRelay1 = _state.relay1On;
    const bool prevRelay2 = _state.relay2On;
    const bool prevRelay3 = _state.relay3On;
    const bool prevBuzzer = _state.buzzerOn;
    const ControlMode prevMode = _state.mode;
    const String prevDate = _state.dateText;
    const String prevTime = _state.timeText;

    _thresholds.temp = nextTempThreshold;
    _thresholds.humid = nextHumidThreshold;
    _thresholds.co = nextCoThreshold;
    _thresholds.no2 = nextNo2Threshold;

    _state.mode = controlModeText == "auto" ? ControlMode::Auto : ControlMode::Manual;
    if (_state.mode == ControlMode::Manual) {
      _relay.setRelay1(desiredRelay1);
      _relay.setRelay2(desiredRelay2);
      _relay.setRelay3(desiredRelay3);
    } else {
      applyAutomation();
    }
    updateBuzzer();
    syncStateFromRelay();

    if (!pendingRtc.isEmpty() &&
        pendingRtcVersion > 0 &&
        pendingRtcVersion != _lastRtcVersionApplied) {
      const int year = jsonGetInt(pendingRtc, "year", _timeEdit.year);
      const int month = jsonGetInt(pendingRtc, "month", _timeEdit.month);
      const int day = jsonGetInt(pendingRtc, "day", _timeEdit.day);
      const int hour = jsonGetInt(pendingRtc, "hour", _timeEdit.hour);
      const int minute = jsonGetInt(pendingRtc, "minute", _timeEdit.minute);
      const int second = jsonGetInt(pendingRtc, "second", _timeEdit.second);

      struct tm t = {};
      t.tm_year = year - 1900;
      t.tm_mon = month - 1;
      t.tm_mday = day;
      t.tm_hour = hour;
      t.tm_min = minute;
      t.tm_sec = second;
      mktime(&t);

      _rtc.setManual(t.tm_wday, day, month, year, hour, minute, second);
      _rtc.readFromDS3231();
      _state.dateText = formatDate();
      _state.timeText = formatTime();
      refreshTimeEdit();
      _lastRtcVersionApplied = pendingRtcVersion;
    }

    if (!pendingRtc.isEmpty() &&
        pendingRtcVersion > 0 &&
        pendingRtcVersion > _lastRtcVersionAcked) {
      shouldAckRtc = true;
      rtcVersionToAck = pendingRtcVersion;
    }

    telemetryChanged =
        prevRelay1 != _state.relay1On ||
        prevRelay2 != _state.relay2On ||
        prevRelay3 != _state.relay3On ||
        prevBuzzer != _state.buzzerOn ||
        prevMode != _state.mode ||
        prevDate != _state.dateText ||
        prevTime != _state.timeText;

    xSemaphoreGive(_stateMutex);
  }

  if (telemetryChanged) {
    _telemetryDirty = true;
  }
  if (shouldAckRtc) {
    ackRtcSync(baseUrl, rtcVersionToAck);
  }
}

void AppController::ackRtcSync(const String& baseUrl, int version) {
  HTTPClient http;
  http.begin(buildUrl(baseUrl, "/api/device-rtc-ack"));
  http.addHeader("Content-Type", "application/json");

  String body;
  body.reserve(80); // ghĩa là đặt trước dung lượng bộ nhớ cho chuỗi body khoảng 80 ký tự để tránh việc phải cấp phát lại nhiều lần khi nối chuỗi
  body += "{\"deviceMac\":\"";
  body += _macAddress;
  body += "\",\"pendingRtcVersion\":";
  body += String(version);
  body += "}";

  const int code = http.POST(body);
  if (code == 200) {
    _lastRtcVersionAcked = version;
  } else {
    Serial.printf("[BACKEND] RTC ack loi: %d\n", code);
  }
  http.end();
}

void AppController::refreshTimeEdit() {
  _timeEdit.day    = _rtc.dt.ngay;
  _timeEdit.month  = _rtc.dt.thang;
  _timeEdit.year   = _rtc.dt.nam;
  _timeEdit.hour   = _rtc.dt.gio;
  _timeEdit.minute = _rtc.dt.phut;
  _timeEdit.second = _rtc.dt.giay;
}

void AppController::applyTimeAdjust(int fi, int delta) {
  switch (fi) {
    case 0: _timeEdit.day    += delta; break;
    case 1: _timeEdit.month  += delta; break;
    case 2: _timeEdit.year   += delta; break;
    case 3: _timeEdit.hour   += delta; break;
    case 4: _timeEdit.minute += delta; break;
    case 5: _timeEdit.second += delta; break;
    default: return;
  }

  _timeEdit.year   = constrain(_timeEdit.year, 2024, 2099);
  _timeEdit.month  = constrain(_timeEdit.month, 1, 12);
  _timeEdit.hour   = (_timeEdit.hour   + 24) % 24;
  _timeEdit.minute = (_timeEdit.minute + 60) % 60;
  _timeEdit.second = (_timeEdit.second + 60) % 60;
  _timeEdit.day    = constrain(_timeEdit.day, 1, daysInMonth(_timeEdit.month, _timeEdit.year));
}

int AppController::daysInMonth(int m, int y) const {
  switch (m) {
    case 4: case 6: case 9: case 11: return 30;
    case 2:
      return ((y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)) ? 29 : 28;
    default:
      return 31;
  }
}

void AppController::openThresholdEditor(MetricType metric) {
  _thresholdEdit.metric = metric;

  switch (metric) {
    case MetricType::Temperature:
      _thresholdEdit.value    = _thresholds.temp;
      _thresholdEdit.step     = 0.5f;
      _thresholdEdit.minValue = 0.0f;
      _thresholdEdit.maxValue = 80.0f;
      _thresholdEdit.title    = "NGUONG NHIET DO";
      _thresholdEdit.unit     = "C";
      _thresholdEdit.decimals = 1;
      break;

    case MetricType::Humidity:
      _thresholdEdit.value    = _thresholds.humid;
      _thresholdEdit.step     = 1.0f;
      _thresholdEdit.minValue = 0.0f;
      _thresholdEdit.maxValue = 100.0f;
      _thresholdEdit.title    = "NGUONG DO AM";
      _thresholdEdit.unit     = "%";
      _thresholdEdit.decimals = 1;
      break;

    case MetricType::Co:
      _thresholdEdit.value    = _thresholds.co;
      _thresholdEdit.step     = 1.0f;
      _thresholdEdit.minValue = 0.0f;
      _thresholdEdit.maxValue = 1000.0f;
      _thresholdEdit.title    = "NGUONG CO";
      _thresholdEdit.unit     = "ppm";
      _thresholdEdit.decimals = 0;
      break;

    case MetricType::No2:
      _thresholdEdit.value    = _thresholds.no2;
      _thresholdEdit.step     = 0.1f;
      _thresholdEdit.minValue = 0.0f;
      _thresholdEdit.maxValue = 15.0f;
      _thresholdEdit.title    = "NGUONG NO2";
      _thresholdEdit.unit     = "ppm";
      _thresholdEdit.decimals = 1;
      break;

    default:
      break;
  }
}

void AppController::applyThresholdAdjust(int delta) {
  _thresholdEdit.value += static_cast<float>(delta) * _thresholdEdit.step;

  if (_thresholdEdit.value < _thresholdEdit.minValue) {
    _thresholdEdit.value = _thresholdEdit.minValue;
  }
  if (_thresholdEdit.value > _thresholdEdit.maxValue) {
    _thresholdEdit.value = _thresholdEdit.maxValue;
  }
}

void AppController::saveThresholdEdit() {
  switch (_thresholdEdit.metric) {
    case MetricType::Temperature: _thresholds.temp  = _thresholdEdit.value; break;
    case MetricType::Humidity:    _thresholds.humid = _thresholdEdit.value; break;
    case MetricType::Co:          _thresholds.co    = _thresholdEdit.value; break;
    case MetricType::No2:         _thresholds.no2   = _thresholdEdit.value; break;
    default: break;
  }
}

String AppController::formatDate() const {
  if (!_rtc.isValid()) return "--/--/----";
  char buf[11];
  snprintf(buf, sizeof(buf), "%02d/%02d/%04d",
           _rtc.dt.ngay, _rtc.dt.thang, _rtc.dt.nam);
  return String(buf);
}

String AppController::formatTime() const {
  if (!_rtc.isValid()) return "--:--:--";
  char buf[9];
  snprintf(buf, sizeof(buf), "%02d:%02d:%02d",
           _rtc.dt.gio, _rtc.dt.phut, _rtc.dt.giay);
  return String(buf);
}

String AppController::buildUrl(const String& baseUrl, const String& path) {
  return baseUrl + path;
}

String AppController::jsonExtractObject(const String& json, const char* key) {
  const String needle = "\"" + String(key) + "\"";
  const int keyPos = json.indexOf(needle);
  if (keyPos < 0) {
    return "";
  }

  const int bracePos = json.indexOf('{', keyPos + needle.length());
  if (bracePos < 0) {
    return "";
  }

  int depth = 0;
  for (int i = bracePos; i < json.length(); ++i) {
    const char ch = json.charAt(i);
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        return json.substring(bracePos, i + 1);
      }
    }
  }

  return "";
}

String AppController::jsonGetString(const String& json, const char* key, const String& fallback) {
  const String needle = "\"" + String(key) + "\"";
  const int keyPos = json.indexOf(needle);
  if (keyPos < 0) {
    return fallback;
  }

  const int colonPos = json.indexOf(':', keyPos + needle.length());
  if (colonPos < 0) {
    return fallback;
  }

  const int quoteStart = json.indexOf('"', colonPos + 1);
  if (quoteStart < 0) {
    return fallback;
  }

  String value;
  for (int i = quoteStart + 1; i < json.length(); ++i) {
    const char ch = json.charAt(i);
    if (ch == '"' && json.charAt(i - 1) != '\\') {
      return value;
    }
    value += ch;
  }

  return fallback;
}

bool AppController::jsonGetBool(const String& json, const char* key, bool fallback) {
  const String needle = "\"" + String(key) + "\"";
  const int keyPos = json.indexOf(needle);
  if (keyPos < 0) {
    return fallback;
  }

  int valuePos = json.indexOf(':', keyPos + needle.length());
  if (valuePos < 0) {
    return fallback;
  }
  valuePos += 1;

  while (valuePos < json.length() && isspace(static_cast<unsigned char>(json.charAt(valuePos)))) {
    valuePos++;
  }

  const String remaining = json.substring(valuePos);
  if (remaining.startsWith("true")) return true;
  if (remaining.startsWith("false")) return false;
  if (remaining.startsWith("1")) return true;
  if (remaining.startsWith("0")) return false;
  return fallback;          
}

float AppController::jsonGetNumber(const String& json, const char* key, float fallback) {
  const String needle = "\"" + String(key) + "\"";
  const int keyPos = json.indexOf(needle);
  if (keyPos < 0) {
    return fallback;
  }

  int valuePos = json.indexOf(':', keyPos + needle.length());
  if (valuePos < 0) {
    return fallback;
  }
  valuePos += 1;

  while (valuePos < json.length() && isspace(static_cast<unsigned char>(json.charAt(valuePos)))) {
    valuePos++;
  }

  String value;
  while (valuePos < json.length()) {
    const char ch = json.charAt(valuePos);
    if ((ch >= '0' && ch <= '9') || ch == '-' || ch == '+' || ch == '.' || ch == 'e' || ch == 'E') {
      value += ch;
      valuePos++;
      continue;
    }
    break;
  }

  return value.isEmpty() ? fallback : value.toFloat();
}

int AppController::jsonGetInt(const String& json, const char* key, int fallback) {
  return static_cast<int>(jsonGetNumber(json, key, static_cast<float>(fallback)));
}

void AppController::logSerial() {
  const unsigned long now = millis();
  if (now - _lastLogMs < LOG_INTERVAL_MS) return;
  _lastLogMs = now;

  if (xSemaphoreTake(_stateMutex, pdMS_TO_TICKS(10)) != pdTRUE) return;

  Serial.printf(
    "[LOG] %s %s | Temp:%.1fC Hum:%.1f%% CO:%.2fppm NO2:%.3fppm"
    " | Thr(T/H/CO/NO2)=%.1f/%.1f/%.0f/%.1f"
    " | R1:%d R2:%d R3:%d Buz:%d | Mode:%s"
    " | WiFi:%s | STA:%s | AP:%s | MAC:%s\n",
    _state.dateText.c_str(), _state.timeText.c_str(),
    _state.temperatureC, _state.humidityPercent,
    _state.coPpm, _state.no2Ppm,
    _thresholds.temp, _thresholds.humid, _thresholds.co, _thresholds.no2,
    _state.relay1On, _state.relay2On, _state.relay3On, _state.buzzerOn,
    _state.mode == ControlMode::Auto ? "AUTO" : "MANUAL",
    _wifi.getStatusText().c_str(),
    _wifi.getStaIP().c_str(),
    _wifi.getApSSID().c_str(),
    _macAddress.c_str()
  );

  xSemaphoreGive(_stateMutex);
}
