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
// POLARIDAD DEL SENSOR
// ==========================================================
// Con INPUT_PULLUP:
// LOW  = BROCHE CERRADO / CONTACTO A GND = GUANTE ABROCHADO -> PUESTO
// HIGH = BROCHE ABIERTO = GUANTE DESABROCHADO -> RETIRADO
// Si tu sensor físico tiene polaridad invertida (activo en HIGH),
// simplemente cambia ESTADO_PUESTO_VALOR a HIGH.
// ==========================================================

const int ESTADO_PUESTO_VALOR = LOW;

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

  if (lectura == ESTADO_PUESTO_VALOR)
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

  if (lectura == ESTADO_PUESTO_VALOR)
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
  Serial.print("[HTTP] Servidor iniciado a millis: ");
  Serial.println(millis());

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
      Serial.println(
        info.wifi_sta_disconnected.reason
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
    "CONECTANDO A RED DE LA CENTRAL"
  );
  Serial.println(
    "========================================"
  );
  Serial.print(
    "SSID: "
  );
  Serial.println(
    WIFI_SSID
  );

  WiFi.mode(
    WIFI_STA
  );
  WiFi.setAutoReconnect(true);
  WiFi.setSleep(false);
  delay(100);

  WiFi.setTxPower(
    WIFI_POWER_8_5dBm
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
      "IP FIJA: 192.168.4.13"
    );
  }
  else
  {
    Serial.println(
      "ERROR CONFIGURANDO IP"
    );
  }

  Serial.print("[WIFI] Inicio WiFi.begin a millis: ");
  Serial.println(millis());

  WiFi.begin(
    WIFI_SSID,
    WIFI_PASSWORD
  );

  int intentos = 0;
  // Verificación rápida cada 100 ms (hasta 150 intentos = 15 s timeout máximo)
  while (
    WiFi.status() != WL_CONNECTED
    &&
    intentos < 150
  )
  {
    delay(100);
    if (intentos % 10 == 0)
    {
      Serial.print(".");
    }
    intentos++;
  }

  Serial.println();
  Serial.print("[WIFI] Fin conexion a millis: ");
  Serial.print(millis());
  Serial.print(" | Intentos (x100ms): ");
  Serial.println(intentos);

  if (
    WiFi.status() == WL_CONNECTED
  )
  {
    Serial.print("[WIFI] Confirmado WL_CONNECTED a millis: ");
    Serial.println(millis());
    Serial.println();

    Serial.println(
      "========================================"
    );
    Serial.println(
      "GUANTE IZQUIERDO CONECTADO A LA CENTRAL"
    );
    Serial.println(
      "========================================"
    );

    Serial.print("IP: "); Serial.println(WiFi.localIP());
    Serial.print("GATEWAY: "); Serial.println(WiFi.gatewayIP());
    Serial.print("RSSI: "); Serial.println(WiFi.RSSI());
    Serial.println(
      "========================================"
    );
  }
  else
  {
    Serial.println();
    Serial.println(
      "❌ NO SE PUDO CONECTAR AL CASCO"
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

  delay(200);

  Serial.println();
  Serial.print("[BOOT GUANTE_I] Inicio setup a millis: ");
  Serial.println(millis());
  Serial.println(
    "========================================"
  );
  Serial.println(
    "INICIANDO GUANTE IZQUIERDO SAFEVISION"
  );
  Serial.println(
    "========================================"
  );

  WiFi.onEvent(
    eventoWiFi
  );

  pinMode(
    PIN_BROCHE,
    INPUT_PULLUP
  );

  ultimoEstado =
    digitalRead(
      PIN_BROCHE
    );

  Serial.println(
    "SENSOR BROCHE - GUANTE IZQUIERDO"
  );
  Serial.println(
    "GPIO 2"
  );
  Serial.print(
    "GPIO 2 = "
  );
  Serial.println(
    ultimoEstado
  );

  if (
    ultimoEstado == ESTADO_PUESTO_VALOR
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

  conectarWiFi();
  iniciarServidor();
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
    server.handleClient();
  }

  // ========================================================
  // RECONEXION WIFI CONTROLADA NO BLOQUEANTE
  // ========================================================

  else
  {
    static unsigned long
      ultimoIntentoWiFi = 0;

    if (
      millis() -
      ultimoIntentoWiFi >= 5000
    )
    {
      ultimoIntentoWiFi =
        millis();

      Serial.println();
      Serial.print("[WIFI] RECONECTANDO GUANTE IZQUIERDO AL CASCO... millis: ");
      Serial.println(millis());

      WiFi.reconnect();
    }
  }

  // ========================================================
  // LEER BROCHE DE FORMA RESPONSIVA
  // ========================================================

  static unsigned long ultimaLectura = 0;
  if (
    millis() - ultimaLectura >= 50
  )
  {
    ultimaLectura = millis();

    int lectura =
      digitalRead(
        PIN_BROCHE
      );

    if (
      lectura != ultimoEstado
    )
    {
      // Antirrebote rápido
      delay(30);

      lectura =
        digitalRead(
          PIN_BROCHE
        );

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

      if (
        lectura == ESTADO_PUESTO_VALOR
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

  delay(10);
}