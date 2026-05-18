#ifndef APP_CONTROLLER_H
#define APP_CONTROLLER_H

#include <Arduino.h>
#include <TFT_eSPI.h>
#include <XPT2046_Touchscreen.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/semphr.h>

#include "DeviceState.h"
#include "CO.h"
#include "NO2.h"
#include "MySHT31.h"
#include "RTC.h"
#include "Relay.h"
#include "DisplayUI.h"
#include "MyWifi.h"

// Nguong dung chung cho relay AUTO va buzzer
struct ThresholdConfig {
  float temp  = 35.0f;   // Relay 1
  float humid = 70.0f;   // Relay 2
  float co    = 50.0f;   // Relay 3
  float no2   = 15.0f;   // Relay 3
};

class AppController {
 public:
  AppController();

  void begin();
  void startTasks();

 private:
  // Hardware
  SPIClass            _touchSPI;
  XPT2046_Touchscreen _touch;
  TFT_eSPI            _tft;
  DisplayUI           _ui;
  COSensor            _co;
  NO2Sensor           _no2;
  SHT3x               _sht;
  RTC                 _rtc;
  Relay               _relay;
  MyWifi              _wifi;
  String              _macAddress;

  // Shared state
  DeviceState         _state;
  TimeEditState       _timeEdit;
  ThresholdConfig     _thresholds;
  ThresholdEditState  _thresholdEdit;

  // RTOS
  SemaphoreHandle_t _stateMutex       = nullptr;
  TaskHandle_t      _taskUIHandle     = nullptr; //là mã định danh cho task người dùng tạo
  TaskHandle_t      _taskSensorHandle = nullptr;
  TaskHandle_t      _taskCtrlHandle   = nullptr;
  TaskHandle_t      _taskWifiHandle   = nullptr;

  // Timing
  unsigned long _lastRtcMs = 0; //Lưu thời điểm lần cuối đọc RTC. Dùng trong runSensors() Nghĩa là cứ đủ RTC_INTERVAL_MS, hiện tại là 1000 ms, thì đọc RTC một lần.
  unsigned long _lastShtMs = 0; //Lưu thời điểm lần cuối đọc cảm biến SHT31. Dùng trong runSensors() Nghĩa là cứ đủ SHT_INTERVAL_MS, hiện tại là 2000 ms, thì đọc SHT31 một lần.
  unsigned long _lastGasMs = 0; //Lưu thời điểm lần cuối đọc cảm biến khí CO và NO2.
  unsigned long _lastLogMs = 0; //Lưu thời điểm lần cuối in log ra Serial.
  unsigned long _lastTelemetrySyncMs = 0; //Lưu thời điểm lần cuối gửi telemetry lên backend dùng trong processBackendSync()
  unsigned long _lastBackendPollMs = 0; //Lưu thời điểm lần cuối hỏi backend xem có lệnh mới không. dùng trong pullBackendState
  unsigned long _lastRuntimePushMs = 0; // Lưu thời điểm lần cuối gửi trạng thái runtime lên backend
  unsigned long _lastBackendWarnMs = 0; // Lưu thời điểm lần cuối backend cảnh báo điều kiện nguy hiểm, dùng để tránh việc cứ liên tục nhận cảnh báo rồi bật relay/buzzer liên tục khi điều kiện nguy hiểm vẫn còn đó.
  unsigned long _lastNtpAttemptMs = 0; // Lưu thời điểm lần cuối thử đồng bộ thời gian từ NTP.
  unsigned long _lastNtpSyncMs = 0; //Dùng để giới hạn chu kỳ sync NTP.

