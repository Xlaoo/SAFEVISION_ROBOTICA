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

    Serial.println(
        "========================================"
    );

    Serial.println(
        "       SAFE VISION EPP"
    );

    Serial.println(
        "       ESP32-C3 - CHALECO"
    );

    Serial.println(
        "========================================"
    );


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


    // ======================================================
    // MODO CLIENTE
    // ======================================================

    WiFi.mode(
        WIFI_STA
    );


    // ======================================================
    // IP FIJA
    // ======================================================

    bool configurado =
        WiFi.config(
            IP_CHALECO,
            GATEWAY,
            SUBNET,
            DNS
        );


    if (configurado)
    {
        Serial.println(
            "IP FIJA CONFIGURADA"
        );
    }
    else
    {
        Serial.println(
            "ERROR CONFIGURANDO IP FIJA"
        );
    }


    // ======================================================
    // CONECTAR
    // ======================================================

    WiFi.begin(
        WIFI_SSID,
        WIFI_PASSWORD
    );


    int intentos = 0;


    while (
        WiFi.status() != WL_CONNECTED
        &&
        intentos < 30
    )
    {
        delay(500);

        Serial.print(
            "."
        );

        intentos++;
    }


    Serial.println();


    // ======================================================
    // CONECTADO
    // ======================================================

    if (
        WiFi.status() == WL_CONNECTED
    )
    {
        Serial.println();

        Serial.println(
            "========================================"
        );

        Serial.println(
            "       WIFI CONECTADO"
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
            "IP DEL CHALECO: "
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
            "========================================"
        );


        Serial.print(
            "Estado WiFi: "
        );

        Serial.println(
            WiFi.status()
        );
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


// ==========================================================
// SETUP
// ==========================================================

void setup()
{
    Serial.begin(
        115200
    );


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
    // ======================================================
    // ATENDER PETICIONES HTTP
    // ======================================================

    if (
        WiFi.status() == WL_CONNECTED
    )
    {
        server.handleClient();
    }


    // ======================================================
    // LEER SENSOR
    // ======================================================

    int lectura =
        digitalRead(
            SENSOR_CHALECO
        );


    // ======================================================
    // DETECTAR CAMBIO
    // ======================================================

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
            "CAMBIO DETECTADO EN EL CHALECO"
        );

        Serial.println(
            "----------------------------------------"
        );


        Serial.print(
            "GPIO 3 = "
        );

        Serial.println(
            lectura
        );


        // ==================================================
        // IMÁN DETECTADO
        // ==================================================

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

        // ==================================================
        // IMÁN NO DETECTADO
        // ==================================================

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
            "----------------------------------------"
        );
    }


    // ======================================================
    // SI SE PERDIÓ WIFI, RECONECTAR
    // ======================================================

    if (
        WiFi.status() != WL_CONNECTED
    )
    {
        static unsigned long
            ultimoIntento = 0;


        if (
            millis() - ultimoIntento > 5000
        )
        {
            ultimoIntento =
                millis();


            Serial.println();

            Serial.println(
                "WIFI DESCONECTADO"
            );

            Serial.println(
                "INTENTANDO RECONECTAR..."
            );


            WiFi.disconnect();


            delay(300);


            WiFi.config(
                IP_CHALECO,
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


    delay(50);
}