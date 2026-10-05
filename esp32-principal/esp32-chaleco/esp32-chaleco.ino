#include <WiFi.h>
#include <WebServer.h>

// ==========================================================
// SAFE VISION EPP
// ESP32-C3 - CHALECO
// ==========================================================
//
// CASCO CENTRAL:
//     192.168.4.1
//
// CHALECO:
//     192.168.4.10
//
// SENSOR:
//     GPIO 3
//
// LÓGICA:
//     LOW  = IMÁN DETECTADO = CHALECO PUESTO
//     HIGH = IMÁN NO DETECTADO = CHALECO RETIRADO
// ==========================================================


// ==========================================================
// WIFI DEL CASCO
// ==========================================================

const char* WIFI_SSID =
    "SAFEVISION_EPP";

const char* WIFI_PASSWORD =
    "SafeVision123";


// ==========================================================
// IP FIJA DEL CHALECO
// ==========================================================

IPAddress IP_CHALECO(
    192,
    168,
    4,
    10
);


// ==========================================================
// GATEWAY = CASCO
// ==========================================================

IPAddress GATEWAY(
    192,
    168,
    4,
    1
);


// ==========================================================
// MASCARA
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
// SENSOR DEL CHALECO
// ==========================================================

const int SENSOR_CHALECO = 3;


// ==========================================================
// SERVIDOR WEB
// ==========================================================

WebServer server(80);


// ==========================================================
// ESTADO ANTERIOR
// ==========================================================

int ultimoEstado = -1;


// ==========================================================
// OBTENER ESTADO DEL CHALECO
// ==========================================================

String obtenerEstadoChaleco()
{
    int lectura =
        digitalRead(
            SENSOR_CHALECO
        );


    // IMÁN DETECTADO
    if (lectura == LOW)
    {
        return "PUESTO";
    }


    // IMÁN NO DETECTADO
    return "RETIRADO";
}


// ==========================================================
// /estado
// ==========================================================

void manejarEstado()
{
    int lectura =
        digitalRead(
            SENSOR_CHALECO
        );


    String estado;


    // ======================================================
    // LOW = IMÁN DETECTADO
    // ======================================================

    if (lectura == LOW)
    {
        estado = "PUESTO";
    }
    else
    {
        estado = "RETIRADO";
    }


    // ======================================================
    // JSON
    // ======================================================

    String json =
        "{"

        "\"epp\":\"CHALECO\","

        "\"estado\":\"" +
        estado +
        "\","

        "\"sensor\":" +
        String(lectura) +
        ","

        "\"conectado\":true"

        "}";


    // ======================================================
    // RESPONDER
    // ======================================================

    server.send(
        200,
        "application/json",
        json
    );


    // ======================================================
    // MONITOR SERIE
    // ======================================================

    Serial.println();

    Serial.println(
        "========================================"
    );

    Serial.println(
        "SOLICITUD /estado"
    );

    Serial.println(
        "========================================"
    );

    Serial.print(
        "GPIO 3 = "
    );

    Serial.println(
        lectura
    );

    Serial.print(
        "CHALECO: "
    );

    Serial.println(
        estado
    );

    Serial.print(
        "IMAN: "
    );

    if (lectura == LOW)
    {
        Serial.println(
            "DETECTADO"
        );
    }
    else
    {
        Serial.println(
            "NO DETECTADO"
        );
    }

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
// /ping
// ==========================================================

void manejarPing()
{
    server.send(
        200,
        "application/json",
        "{\"ok\":true,\"epp\":\"CHALECO\"}"
    );


    Serial.println(
        "PING recibido"
    );
}


// ==========================================================
// /
// ==========================================================

void manejarInicio()
{
    String html =
        R"rawliteral(

<!DOCTYPE html>

<html>

<head>

<meta charset="UTF-8">

<meta name="viewport"
content="width=device-width, initial-scale=1.0">

<title>SafeVision EPP</title>

</head>

<body>

<h1>SafeVision EPP</h1>

<h2>ESP32-C3 - CHALECO</h2>

<p>
Chaleco conectado a la central.
</p>

<p>
SSID: SAFEVISION_EPP
</p>

<p>
IP: 192.168.4.10
</p>

<p>
GPIO SENSOR: 3
</p>

<p>
<a href="/estado">
Consultar estado
</a>
</p>

<p>
<a href="/ping">
Probar conexión
</a>
</p>

</body>

</html>

)rawliteral";


    server.send(
        200,
        "text/html",
        html
    );
}


