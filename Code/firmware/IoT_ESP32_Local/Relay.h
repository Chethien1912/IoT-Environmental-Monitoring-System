#ifndef RELAY_H
#define RELAY_H

#include <Arduino.h>

// ── Pin mapping ────────────────────────────────────────────
#define PIN_RELAY1  17
#define PIN_RELAY2  27
#define PIN_RELAY3  26
#define PIN_BUZZER  18
// ──────────────────────────────────────────────────────────

class Relay {
 public:
  bool k1 = false;   // Relay 1 (nhiệt độ)
  bool k2 = false;   // Relay 2 (độ ẩm)
  bool k3 = false;   // Relay 3 (CO / NO2)
  bool buzzer = false;

  void begin();
  void setRelay1(bool on);
  void setRelay2(bool on);
  void setRelay3(bool on);
  void setBuzzer(bool on);
  void allOff();
};

#endif
