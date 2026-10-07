#include <WiFi.h>
#include <WebServer.h>

// ==========================================================
// SAFE VISION EPP
// ESP32-C3 - GUANTE IZQUIERDO
// ==========================================================

const char* WIFI_SSID = "SAFEVISION_EPP";
const char* WIFI_PASSWORD = "SafeVision123";

// ==========================================================
// RED SAFE VISION
// ==========================================================
//
// CASCO CENTRAL:     192.168.4.1
// CHALECO:           192.168.4.10
// LENTES:            192.168.4.11
// GUANTE DERECHO:    192.168.4.12
// GUANTE IZQUIERDO:  192.168.4.13
//
// ==========================================================

// ==========================================================
// IP FIJA DEL GUANTE IZQUIERDO
// ==========================================================

IPAddress IP_GUANTE(
  192,
  168,
  4,
  13
);

// ==========================================================
// GATEWAY = CASCO CENTRAL
// ==========================================================

IPAddress GATEWAY(
  192,
  168,
  4,
  1
);

// ==========================================================
// MASCARA DE RED
// ==========================================================

IPAddress SUBNET(
  255,
  255,
  255,
  0
);

// ==========================================================
// DNS
// ==========================================================

IPAddress DNS(
  192,
  168,
  4,
  1
);

// ==========================================================
// SENSOR DEL BROCHE
// ==========================================================
//
// GPIO 2
//
// LOW  = BROCHE CERRADO
//      = GUANTE ABROCHADO
//      = PUESTO
//
// HIGH = BROCHE ABIERTO
//      = GUANTE DESABROCHADO
//      = RETIRADO
//
// IMPORTANTE:
//
// PUESTO / RETIRADO = ESTADO FISICO
// CONECTADO / DESCONECTADO = ESTADO WIFI
//
// RETIRADO NO SIGNIFICA DESCONECTADO.
//
// ==========================================================

const int PIN_BROCHE = 2;

// ==========================================================
// SERVIDOR WEB
// ==========================================================

WebServer server(80);

// ==========================================================
// VARIABLES
// ==========================================================

int ultimoEstado = -1;

bool servidorIniciado = false;

unsigned long ultimoIntentoWiFi = 0;

// ==========================================================
// OBTENER ESTADO DEL GUANTE
// ==========================================================

String obtenerEstadoGuante()
{
  int lectura =
    digitalRead(
      PIN_BROCHE
    );

  if (lectura == LOW)
  {
    return "PUESTO";
  }

  return "RETIRADO";
}

// ==========================================================
// ENDPOINT /estado
// ==========================================================

void manejarEstado()
{
  int lectura =
    digitalRead(
      PIN_BROCHE
    );

  String estado;

  String broche;

  // ========================================================
  // ESTADO FISICO
  // ========================================================

  if (lectura == LOW)
  {
    estado = "PUESTO";
    broche = "ABROCHADO";
  }
  else
  {
    estado = "RETIRADO";
    broche = "DESABROCHADO";
  }

  // ========================================================
  // JSON PARA EL CASCO
  // ========================================================

  String json = "{";

  json +=
    "\"epp\":\"GUANTE_IZQUIERDO\",";

  json +=
    "\"estado\":\"" +
    estado +
    "\",";

  json +=
    "\"sensor\":" +
    String(lectura) +
    ",";

  json +=
    "\"broche\":\"" +
    broche +
    "\",";

  json +=
    "\"conectado\":true";

  json += "}";

  // ========================================================
  // RESPUESTA HTTP
  // ========================================================

  server.send(
    200,
    "application/json",
    json
  );

  // ========================================================
  // MONITOR SERIE
  // ========================================================

  Serial.println();

  Serial.println(
    "========================================"
  );

  Serial.println(
    "SOLICITUD /estado - GUANTE IZQUIERDO"
  );

  Serial.println(
    "========================================"
  );

  Serial.print(
    "GPIO 2 = "
  );

  Serial.println(
    lectura
  );

  Serial.print(
    "BROCHE: "
  );

  Serial.println(
    broche
  );

  Serial.print(
    "GUANTE IZQUIERDO: "
  );

  Serial.println(
    estado
  );

  Serial.print(
    "RESPUESTA: "
  );

  Serial.println(
    json
  );

  Serial.println(
    "========================================"
  );
}