// ==========================================================
// CONECTAR AL WIFI DEL CASCO
// ==========================================================

void conectarWiFi()
{
    Serial.println();
    Serial.println("========================================");
    Serial.println("SAFE VISION EPP - CHALECO");
    Serial.println("========================================");

    // 1. Modo Estación
    WiFi.mode(WIFI_STA);
    delay(500);
    // SOLUCIÓN AL AUTH_EXPIRE DEL ESP32-C3 SUPER MINI
    WiFi.setTxPower(WIFI_POWER_8_5dBm);

    // 2. Configuración de IP fija
    Serial.println("CONFIGURANDO IP FIJA...");
    bool configurado = WiFi.config(
        IP_CHALECO,
        GATEWAY,
        SUBNET,
        DNS
    );

    if (configurado)
    {
        Serial.println("IP FIJA CONFIGURADA: 192.168.4.10");
    }
    else
    {
        Serial.println("ERROR CONFIGURANDO IP FIJA");
    }

    // 3. Conexión al AP del Casco
    Serial.println();
    Serial.println("CONECTANDO AL CASCO...");
    Serial.print("SSID: ");
    Serial.println(WIFI_SSID);

    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

    int intentos = 0;
    while (
        WiFi.status() != WL_CONNECTED
        && intentos < 30
    )
    {
        delay(500);
        Serial.print(".");
        intentos++;
    }

    Serial.println();

    if (WiFi.status() == WL_CONNECTED)
    {
        Serial.println();
        Serial.println("========================================");
        Serial.println("WIFI CONECTADO CORRECTAMENTE");
        Serial.println("========================================");
        Serial.print("SSID: ");
        Serial.println(WiFi.SSID());
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
        Serial.print("GATEWAY: ");
        Serial.println(WiFi.gatewayIP());
        Serial.print("RSSI: ");
        Serial.println(WiFi.RSSI());
        Serial.println("========================================");
    }
    else
    {
        Serial.println();
        Serial.println("========================================");
        Serial.println("ERROR: NO SE PUDO CONECTAR AL CASCO");
        Serial.print("WiFi.status(): ");
        Serial.println(WiFi.status());
        Serial.println("========================================");
    }
}
// ==========================================================
// INICIAR SERVIDOR
// ==========================================================

