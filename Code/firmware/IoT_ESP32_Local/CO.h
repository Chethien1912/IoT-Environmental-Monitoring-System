#ifndef CO_H
#define CO_H

#include <Arduino.h>

class COSensor {
 public:
  explicit COSensor(uint8_t pin, float supplyVoltage = 3.3f);
  void begin() const;
  float readPpm();

 private:
  uint8_t _pin;
  float _supplyVoltage;
};

#endif