  bool _telemetryDirty = true; // Cờ báo telemetry đã thay đổi và cần gửi lên backend.
  bool _runtimeDirty = false; // Cờ báo trạng thái runtime (relay/buzzer) đã thay đổi và cần gửi lên backend.
  int  _lastRtcVersionApplied = 0; // Lưu version RTC từ backend đã được ESP32 áp dụng. Mục đích: tránh áp dụng cùng một lệnh RTC nhiều lần
  int  _lastRtcVersionAcked = 0;  // Lưu version RTC mà ESP32 đã báo lại backend là đã xử lý xong. Mục đích: tránh gửi ack trùng lặp quá nhiều lần.
  bool _lastWifiConnected = false;  // Lưu trạng thái WiFi ở lần kiểm tra trước Nó giúp phát hiện WiFi vừa mới kết nối. Nếu vừa mới kết nối, code có thể sync NTP ngay

  // Task entry
  static void taskUI(void* pv); // là hàm task FreeRTOS gọi. Vì FreeRTOS yêu cầu hàm task phải có kiểu void(void*), nên các hàm runUI, runSensors, runControl, runWifi sẽ là các hàm thành viên bình thường, còn các hàm taskUI, taskSensors, taskControl, taskWifi sẽ là các hàm static dùng để gọi các hàm thành viên đó.
  static void taskSensors(void* pv);
  static void taskControl(void* pv);
  static void taskWifi(void* pv);

  // Task body
  void runUI(); // Task Body của task UI, sẽ chạy vòng lặp liên tục để cập nhật giao diện người dùng. Trong mỗi vòng lặp, nó sẽ gọi _ui.update() để
  void runSensors();
  void runControl();
  void runWifi();

  // Logic
  void readRtc();
  void readTempHumidity();
  void readGasSensors();
  void applyAutomation();
  void updateBuzzer();
  void handleTouch();
  void syncStateFromRelay();
  void syncRtcFromNtpIfNeeded();
  void processBackendSync();
  bool pushTelemetry(const String& baseUrl); // Gửi dữ liệu telemetry lên backend
  bool pushRuntimeState(const String& baseUrl); //Gửi trạng thái điều khiển runtime lên backend.
  void pullBackendState(const String& baseUrl); //Hỏi backend xem có lệnh mới nào không, ví dụ đổi trạng thái relay, chỉnh ngưỡng, chỉnh thời gian, v.v... rồi cập nhật lại trạng thái trong ESP32.
  void ackRtcSync(const String& baseUrl, int version); //Gửi ack về backend sau khi đã áp dụng xong lệnh sync thời gian từ backend, để backend biết là ESP32 đã xử lý xong và không cần phải gửi lại lệnh đó nữa.

  // Time edit
  void refreshTimeEdit(); //Copy thời gian hiện tại từ RTC sang _timeEdit
  void applyTimeAdjust(int fieldIndex, int delta); // Tăng hoặc giảm một phần của thời gian.
  int  daysInMonth(int m, int y) const;

  // Threshold edit
  void openThresholdEditor(MetricType metric); //Chuẩn bị dữ liệu để mở màn hình chỉnh ngưỡn
  void applyThresholdAdjust(int delta); //Tăng hoặc giảm giá trị ngưỡng đang chỉnh.
  void saveThresholdEdit(); //Lưu giá trị ngưỡng đang chỉnh vào cấu hình ngưỡng thật _thresholds

  // Utils
  String formatDate() const; //Chuyển ngày từ RTC thành chuỗi hiển thị.
  String formatTime() const; //Chuyển giờ từ RTC thành chuỗi hiển thị.
  void logSerial();
  static String buildUrl(const String& baseUrl, const String& path);//Ghép URL backend.
  static String jsonExtractObject(const String& json, const char* key); //Tìm và lấy một object con trong JSON
  static String jsonGetString(const String& json, const char* key, const String& fallback = ""); // Nếu có "controlMode":"auto" thì trả "auto"Nếu không tìm thấy thì trả fallback "manual"
  static bool jsonGetBool(const String& json, const char* key, bool fallback); // Lấy giá trị boolean từ JSON.
  static float jsonGetNumber(const String& json, const char* key, float fallback); // Lấy số thực từ JSON
  static int jsonGetInt(const String& json, const char* key, int fallback); // Lấy số nguyên từ JSON
};

#endif
