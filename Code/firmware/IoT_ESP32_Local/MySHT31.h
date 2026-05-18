#ifndef MY_SHT31_H
#define MY_SHT31_H

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_SHT31.h>

#define SHT31_ADDRESS 0x44
#define SHT31_SDA_PIN 21
#define SHT31_SCL_PIN 22

class SHT3x {
 public:
  float temperature = NAN;
  float humidity    = NAN;

  void begin();
  void read();

 private:
  Adafruit_SHT31 _sht31;
};

#endif
