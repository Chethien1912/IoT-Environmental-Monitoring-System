#include "CO.h"
#include <math.h>

namespace {
constexpr uint8_t kSampleCount = 50;
constexpr uint8_t kSampleDelayMs = 5;
}

COSensor::COSensor(uint8_t pin, float supplyVoltage)
    : _pin(pin), _supplyVoltage(supplyVoltage) {}

void COSensor::begin() const {
  pinMode(_pin, INPUT);
  analogReadResolution(12);
  analogSetPinAttenuation(_pin, ADC_11db);
}

float COSensor::readPpm() {
  const float RL = 10.0f;
  const float R0 = 125.0f;
  const float a = 1.0f;
  const float b = -2.512f;

  long sum = 0;
  for (int i = 0; i < kSampleCount; i++) {
    sum += analogRead(_pin);
    delay(kSampleDelayMs);
  }

  float adcAvg = (float)sum / (float)kSampleCount;
  float Vout = adcAvg * (_supplyVoltage / 4095.0f);

  if (Vout <= 0.0f) {
    return NAN;
  }

  float Rs = ((_supplyVoltage - Vout) / Vout) * RL;
  float ratio = Rs / R0;
  float ppm = a * pow(ratio, b);

  return ppm;
}