void iniciarServidor()
{
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


    Serial.println();

    Serial.println(
        "========================================"
    );

    Serial.println(
        "SERVIDOR CHALECO INICIADO"
    );

    Serial.println(
        "========================================"
    );


    Serial.println(
        "IP: http://192.168.4.10"
    );


    Serial.println(
        "ESTADO: http://192.168.4.10/estado"
    );


    Serial.println(
        "PING: http://192.168.4.10/ping"
    );


    Serial.println(
        "SENSOR: GPIO 3"
    );


    Serial.println();

    Serial.println(
        "LISTO PARA CONECTAR CON SAFE VISION EPP"
    );


    Serial.println(
        "========================================"
    );
}
void eventoWiFi(WiFiEvent_t event, WiFiEventInfo_t info)
{
    switch (event)
    {
        case ARDUINO_EVENT_WIFI_STA_START:
            Serial.println("[WIFI] STA INICIADA");
            break;

        case ARDUINO_EVENT_WIFI_STA_CONNECTED:
            Serial.println();
            Serial.println("========================================");
            Serial.println("[WIFI] ASOCIADO AL CASCO");
            Serial.print("SSID: ");
            Serial.println((char*)info.wifi_sta_connected.ssid);
            Serial.printf("BSSID AP: %02X:%02X:%02X:%02X:%02X:%02X\n",
                info.wifi_sta_connected.bssid[0], info.wifi_sta_connected.bssid[1],
                info.wifi_sta_connected.bssid[2], info.wifi_sta_connected.bssid[3],
                info.wifi_sta_connected.bssid[4], info.wifi_sta_connected.bssid[5]);
            Serial.print("CANAL: ");
            Serial.println(info.wifi_sta_connected.channel);
            Serial.println("========================================");
            break;

        case ARDUINO_EVENT_WIFI_STA_GOT_IP:
            Serial.println();
            Serial.println("========================================");
            Serial.print("[WIFI] IP OBTENIDA: ");
            Serial.println(WiFi.localIP());
            Serial.println("========================================");
            break;

        case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
            Serial.println();
            Serial.println("========================================");
            Serial.println("[WIFI] DESCONECTADO");
            Serial.print("REASON CODE: ");
            Serial.print(info.wifi_sta_disconnected.reason);
            Serial.print(" - ");
            Serial.println(WiFi.STA.disconnectReasonName((wifi_err_reason_t)info.wifi_sta_disconnected.reason));
            Serial.println("========================================");
            break;

        default:
            break;
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
    WiFi.onEvent(eventoWiFi);

    delay(2000);


    // ======================================================
    // SENSOR MAGNÉTICO
    // ======================================================
    //
    // IMPORTANTE:
    //
    // INPUT_PULLUP es el mismo modo que probaste
    // y confirmó que el sensor detecta correctamente.
    // ======================================================

    pinMode(
        SENSOR_CHALECO,
        INPUT_PULLUP
    );


    Serial.println();

    Serial.println(
        "========================================"
    );

    Serial.println(
        "SENSOR MAGNETICO DEL CHALECO"
    );

    Serial.println(
        "GPIO 3"
    );

    Serial.println(
        "========================================"
    );


    // ======================================================
    // CONECTAR AL CASCO
    // ======================================================

    conectarWiFi();


    // ======================================================
    // INICIAR SERVIDOR
    // ======================================================

    if (
        WiFi.status() == WL_CONNECTED
    )
    {
        iniciarServidor();
    }


    // ======================================================
    // ESTADO INICIAL
    // ======================================================

    int lectura =
        digitalRead(
            SENSOR_CHALECO
        );


    ultimoEstado =
        lectura;


    Serial.println();

    Serial.println(
        "========================================"
    );

    Serial.println(
        "ESTADO INICIAL DEL CHALECO"
    );

    Serial.println(
        "========================================"
    );


    Serial.print(
        "GPIO 3 = "
    );

    Serial.println(
        lectura
    );


    if (
        lectura == LOW
    )
    {
        Serial.println(
            "IMAN: DETECTADO"
        );

        Serial.println(
            "CHALECO: PUESTO"
        );

        Serial.println(
            "ESTADO: EPP COLOCADO"
        );
    }
    else
    {
        Serial.println(
            "IMAN: NO DETECTADO"
        );

        Serial.println(
            "CHALECO: RETIRADO"
        );

        Serial.println(
            "ESTADO: EPP NO COLOCADO"
        );
    }


    Serial.println(
        "========================================"
    );
}


// ==========================================================
// LOOP
// ==========================================================

void loop()
{
    if (WiFi.status() == WL_CONNECTED)
    {
        server.handleClient();
    }

    int lectura = digitalRead(SENSOR_CHALECO);

    if (lectura != ultimoEstado)
    {
        ultimoEstado = lectura;

        Serial.println();
        Serial.println("----------------------------------------");
        Serial.println("CAMBIO DETECTADO EN EL CHALECO");
        Serial.println("----------------------------------------");

        Serial.print("GPIO 3 = ");
        Serial.println(lectura);

        if (lectura == LOW)
        {
            Serial.println("IMAN: DETECTADO");
            Serial.println("CHALECO: PUESTO");
            Serial.println("ESTADO: EPP COLOCADO");
        }
        else
        {
            Serial.println("IMAN: NO DETECTADO");
            Serial.println("CHALECO: RETIRADO");
            Serial.println("ESTADO: EPP NO COLOCADO");
        }

        Serial.println("----------------------------------------");
    }

    // ======================================================
    // SI SE PERDIÓ WIFI, RECONECTAR
    // ======================================================
   if (WiFi.status() != WL_CONNECTED)
    {
        static unsigned long ultimoIntento = 0;
        if (millis() - ultimoIntento > 5000)
        {
            ultimoIntento = millis();
            Serial.println();
            Serial.println("WIFI DESCONECTADO");
            Serial.println("INTENTANDO RECONECTAR...");
            WiFi.disconnect();
            delay(300);
            WiFi.config(IP_CHALECO, GATEWAY, SUBNET, DNS);
            WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
        }
    }

    delay(50);
}