// ==========================================================
// ENDPOINT /ping
// ==========================================================

void manejarPing()
{
  server.send(
    200,
    "application/json",
    "{\"ok\":true,\"epp\":\"GUANTE_IZQUIERDO\"}"
  );

  Serial.println(
    "PING RECIBIDO - GUANTE IZQUIERDO"
  );
}

// ==========================================================
// PAGINA PRINCIPAL
// ==========================================================

void manejarInicio()
{
  String html =
    "<h1>SAFE VISION EPP</h1>";

  html +=
    "<h2>GUANTE IZQUIERDO</h2>";

  html +=
    "<p>IP: 192.168.4.13</p>";

  html +=
    "<p>GPIO SENSOR: 2</p>";

  html +=
    "<p>Estado: ";

  html +=
    obtenerEstadoGuante();

  html +=
    "</p>";

  html +=
    "<p><a href='/estado'>"
    "Consultar estado"
    "</a></p>";

  html +=
    "<p><a href='/ping'>"
    "Probar conexion"
    "</a></p>";

  server.send(
    200,
    "text/html",
    html
  );
}

// ==========================================================
// INICIAR SERVIDOR
// ==========================================================

void iniciarServidor()
{
  if (servidorIniciado)
  {
    return;
  }

  server.on(
    "/",
    HTTP_GET,
    manejarInicio
  );

  server.on(
    "/estado",
    HTTP_GET,
    manejarEstado
  );

  server.on(
    "/ping",
    HTTP_GET,
    manejarPing
  );

  server.begin();

  servidorIniciado = true;

  Serial.println();

  Serial.println(
    "========================================"
  );

  Serial.println(
    "SERVIDOR GUANTE IZQUIERDO INICIADO"
  );

  Serial.println(
    "========================================"
  );

  Serial.println(
    "IP: http://192.168.4.13"
  );

  Serial.println(
    "ESTADO: http://192.168.4.13/estado"
  );

  Serial.println(
    "PING: http://192.168.4.13/ping"
  );

  Serial.println(
    "SENSOR: GPIO 2"
  );

  Serial.println(
    "========================================"
  );
}

// ==========================================================
// EVENTOS WIFI
// ==========================================================

void eventoWiFi(
  WiFiEvent_t event,
  WiFiEventInfo_t info
)
{
  switch (event)
  {
    // ======================================================
    // CONECTADO AL AP
    // ======================================================

    case ARDUINO_EVENT_WIFI_STA_CONNECTED:

      Serial.println();

      Serial.println(
        "========================================"
      );

      Serial.println(
        "[WIFI] GUANTE IZQUIERDO ASOCIADO AL CASCO"
      );

      Serial.println(
        "========================================"
      );

      break;

    // ======================================================
    // IP OBTENIDA
    // ======================================================

    case ARDUINO_EVENT_WIFI_STA_GOT_IP:

      Serial.println();

      Serial.println(
        "========================================"
      );

      Serial.print(
        "[WIFI] IP OBTENIDA: "
      );

      Serial.println(
        WiFi.localIP()
      );

      Serial.println(
        "========================================"
      );

      break;

    // ======================================================
    // WIFI DESCONECTADO
    // ======================================================

    case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:

      Serial.println();

      Serial.println(
        "========================================"
      );

      Serial.println(
        "[WIFI] GUANTE IZQUIERDO DESCONECTADO"
      );

      Serial.print(
        "REASON CODE: "
      );

      Serial.print(
        info.wifi_sta_disconnected.reason
      );

      Serial.print(
        " - "
      );

      Serial.println(
        WiFi.STA.disconnectReasonName(
          (wifi_err_reason_t)
          info.wifi_sta_disconnected.reason
        )
      );

      Serial.println(
        "========================================"
      );

      break;

    default:

      break;
  }
}

