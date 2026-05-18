#include "MySHT31.h"

void SHT3x::begin() {
  Wire.begin(SHT31_SDA_PIN, SHT31_SCL_PIN);
  if (!_sht31.begin(SHT31_ADDRESS)) {
    Serial.println("[SHT31] Khong tim thay cam bien!");
  } else {
    Serial.println("[SHT31] Khoi tao thanh cong.");
  }
}

void SHT3x::read() {
  float t = _sht31.readTemperature();
  float h = _sht31.readHumidity();
  if (!isnan(t)) temperature = t;
  if (!isnan(h)) humidity    = h;
}
