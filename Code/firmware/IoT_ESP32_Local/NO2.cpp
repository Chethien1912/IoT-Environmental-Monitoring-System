#include "NO2.h"
#include <math.h>

namespace {
constexpr uint8_t kSampleCount = 10;
constexpr uint8_t kSampleDelayMs = 10;
}

NO2Sensor::NO2Sensor(uint8_t pin, float supplyVoltage)
    : _pin(pin), _supplyVoltage(supplyVoltage) {}

void NO2Sensor::begin() const {
  pinMode(_pin, INPUT);
  analogSetPinAttenuation(_pin, ADC_11db);
}

float NO2Sensor::readPpm() {
  const float RL = 200.0f;
  const float R0 = 512.0f;
  const float a = 0.037f;
  const float b = 1.43f;

  int adcVal = 0;
  for (int i = 0; i < kSampleCount; i++) {
    adcVal += analogRead(_pin);
    delay(kSampleDelayMs);
  }
  adcVal /= kSampleCount;
  
  float rs = RL * (4128.0f - (float)adcVal) / adcval;
  float ratio = rs / R0;
  float ppm = a * pow(ratio, b);

  return ppm;
}