// ==========================================================
// CONECTAR AL WIFI DEL CASCO
// ==========================================================

void conectarWiFi()
{
  Serial.println();

  Serial.println(
    "========================================"
  );

  Serial.println(
    "SAFE VISION EPP"
  );

  Serial.println(
    "GUANTE IZQUIERDO"
  );

  Serial.println(
    "========================================"
  );

  // ========================================================
  // ESP32-C3 EN MODO CLIENTE
  // ========================================================

  WiFi.mode(
    WIFI_STA
  );

  delay(500);

  // ========================================================
  // IMPORTANTE - ESP32-C3 SUPER MINI
  // ========================================================
  //
  // Misma potencia utilizada por los otros ESP32-C3
  // para conectarse correctamente al CASCO.
  //
  // ========================================================

  WiFi.setTxPower(
    WIFI_POWER_8_5dBm
  );

  // ========================================================
  // IP FIJA
  // ========================================================

  Serial.println(
    "CONFIGURANDO IP FIJA..."
  );

  bool configurado =
    WiFi.config(
      IP_GUANTE,
      GATEWAY,
      SUBNET,
      DNS
    );

  if (configurado)
  {
    Serial.println(
      "IP FIJA CONFIGURADA: 192.168.4.13"
    );
  }
  else
  {
    Serial.println(
      "ERROR CONFIGURANDO IP FIJA"
    );
  }

  // ========================================================
  // CONECTAR
  // ========================================================

  Serial.println();

  Serial.println(
    "CONECTANDO AL CASCO..."
  );

  Serial.print(
    "SSID: "
  );

  Serial.println(
    WIFI_SSID
  );

  WiFi.begin(
    WIFI_SSID,
    WIFI_PASSWORD
  );

  // ========================================================
  // ESPERAR CONEXION
  // ========================================================

  unsigned long inicio =
    millis();

  while (
    WiFi.status() != WL_CONNECTED
    &&
    millis() - inicio < 15000
  )
  {
    delay(500);

    Serial.print(".");
  }

  Serial.println();

  // ========================================================
  // RESULTADO
  // ========================================================

  if (
    WiFi.status() == WL_CONNECTED
  )
  {
    Serial.println();

    Serial.println(
      "========================================"
    );

    Serial.println(
      "WIFI CONECTADO CORRECTAMENTE"
    );

    Serial.println(
      "GUANTE IZQUIERDO"
    );

    Serial.println(
      "========================================"
    );

    Serial.print(
      "SSID: "
    );

    Serial.println(
      WiFi.SSID()
    );

    Serial.print(
      "IP: "
    );

    Serial.println(
      WiFi.localIP()
    );

    Serial.print(
      "GATEWAY: "
    );

    Serial.println(
      WiFi.gatewayIP()
    );

    Serial.print(
      "RSSI: "
    );

    Serial.println(
      WiFi.RSSI()
    );

    Serial.println(
      "========================================"
    );

    iniciarServidor();
  }
  else
  {
    Serial.println();

    Serial.println(
      "========================================"
    );

    Serial.println(
      "ERROR: NO SE PUDO CONECTAR AL CASCO"
    );

    Serial.println(
      "SE REINTENTARA AUTOMATICAMENTE"
    );

    Serial.println(
      "========================================"
    );
  }
}

// ==========================================================
// SETUP
// ==========================================================

