#ifndef _MyWifi_h
#define _MyWifi_h

#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h> // lưu dữ liệu vào flash, kiểu như EEPROM hiện đại của ESP32.

class MyWifi {
 public:
  void begin();
  void startConfigPortal(); // bật web cấu hình ở 192.168.4.1
  void handle();// xử lý request web server, phải gọi liên tục trong loop().
  void process(); //xử lý kết nối WiFi, retry, timeout, v.v., cũng phải gọi liên tục trong loop()

  String LaySoMac(void);
  void KetNoiWiFi(int ThoiGianChoKetNoi);
  void requestConnect(const String& ssid, const String& password); //Yêu cầu ESP32 kết nối tới WiFi với ssid và password vừa nhập.
  void disconnectSavedWifi(); //Ngắt kết nối WiFi hiện tại và xóa SSID/password đã lưu, buộc người dùng phải vào AP config để cấu hình lại mạng.

  bool isConnected() const; // ESP32 đã kết nối WiFi nhà chưa.
  String getStaIP() const; //  IP của ESP32 trong mạng WiFi nhà.
  String getApIP() const;   // IP của ESP32 khi nó phát AP, thường là 192.168.4.1.
  String getApSSID() const; //tên WiFi AP mà ESP32 phát ra
  String getSavedSSID() const; // tên WiFi nhà đã lưu.
  String getBackendBaseUrl() const; //URL backend đã cấu hình.
  String getStatusText() const; //trạng thái WiFi dạng text.

 private:
  String TenWiFi = "";
  String MatKhauWiFi = "";
  String BackendBaseUrl = "";

  String _apSsid; //tên WiFi ESP32 tự phát, thường là "ESP32-xxxxxx" với xxxxxx là 6 ký tự cuối của MAC address.
  String _apPass = "12345678";
  String _macNoColon; //MAC address của ESP32 nhưng bỏ dấu ":" đi, dùng để tạo SSID AP và lưu trong Preferences làm key phụ trợ tránh trùng lặp giữa các thiết bị. 

  WebServer _server{80}; // web server để phục vụ trang cấu hình khi ESP32 ở chế độ AP.
  Preferences _prefs;  // dùng lưu/read cấu hình WiFi trong flash.

  bool _portalStarted = false; // web config portal đã bật chưa
  bool _connectRequested = false; // có yêu cầu bắt đầu kết nối WiFi không.
  bool _connecting = false; // đang trong quá trình kết nối WiFi (đã gọi WiFi.begin() nhưng chưa có kết quả thành công hay thất bại).
  unsigned long _connectStartMs = 0; // thời điểm bắt đầu thử kết nối WiFi, dùng để tính timeout.
  unsigned long _lastRetryMs = 0; // thời điểm cuối cùng đã thử bắt đầu kết nối WiFi, dùng để giới hạn tần suất retry khi có cấu hình WiFi nhưng chưa kết nối được.

  static constexpr unsigned long CONNECT_TIMEOUT_MS = 15000UL; // thời gian tối đa chờ kết nối WiFi thành công trước khi coi là thất bại, tính từ lúc gọi WiFi.begin(). Nếu có lỗi sẽ in ra lý do thất bại trên Serial Monitor.
  static constexpr unsigned long RETRY_INTERVAL_MS  = 30000UL; // khoảng thời gian tối thiểu giữa các lần thử bắt đầu kết nối WiFi khi đã có cấu hình WiFi nhưng chưa kết nối được. Ví dụ nếu đặt 30000ms thì sau khi ESP32 khởi động, nếu có cấu hình WiFi nhưng không kết nối được, nó sẽ thử bắt đầu kết nối ngay. Nếu sau 30 giây mà vẫn chưa kết nối được thì nó sẽ thử bắt đầu kết nối lại lần nữa, cứ như vậy cho đến khi thành công. Mục đích là để tránh việc cứ liên tục gọi WiFi.begin() trong

  void loadCredentials(); // đọc cấu hình WiFi đã lưu trong flash vào biến TenWiFi, MatKhauWiFi, BackendBaseUrl.
  void saveCredentials(const String& ssid, const String& password, const String& backendUrl); // lưu cấu hình WiFi mới vào flash và cập nhật biến TenWiFi, MatKhauWiFi, BackendBaseUrl.
  void beginStationConnect(); // bắt đầu quá trình kết nối WiFi với cấu hình đã lưu trong TenWiFi, MatKhauWiFi. Gọi WiFi.begin() và set _connecting=true, _connectStartMs=millis(), _lastRetryMs=millis().
  void setupRoutes();// thiết lập các đường dẫn cho web server khi ESP32 ở chế độ AP config.
  String buildHtml() const; //tạo giao diện HTML cho trang cấu hình.
  String normalizeUrl(const String& url) const; //chuẩn hóa URL, ví dụ xóa dấu / cuối.
};

#endif
