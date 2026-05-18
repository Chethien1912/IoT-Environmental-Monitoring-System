#ifndef RTC_H
#define RTC_H

#include <Arduino.h>
#include <DS3231.h>

struct ThoiGian {
  int thu   = 0;
  int ngay  = 1;
  int thang = 1;
  int nam   = 2024;
  int gio   = 0;
  int phut  = 0;
  int giay  = 0;
};

class RTC {
 public:
  ThoiGian dt;

  void begin(); //khởi tạo RTC, đọc thời gian từ DS3231.
  bool isValid() const; //kiểm tra dữ liệu thời gian hiện tại có hợp lệ không.
  void readFromDS3231(); //đọc thời gian từ module DS3231 vào biến dt
  void writeToDS3231(); // ghi thời gian từ biến dt xuống module DS3231
  bool syncFromNtp(long gmtOffsetSeconds, int daylightOffsetSeconds); //lấy giờ từ internet bằng NTP, sau đó ghi vào DS3231.
  void setManual(int thu, int ngay, int thang, int nam, int gio, int phut, int giay); //đặt giờ thủ công rồi ghi vào DS3231.

 private:
  DS3231 _ds;
};

#endif
