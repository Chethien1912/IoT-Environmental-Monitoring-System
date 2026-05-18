#ifndef NO2_H
#define NO2_H

#include <Arduino.h>

class NO2Sensor {
 public:
  explicit NO2Sensor(uint8_t pin, float supplyVoltage = 3.3f);
  void begin() const;
  float readPpm();

 private:
  uint8_t _pin;
  float _supplyVoltage;
};

#endif