void setup()
{
  Serial.begin(
    115200
  );

  delay(2000);

  // ========================================================
  // EVENTOS WIFI
  // ========================================================

  WiFi.onEvent(
    eventoWiFi
  );

  // ========================================================
  // SENSOR BROCHE
  // ========================================================

  pinMode(
    PIN_BROCHE,
    INPUT_PULLUP
  );

  // ========================================================
  // ESTADO INICIAL
  // ========================================================

  ultimoEstado =
    digitalRead(
      PIN_BROCHE
    );

  Serial.println();

  Serial.println(
    "========================================"
  );

  Serial.println(
    "SENSOR BROCHE - GUANTE IZQUIERDO"
  );

  Serial.println(
    "GPIO 2"
  );

  Serial.println(
    "========================================"
  );

  Serial.print(
    "GPIO 2 = "
  );

  Serial.println(
    ultimoEstado
  );

  if (
    ultimoEstado == LOW
  )
  {
    Serial.println(
      "GUANTE IZQUIERDO ABROCHADO"
    );

    Serial.println(
      "GUANTE IZQUIERDO: PUESTO"
    );
  }
  else
  {
    Serial.println(
      "GUANTE IZQUIERDO DESABROCHADO"
    );

    Serial.println(
      "GUANTE IZQUIERDO: RETIRADO"
    );
  }

  Serial.println(
    "========================================"
  );

  // ========================================================
  // CONECTAR AL CASCO
  // ========================================================

  conectarWiFi();
}

// ==========================================================
// LOOP
// ==========================================================

void loop()
{
  // ========================================================
  // SERVIDOR HTTP
  // ========================================================

  if (
    WiFi.status() == WL_CONNECTED
  )
  {
    if (!servidorIniciado)
    {
      iniciarServidor();
    }

    server.handleClient();
  }

  // ========================================================
  // SI SE PERDIO WIFI
  // ========================================================

  else
  {
    if (
      millis() -
      ultimoIntentoWiFi >= 5000
    )
    {
      ultimoIntentoWiFi =
        millis();

      Serial.println();

      Serial.println(
        "WIFI DESCONECTADO"
      );

      Serial.println(
        "INTENTANDO RECONECTAR AL CASCO..."
      );

      // ====================================================
      // RECONEXION COMPLETA
      // ====================================================

      WiFi.disconnect();

      delay(300);

      // Volvemos a colocar la IP fija del
      // GUANTE IZQUIERDO antes de conectar.
      WiFi.config(
        IP_GUANTE,
        GATEWAY,
        SUBNET,
        DNS
      );

      WiFi.begin(
        WIFI_SSID,
        WIFI_PASSWORD
      );
    }
  }

  // ========================================================
  // LEER SENSOR DEL BROCHE
  // ========================================================

  int lectura =
    digitalRead(
      PIN_BROCHE
    );

  // ========================================================
  // DETECTAR CAMBIO
  // ========================================================

  if (
    lectura != ultimoEstado
  )
  {
    // ======================================================
    // ANTIRREBOTE
    // ======================================================

    delay(30);

    lectura =
      digitalRead(
        PIN_BROCHE
      );

    if (
      lectura != ultimoEstado
    )
    {
      ultimoEstado =
        lectura;

      Serial.println();

      Serial.println(
        "----------------------------------------"
      );

      Serial.println(
        "CAMBIO DETECTADO EN GUANTE IZQUIERDO"
      );

      Serial.println(
        "----------------------------------------"
      );

      Serial.print(
        "GPIO 2 = "
      );

      Serial.println(
        lectura
      );

      // ====================================================
      // GUANTE ABROCHADO
      // ====================================================

      if (
        lectura == LOW
      )
      {
        Serial.println(
          "BROCHE: ABROCHADO"
        );

        Serial.println(
          "GUANTE IZQUIERDO: PUESTO"
        );

        Serial.println(
          "ESTADO: EPP COLOCADO"
        );
      }

      // ====================================================
      // GUANTE DESABROCHADO
      // ====================================================

      else
      {
        Serial.println(
          "BROCHE: DESABROCHADO"
        );

        Serial.println(
          "GUANTE IZQUIERDO: RETIRADO"
        );

        Serial.println(
          "ESTADO: EPP NO COLOCADO"
        );
      }

      Serial.println(
        "----------------------------------------"
      );
    }
  }

  delay(50);
}