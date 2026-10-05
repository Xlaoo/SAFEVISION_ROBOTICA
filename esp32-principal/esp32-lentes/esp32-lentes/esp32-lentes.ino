#include <WiFi.h>

const char* ssid = "PRUEBA_C3";
const char* password = "12345678";

void setup() {
  Serial.begin(115200);
  delay(2000);

  WiFi.mode(WIFI_STA);

  Serial.println("CONECTANDO...");
  WiFi.begin(ssid, password);

  int intentos = 0;

  while (WiFi.status() != WL_CONNECTED && intentos < 40) {
    delay(500);
    Serial.print(".");
    intentos++;
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("==========");
    Serial.println("CONECTADO");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    Serial.println("==========");
  } else {
    Serial.println("==========");
    Serial.println("NO CONECTO");
    Serial.print("WiFi.status(): ");
    Serial.println(WiFi.status());
    Serial.println("==========");
  }
}

void loop() {
}