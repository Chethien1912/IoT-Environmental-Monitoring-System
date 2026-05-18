#include "RTC.h"
#include <time.h>

void RTC::begin() {
  // DS3231 dùng I2C – Wire.begin() đã gọi trong SHT31::begin()
  readFromDS3231();
  Serial.println("[RTC] Khoi tao xong.");
}

bool RTC::isValid() const {
  return dt.nam >= 2026 && dt.nam <= 2099 &&
         dt.thang >= 1  && dt.thang <= 12  &&
         dt.ngay  >= 1  && dt.ngay  <= 31  &&
         dt.gio   >= 0  && dt.gio   <= 23  &&
         dt.phut  >= 0  && dt.phut  <= 59  &&
         dt.giay  >= 0  && dt.giay  <= 59;
}
//-----Hàm này đọc toàn bộ thời gian từ DS3231-----//
void RTC::readFromDS3231() {
  bool century = false; // dùng khi đọc tháng/năm để biết có qua thế kỷ hay chưa
  bool h12, pm; // cho biết DS3231 đang ở chế độ 12 giờ hay 24 giờ. nếu dùng 12 giờ thì cho biết AM/PM.
  dt.thu   = _ds.getDoW();
  dt.ngay  = _ds.getDate();
  dt.thang = _ds.getMonth(century);
  dt.nam   = _ds.getYear() + 2000;
  dt.gio   = _ds.getHour(h12, pm);
  dt.phut  = _ds.getMinute();
  dt.giay  = _ds.getSecond();
}

void RTC::writeToDS3231() {
  _ds.setClockMode(false);
  _ds.setYear(dt.nam - 2000);
  _ds.setMonth(dt.thang);
  _ds.setDate(dt.ngay);
  _ds.setDoW(dt.thu);
  _ds.setHour(dt.gio);
  _ds.setMinute(dt.phut);
  _ds.setSecond(dt.giay);
  Serial.println("[RTC] Da ghi vao DS3231.");
}

bool RTC::syncFromNtp(long gmtOffsetSeconds, int daylightOffsetSeconds) {
  // mẫu code dùng: syncFromNtp(25200, 0); có nghĩa dùng giờ Việt Nam, không cộng giờ mùa hè, lấy giờ từ Internet
  configTime( // cấu hình NTP server để ESP32 lấy giờ từ internet.
    gmtOffsetSeconds,// gmtOffsetSeconds: độ lệch múi giờ so với UTC, tính bằng giây vd: Việt Nam là UTC+7, nên thường là 7 * 3600 = 25200
    daylightOffsetSeconds, // daylightOffsetSeconds: daylight saving time. Việt Nam không dùng DST, nên thường là 0.
    "pool.ntp.org", // Đây là 3 server thời gian, ESP32 sẽ dùng một trong các server đó để lấy giờ.
    "time.nist.gov",
    "asia.pool.ntp.org"
  );

  struct tm timeInfo = {};//à cấu trúc thời gian chuẩn của C/C++: ngay thang... = {} nghĩa là khởi tạo rỗng, đưa mọi trường về 0.
  // vd tm_year = 126 nghĩa là năm 2026, tm_mon = 0 nghĩa là tháng 1
  if (!getLocalTime(&timeInfo, 5000)) { // Nó yêu cầu ESP32 lấy thời gian hiện tại đã được xử lý theo múi giờ, rồi ghi vào timeInfo., Là thời gian chờ tối đa: 5000 ms = 5 giây, ESP32 sẽ cố lấy giờ trong vòng 5 giây
    return false;
  }

  dt.thu = timeInfo.tm_wday == 0 ? 7 : timeInfo.tm_wday; //nếu tm_wday == 0 thì cho thành 7 0 là chủ nhật, 1 thứ 2, 2 thứ 3...
  dt.ngay = timeInfo.tm_mday;
  dt.thang = timeInfo.tm_mon + 1; //tháng bắt đầu từ 0, nên +1 để đúng vd tháng 1: 0+1=1.
  dt.nam = timeInfo.tm_year + 1900; // năm bắt đầu từ 1900, nên năm=năm đọc+1900 vd 2026=126+1900
  dt.gio = timeInfo.tm_hour;
  dt.phut = timeInfo.tm_min;
  dt.giay = timeInfo.tm_sec;
  writeToDS3231();
  return true;
}

void RTC::setManual(int thu, int ngay, int thang, int nam,
                    int gio, int phut, int giay) {
  dt.thu   = thu;
  dt.ngay  = ngay;
  dt.thang = thang;
  dt.nam   = nam;
  dt.gio   = gio;
  dt.phut  = phut;
  dt.giay  = giay;
  writeToDS3231();
}
