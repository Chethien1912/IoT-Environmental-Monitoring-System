#include "AppController.h"

AppController app;

void setup() {
  app.begin();
  app.startTasks();
  
  
}

void loop() {
  vTaskDelay(pdMS_TO_TICKS(1000));
}