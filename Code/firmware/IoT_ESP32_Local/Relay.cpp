#include "Relay.h"

void Relay::begin() {
  pinMode(PIN_RELAY1, OUTPUT);
  pinMode(PIN_RELAY2, OUTPUT);
  pinMode(PIN_RELAY3, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  allOff();
}

void Relay::setRelay1(bool on) {
  if (k1 == on) return;
  k1 = on;
  digitalWrite(PIN_RELAY1, on ? HIGH : LOW);
}

void Relay::setRelay2(bool on) {
  if (k2 == on) return;
  k2 = on;
  digitalWrite(PIN_RELAY2, on ? HIGH : LOW);
}

void Relay::setRelay3(bool on) {
  if (k3 == on) return;
  k3 = on;
  digitalWrite(PIN_RELAY3, on ? HIGH : LOW);
}

void Relay::setBuzzer(bool on) {
  if (buzzer == on) return;
  buzzer = on;
  digitalWrite(PIN_BUZZER, on ? HIGH : LOW);
}

void Relay::allOff() {
  k1 = k2 = k3 = buzzer = false;
  digitalWrite(PIN_RELAY1, LOW);
  digitalWrite(PIN_RELAY2, LOW);
  digitalWrite(PIN_RELAY3, LOW);
  digitalWrite(PIN_BUZZER, LOW);
}
