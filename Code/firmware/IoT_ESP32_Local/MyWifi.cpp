#include "MyWifi.h"
#include <esp_system.h> // để đọc MAC address của ESP32

namespace {
// Neu muon bo qua URL da luu trong Preferences, sua truc tiep dong duoi day.
// VD: "http://192.168.1.13:3000"
constexpr char DEFAULT_BACKEND_URL[] = "http://192.168.1.21:3000"; // Biến này là backend mặc định

String wifiStatusToText(wl_status_t status) {
  switch (status) {
    case WL_CONNECTED:      return "Da ket noi";
    case WL_NO_SSID_AVAIL:  return "Khong tim thay SSID";
    case WL_CONNECT_FAILED: return "Sai mat khau / that bai";
    case WL_CONNECTION_LOST:return "Mat ket noi";
    case WL_DISCONNECTED:   return "Chua ket noi";
    case WL_IDLE_STATUS:    return "Dang cho";
    default:                return "Khong ro";
  }
}
}

String MyWifi::LaySoMac(void) { // Chuyển 6 byte MAC thành chuỗi 12 ký tự hex viết hoa.
  uint8_t mac[6] = {0};
  esp_read_mac(mac, ESP_MAC_WIFI_STA);

  char buf[13];
  snprintf(buf, sizeof(buf), "%02X%02X%02X%02X%02X%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

  _macNoColon = String(buf);
  return _macNoColon;
}

void MyWifi::begin() {
  if (_macNoColon.isEmpty()) {
    LaySoMac();
  }

  _apSsid = "ESP32-SETUP-" + _macNoColon.substring(_macNoColon.length() - 6); //Tạo tên AP từ 6 ký tự cuối MAC

  //---Mở vùng lưu Preferences tên wifi_cfg, rồi đọc cấu hình WiFi đã lưu---//
  _prefs.begin("wifi_cfg", false);
  loadCredentials();
  //-----------------------------------------------------------------------//

  WiFi.persistent(false);// không để thư viện WiFi tự ghi cấu hình vào flash. Việc lưu cấu hình sẽ do chính code của MyWifi kiểm soát thông qua Preferences, tránh việc WiFi.begin
  WiFi.setSleep(false);  //tắt sleep để WiFi ổn định hơn.
  WiFi.mode(WIFI_AP_STA); // ESP32 chạy cả 2 chế độ AP và STA cùng lúc. Khi có cấu hình WiFi nhà thì nó sẽ tự động kết nối vào WiFi đó, nếu chưa có hoặc kết nối thất bại thì nó vẫn phát AP để người dùng có thể vào cấu hình.

  const bool apOk = WiFi.softAP(_apSsid.c_str(), _apPass.c_str()); //Bật WiFi AP với SSID và password đã tạo.
  delay(100);

  Serial.println();
  Serial.println("[WIFI] ===== CHE DO CAU HINH =====");
  Serial.print("[WIFI] MAC ESP32: ");
  Serial.println(_macNoColon);
  Serial.print("[WIFI] AP SSID  : ");
  Serial.println(_apSsid);
  Serial.print("[WIFI] AP PASS  : ");
  Serial.println(_apPass);
  Serial.print("[WIFI] AP IP    : ");
  Serial.println(WiFi.softAPIP());
  Serial.print("[WIFI] AP start : ");
  Serial.println(apOk ? "OK" : "FAIL");

  startConfigPortal(); //Bật web config portal ngay sau khi khởi động, dù có cấu hình WiFi hay không, để người dùng có thể vào cấu hình bất cứ lúc nào.

  if (!TenWiFi.isEmpty()) {
    Serial.print("[WIFI] Da tim thay WiFi da luu: ");
    Serial.println(TenWiFi);
    _connectRequested = true;
  } else {
    Serial.println("[WIFI] Chua co WiFi da luu. Hay vao web 192.168.4.1 de cau hinh.");
  }
}

void MyWifi::startConfigPortal() {
  if (_portalStarted) return;
  setupRoutes(); // để đăng ký các URL.
  _server.begin(); //để chạy web server.
  _portalStarted = true;
  Serial.println("[WIFI] Web config portal dang chay tai http://192.168.4.1");
}

void MyWifi::setupRoutes() {
  //---_server.on(đường_dẫn, phương_thức_HTTP, hàm_xử_lý);--//
  //"/" là trang chính của web config portal, hiển thị thông tin và form cấu hình WiFi. vi du: http://192.168.4.1/
  // "/save" http://192.168.4.1/save
  // HTTP_GET: dùng khi trình duyệt xin dữ liệu / mở trang. mở trang cấu hình → GET /
  // HTTP_POST: dùng khi trình duyệt gửi dữ liệu lên server, thường là form. bấm nút lưu form → POST /save
  // [this]() { ... } Đây là hàm callback được chạy khi có request phù hợp. Nó có nghĩa là lambda này được phép dùng các thành viên của object hiện tại, ví dụ: _server, buildHtml(),normalizeUrl()
  // _server.send(mã_trạng_thái, kiểu_nội_dung, nội_dung);
  // 200 = thành công
  // "text/html; charset=utf-8" text/html → nội dung là HTML charset=utf-8 → hiển thị tiếng Việt đúng
  // buildHtml() Hàm này thường trả về một String chứa mã HTML của trang web.
  _server.on("/", HTTP_GET, [this]() {
    _server.send(200, "text/html; charset=utf-8", buildHtml());
  }); 
  _server.on("/save", HTTP_POST, [this]() {
    String ssid = _server.arg("ssid"); // lấy dữ liêu từ form, với "ssid", "password", "backend_url" là tên của các input trong form HTML. Ví dụ: <input name='ssid' ...>, thì ở đây sẽ lấy được giá trị người dùng nhập vào ô SSID.
    String password = _server.arg("password");
    String backendUrl = _server.arg("backend_url");
    ssid.trim(); //rim() dùng để xóa khoảng trắng đầu và cuối chuỗi.Việc này giúp tránh lỗi do người dùng vô tình nhập khoảng trắng
    backendUrl = normalizeUrl(backendUrl); // chuẩn hóa URL, ví dụ xóa dấu / cuối. Việc này giúp tránh lỗi khi so sánh URL hoặc khi dùng URL để gọi API sau này.

    if (ssid.isEmpty()) {
      _server.send(400, "text/html; charset=utf-8",
                   "<html><body><h3>SSID khong duoc de trong</h3><a href='/'>Quay lai</a></body></html>");
      return;
    }
    //Lưu vào flash, rồi yêu cầu kết nối WiFi.Sau đó trả về trang HTML báo đã lưu cấu hình.//
    saveCredentials(ssid, password, backendUrl);
    requestConnect(ssid, password);

    String html;
    html += F("<!doctype html><html><head><meta charset='utf-8'>");
    html += F("<meta name='viewport' content='width=device-width,initial-scale=1'>");
    html += F("<title>Da luu WiFi</title></head><body style='font-family:Arial;padding:16px'>");
    html += F("<h2>Da luu cau hinh WiFi</h2>");
    html += F("<p>ESP32 dang thu ket noi toi: <b>");
    html += ssid;
    html += F("</b></p>");
    html += F("<p>Backend URL: <b>");
    html += backendUrl.isEmpty() ? String("(chua cau hinh)") : backendUrl;
    html += F("</b></p><p>Cho 5-15 giay roi tai lai trang chinh de xem trang thai.</p>");
    html += F("<p><a href='/'>Quay lai trang chinh</a></p>");
    html += F("</body></html>");
    _server.send(200, "text/html; charset=utf-8", html);
  });
    
   //Route này trả JSON thông tin trạng thái. Ví dụ khi gọi http://192.168.4.1/info thì sẽ nhận được JSON chứa MAC address, tên AP, IP AP, SSID đã lưu, URL backend đã cấu hình, trạng thái WiFi, IP STA, v.v. Route này rất hữu ích để app di động hoặc frontend có thể gọi lấy thông tin trạng thái hiện tại của ESP32 mà không cần phải parse HTML.
  _server.on("/info", HTTP_GET, [this]() {
    String json = "{";
    json += "\"mac\":\"" + _macNoColon + "\",";
    json += "\"ap_ssid\":\"" + _apSsid + "\",";
    json += "\"ap_ip\":\"" + getApIP() + "\",";
    json += "\"saved_ssid\":\"" + TenWiFi + "\",";
    json += "\"backend_url\":\"" + BackendBaseUrl + "\",";
    json += "\"wifi_status\":\"" + getStatusText() + "\",";
    json += "\"sta_ip\":\"" + getStaIP() + "\"";
    json += "}";
    _server.send(200, "application/json; charset=utf-8", json);
  }); //Route này hữu ích nếu frontend/backend muốn kiểm tra trạng thái ESP32.

   // Định nghĩa route mặc định khi người dùng truy cập vào một đường dẫn không tồn tại trên web server. Ở đây mình chọn cách redirect về trang chính "/", nhưng bạn cũng có thể trả về trang lỗi 404 nếu muốn.
  _server.onNotFound([this]() {
    _server.sendHeader("Location", "/");
    _server.send(302, "text/plain", "");
  });
}

String MyWifi::buildHtml() const {
  String html;
  html.reserve(2600);

  html += F("<!doctype html><html><head><meta charset='utf-8'>");
  html += F("<meta name='viewport' content='width=device-width,initial-scale=1'>");
  html += F("<title>ESP32 WiFi Config</title></head>");
  html += F("<body style='font-family:Arial;background:#f4f7fb;margin:0;padding:14px'>");
  html += F("<div style='max-width:520px;margin:auto;background:#fff;padding:18px;border-radius:14px;box-shadow:0 2px 10px rgba(0,0,0,.08)'>");
  html += F("<h2 style='margin-top:0'>Cau hinh WiFi cho ESP32</h2>");
  html += F("<p><b>MAC:</b> ");
  html += _macNoColon;
  html += F("<br><b>AP SSID:</b> ");
  html += _apSsid;
  html += F("<br><b>AP Password:</b> ");
  html += _apPass;
  html += F("<br><b>AP IP:</b> ");
  html += getApIP();
  html += F("<br><b>Backend URL:</b> ");
  html += BackendBaseUrl.isEmpty() ? String("(chua cau hinh)") : BackendBaseUrl;
  html += F("</p>");

  html += F("<div style='padding:12px;background:#eef6ff;border-radius:10px;margin:12px 0'>");
  html += F("<b>Trang thai WiFi hien tai</b><br>");
  html += F("SSID da luu: ");
  html += TenWiFi.isEmpty() ? String("(chua co)") : TenWiFi;
  html += F("<br>Trang thai: ");
  html += getStatusText();
  html += F("<br>IP noi mang nha: ");
  html += getStaIP();
  html += F("</div>");

  html += F("<form method='POST' action='/save'>");
  html += F("<label>Ten WiFi (SSID)</label><br>");
  html += F("<input name='ssid' style='width:100%;padding:10px;margin:6px 0 12px;border-radius:8px;border:1px solid #bbb' value='");
  html += TenWiFi;
  html += F("' required><br>");
  html += F("<label>Mat khau</label><br>");
  html += F("<input name='password' type='password' autocomplete='current-password' style='width:100%;padding:10px;margin:6px 0 12px;border-radius:8px;border:1px solid #bbb'><br>");
  html += F("<label>Backend URL</label><br>");
  html += F("<input name='backend_url' style='width:100%;padding:10px;margin:6px 0 12px;border-radius:8px;border:1px solid #bbb' placeholder='http://192.168.x.x:3000' value='");
  html += BackendBaseUrl;
  html += F("'><br>");
  html += F("<button type='submit' style='width:100%;padding:12px;border:0;border-radius:10px;background:#0b79d0;color:#fff;font-weight:bold'>Luu va ket noi</button>");
  html += F("</form>");

  html += F("<p style='font-size:13px;color:#555;margin-top:14px'>Sau khi dien thoai ket noi vao AP cua ESP32, mo trinh duyet va vao <b>192.168.4.1</b>. AP van duoc giu mo, nen ban co the vao lai bat cu luc nao de doi WiFi.</p>");
  html += F("</div></body></html>");
  return html;
}
// Đọc dữ liệu đã lưu trong flash vào biến TenWiFi, MatKhauWiFi, BackendBaseUrl. Hàm này được gọi trong begin() sau khi mở vùng lưu Preferences.
void MyWifi::loadCredentials() {
  TenWiFi = _prefs.getString("ssid", "");
  MatKhauWiFi = _prefs.getString("pass", "");
  BackendBaseUrl = normalizeUrl(_prefs.getString("backend_url", ""));

  const String forcedBackendUrl = normalizeUrl(DEFAULT_BACKEND_URL); //Nếu DEFAULT_BACKEND_URL không rỗng, nó sẽ ép BackendBaseUrl dùng giá trị hard-cod
  if (!forcedBackendUrl.isEmpty()) {
    BackendBaseUrl = forcedBackendUrl;
  }
}
//Cập nhật biến trong RAM. Lưu cấu hình mới vào flash. Hàm này được gọi khi người dùng submit form cấu hình trên web config portal.
void MyWifi::saveCredentials(const String& ssid, const String& password, const String& backendUrl) {
  TenWiFi = ssid;
  MatKhauWiFi = password;
  BackendBaseUrl = normalizeUrl(backendUrl);
  _prefs.putString("ssid", TenWiFi);
  _prefs.putString("pass", MatKhauWiFi);
  _prefs.putString("backend_url", BackendBaseUrl);

  Serial.print("[WIFI] Da luu SSID moi: ");
  Serial.println(TenWiFi);
  Serial.print("[WIFI] Backend URL: ");
  Serial.println(BackendBaseUrl.isEmpty() ? "(chua cau hinh)" : BackendBaseUrl);
}
//Hàm này chưa kết nối ngay. Nó chỉ lưu SSID/password vào RAM và bật cờ//
void MyWifi::requestConnect(const String& ssid, const String& password) {
  TenWiFi = ssid;
  MatKhauWiFi = password;
  _connectRequested = true;
}
//Hàm này sẽ xóa cấu hình đã lưu và ngắt kết nối WiFi hiện tại. Sau khi gọi hàm này, người dùng sẽ phải vào lại AP config để cấu hình WiFi mới.
void MyWifi::disconnectSavedWifi() {
  _connectRequested = false;
  _connecting = false;
  _lastRetryMs = millis();

  TenWiFi = "";
  MatKhauWiFi = "";
  _prefs.remove("ssid");
  _prefs.remove("pass");

  WiFi.disconnect(false, true);
  Serial.println("[WIFI] Da ngat WiFi va xoa SSID/password da luu. Vao AP config de doi mang.");
}

void MyWifi::KetNoiWiFi(int) {
  _connectRequested = true;
}

void MyWifi::beginStationConnect() {
  if (TenWiFi.isEmpty()) return;

  Serial.print("[WIFI] Dang ket noi toi: ");
  Serial.println(TenWiFi);

  WiFi.disconnect(false, true);
  delay(50);
  WiFi.begin(TenWiFi.c_str(), MatKhauWiFi.c_str());
  _connecting = true;
  _connectStartMs = millis();
  _lastRetryMs = millis();
}
//Nếu không gọi handle(), trang 192.168.4.1 có thể không phản hồi hoặc phản hồi chậm.//
void MyWifi::handle() {
  if (_portalStarted) {
    _server.handleClient();
  }
}
//Đây là hàm xử lý trạng thái WiFi theo kiểu non-blocking. Nó sẽ được gọi liên tục trong loop() để kiểm tra xem có cần bắt đầu kết nối WiFi không, có đang trong quá trình kết nối không, có bị timeout không, và có cần retry kết nối không.//
void MyWifi::process() {
  if (_connectRequested) {
    _connectRequested = false;
    beginStationConnect();
  }

  if (_connecting) {
    wl_status_t status = WiFi.status();

    if (status == WL_CONNECTED) {
      _connecting = false;
      Serial.println("[WIFI] Ket noi WiFi thanh cong.");
      Serial.print("[WIFI] STA IP: ");
      Serial.println(WiFi.localIP());
      return;
    }

    if (millis() - _connectStartMs >= CONNECT_TIMEOUT_MS) {
      _connecting = false;
      Serial.print("[WIFI] Ket noi that bai. Ly do: ");
      Serial.println(wifiStatusToText(status));
    }
    return;
  }

  if (!TenWiFi.isEmpty() && WiFi.status() != WL_CONNECTED) {
    if (millis() - _lastRetryMs >= RETRY_INTERVAL_MS) {
      Serial.println("[WIFI] Thu ket noi lai WiFi da luu...");
      beginStationConnect();
    }
  }
}

bool MyWifi::isConnected() const {
  return WiFi.status() == WL_CONNECTED;
}

String MyWifi::getStaIP() const {
  return isConnected() ? WiFi.localIP().toString() : String("0.0.0.0");
}

String MyWifi::getApIP() const {
  return WiFi.softAPIP().toString(); //trả IP của AP, thường là 192.168.4.1.
}

String MyWifi::getApSSID() const {
  return _apSsid; //trả tên AP mà ESP32 phát ra.
}

String MyWifi::getSavedSSID() const {
  return TenWiFi;
}

String MyWifi::getBackendBaseUrl() const {
  return BackendBaseUrl;
}

String MyWifi::getStatusText() const {
  return wifiStatusToText(WiFi.status());
}
//Xóa khoảng trắng đầu/cuối,Xóa dấu / ở cuối URL.
String MyWifi::normalizeUrl(const String& url) const {
  String normalized = url;
  normalized.trim();
  while (normalized.endsWith("/")) {
    normalized.remove(normalized.length() - 1);
  }
  return normalized;
}
