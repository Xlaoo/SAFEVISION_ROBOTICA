
#include <WiFi.h>
#include <WebServer.h>

const char* WIFI_SSID = "SAFEVISION_EPP";
const char* WIFI_PASSWORD = "SafeVision123";

IPAddress IP_GUANTE(192, 168, 4, 12);
IPAddress GATEWAY(192, 168, 4, 1);
IPAddress SUBNET(255, 255, 255, 0);
IPAddress DNS(192, 168, 4, 1);

const int PIN_BROCHE = 2;

WebServer server(80);

int ultimoEstado = -1;
bool servidorIniciado = false;
unsigned long ultimoIntentoWiFi = 0;

String obtenerEstadoGuante() {
  return digitalRead(PIN_BROCHE) == LOW
      ? "PUESTO"
      : "RETIRADO";
}

void manejarEstado() {
  int lectura = digitalRead(PIN_BROCHE);
  String estado = lectura == LOW ? "PUESTO" : "RETIRADO";

  String json = "{";
  json += "\"epp\":\"GUANTE_DERECHO\",";
  json += "\"estado\":\"" + estado + "\",";
  json += "\"sensor\":" + String(lectura) + ",";
  json += "\"broche\":\"";
  json += lectura == LOW ? "ABROCHADO" : "DESABROCHADO";
  json += "\",";
  json += "\"conectado\":true";
  json += "}";

  server.send(200, "application/json", json);

  Serial.println();
  Serial.println("SOLICITUD /estado");
  Serial.print("GPIO 2: ");
  Serial.println(lectura);
  Serial.print("GUANTE DERECHO: ");
  Serial.println(estado);
  Serial.print("RESPUESTA: ");
  Serial.println(json);
}

void manejarPing() {
  server.send(
    200,
    "application/json",
    "{\"ok\":true,\"epp\":\"GUANTE_DERECHO\"}"
  );
}

void manejarInicio() {
  String html = "<h1>SAFE VISION EPP</h1>";
  html += "<h2>GUANTE DERECHO</h2>";
  html += "<p>IP: 192.168.4.12</p>";
  html += "<p>Estado: " + obtenerEstadoGuante() + "</p>";
  html += "<p><a href='/estado'>Consultar estado</a></p>";
  html += "<p><a href='/ping'>Probar conexion</a></p>";

  server.send(200, "text/html", html);
}

void iniciarServidor() {
  if (servidorIniciado) return;

  server.on("/", HTTP_GET, manejarInicio);
  server.on("/estado", HTTP_GET, manejarEstado);
  server.on("/ping", HTTP_GET, manejarPing);

  server.begin();
  servidorIniciado = true;

  Serial.println();
  Serial.println("========================================");
  Serial.println("SERVIDOR GUANTE DERECHO INICIADO");
  Serial.println("IP: http://192.168.4.12");
  Serial.println("ESTADO: http://192.168.4.12/estado");
  Serial.println("PING: http://192.168.4.12/ping");
  Serial.println("========================================");
}

void eventoWiFi(WiFiEvent_t event, WiFiEventInfo_t info) {
  switch (event) {
    case ARDUINO_EVENT_WIFI_STA_CONNECTED:
      Serial.println("[WIFI] ASOCIADO AL CASCO");
      break;

    case ARDUINO_EVENT_WIFI_STA_GOT_IP:
      Serial.print("[WIFI] IP OBTENIDA: ");
      Serial.println(WiFi.localIP());
      break;

    case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
      Serial.print("[WIFI] DESCONECTADO - REASON CODE: ");
      Serial.println(info.wifi_sta_disconnected.reason);
      break;

    default:
      break;
  }
}

void conectarWiFi() {
  Serial.println();
  Serial.println("========================================");
  Serial.println("SAFE VISION EPP - GUANTE DERECHO");
  Serial.println("========================================");

  WiFi.mode(WIFI_STA);
  delay(500);

  // Misma potencia que funciono en el CHALECO C3
  WiFi.setTxPower(WIFI_POWER_8_5dBm);

  Serial.println("CONFIGURANDO IP FIJA...");

  if (WiFi.config(IP_GUANTE, GATEWAY, SUBNET, DNS)) {
    Serial.println("IP FIJA CONFIGURADA: 192.168.4.12");
  } else {
    Serial.println("ERROR CONFIGURANDO IP FIJA");
  }

  Serial.println("CONECTANDO AL CASCO...");
  Serial.print("SSID: ");
  Serial.println(WIFI_SSID);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long inicio = millis();

  while (
    WiFi.status() != WL_CONNECTED &&
    millis() - inicio < 15000
  ) {
    delay(500);
    Serial.print(".");
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("WIFI CONECTADO CORRECTAMENTE");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
    Serial.print("GATEWAY: ");
    Serial.println(WiFi.gatewayIP());
    Serial.print("RSSI: ");
    Serial.println(WiFi.RSSI());

    iniciarServidor();
  } else {
    Serial.println("NO SE PUDO CONECTAR AL CASCO");
    Serial.println("SE REINTENTARA AUTOMATICAMENTE");
  }
}

void setup() {
  Serial.begin(115200);
  delay(2000);

  pinMode(PIN_BROCHE, INPUT_PULLUP);

  WiFi.onEvent(eventoWiFi);

  ultimoEstado = digitalRead(PIN_BROCHE);

  Serial.println();
  Serial.println("========================================");
  Serial.println("SENSOR BROCHE - GUANTE DERECHO");
  Serial.println("GPIO 2");
  Serial.println("========================================");

  if (ultimoEstado == LOW) {
    Serial.println("GUANTE ABROCHADO");
    Serial.println("ESTADO: PUESTO");
  } else {
    Serial.println("GUANTE DESABROCHADO");
    Serial.println("ESTADO: RETIRADO");
  }

  conectarWiFi();
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!servidorIniciado) {
      iniciarServidor();
    }

    server.handleClient();
  } else {
    if (millis() - ultimoIntentoWiFi >= 5000) {
      ultimoIntentoWiFi = millis();

      Serial.println("INTENTANDO RECONECTAR AL CASCO...");

      WiFi.reconnect();
    }
  }

  int lectura = digitalRead(PIN_BROCHE);

  if (lectura != ultimoEstado) {
    delay(30);
    lectura = digitalRead(PIN_BROCHE);

    if (lectura != ultimoEstado) {
      ultimoEstado = lectura;

      Serial.println();
      Serial.println("----------------------------------------");
      Serial.println("CAMBIO DETECTADO EN GUANTE DERECHO");
      Serial.print("GPIO 2 = ");
      Serial.println(lectura);

      if (lectura == LOW) {
        Serial.println("GUANTE ABROCHADO");
        Serial.println("GUANTE DERECHO: PUESTO");
      } else {
        Serial.println("GUANTE DESABROCHADO");
        Serial.println("GUANTE DERECHO: RETIRADO");
      }

      Serial.println("----------------------------------------");
    }
  }

  delay(50);
}
