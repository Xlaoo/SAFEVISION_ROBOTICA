#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <Adafruit_VL53L0X.h>

// ==========================================================
// SAFE VISION EPP
// ESP32-C3 - LENTES
// ==========================================================
//
// CENTRAL CASCO:
// 192.168.4.1
//
// CHALECO:
// 192.168.4.10
//
// LENTES:
// 192.168.4.11
//
// REGLA:
//
// <= 5 CM  = PUESTO
// >  5 CM  = RETIRADO
//
// Cuando está RETIRADO, Flutter posteriormente
// generará la alarma.
// ==========================================================


// ==========================================================
// WIFI CREADO POR EL CASCO
// ==========================================================

const char* WIFI_SSID =
    "SAFEVISION_EPP";

const char* WIFI_PASSWORD =
    "SafeVision123";


// ==========================================================
// IP FIJA DE LOS LENTES
// ==========================================================

IPAddress IP_LENTES(
    192,
    168,
    4,
    11
);


// ==========================================================
// CASCO = GATEWAY
// ==========================================================

IPAddress GATEWAY(
    192,
    168,
    4,
    1
);


IPAddress SUBNET(
    255,
    255,
    255,
    0
);


IPAddress DNS(
    192,
    168,
    4,
    1
);


// ==========================================================
// PINES VL53L0X
// ==========================================================

const int SDA_PIN = 6;
const int SCL_PIN = 7;


// ==========================================================
// DISTANCIA LIMITE
// ==========================================================
//
// 50 mm = 5 cm
//
// <= 50 mm = PUESTO
// >  50 mm = RETIRADO
//
// ==========================================================

const int LIMITE_LENTES_MM = 50;


// ==========================================================
// SENSOR
// ==========================================================

Adafruit_VL53L0X sensor =
    Adafruit_VL53L0X();

bool sensorIniciado = false;


// ==========================================================
// SERVIDOR
// ==========================================================

WebServer server(80);


// ==========================================================
// VARIABLES
// ==========================================================

String estadoLentes =
    "DESCONOCIDO";

String estadoAnterior =
    "DESCONOCIDO";

int distanciaMM = -1;


// ==========================================================
// LEER DISTANCIA
// ==========================================================
//
// Hacemos varias mediciones y sacamos promedio
// para evitar cambios falsos.
//
// ==========================================================

int leerDistancia()
{
    if (!sensorIniciado)
    {
        static unsigned long ultimoReintentoSensor = 0;
        if (millis() - ultimoReintentoSensor > 3000)
        {
            ultimoReintentoSensor = millis();
            sensorIniciado = sensor.begin();
        }
        if (!sensorIniciado)
        {
            return -1;
        }
    }

    VL53L0X_RangingMeasurementData_t medida;
    long suma = 0;
    int validas = 0;

    for (int i = 0; i < 2; i++)
    {
        sensor.rangingTest(
            &medida,
            false
        );

        if (medida.RangeStatus != 4 && medida.RangeMilliMeter > 0 && medida.RangeMilliMeter < 2000)
        {
            suma +=
                medida.RangeMilliMeter;

            validas++;
        }
    }

    if (validas == 0)
    {
        return -1;
    }

    return suma / validas;
}


// ==========================================================
// ACTUALIZAR ESTADO
// ==========================================================

void actualizarEstado()
{
    distanciaMM =
        leerDistancia();


    // ======================================================
    // SI EL SENSOR NO ENCUENTRA OBJETO
    //
    // Consideramos que los lentes fueron retirados.
    // ======================================================

    if (distanciaMM < 0)
    {
        estadoLentes =
            "RETIRADO";

        return;
    }


    // ======================================================
    // 5 CM O MENOS
    // ======================================================

    if (distanciaMM <= LIMITE_LENTES_MM)
    {
        estadoLentes =
            "PUESTO";
    }


    // ======================================================
    // MÁS DE 5 CM
    // ======================================================

    else
    {
        estadoLentes =
            "RETIRADO";
    }
}


// ==========================================================
// MOSTRAR MEDICION
// ==========================================================

void mostrarEstado()
{
    Serial.println();

    Serial.println(
        "========================================"
    );


    Serial.print(
        "DISTANCIA: "
    );


    if (distanciaMM >= 0)
    {
        Serial.print(
            distanciaMM
        );

        Serial.print(
            " mm | "
        );

        Serial.print(
            distanciaMM / 10.0
        );

        Serial.println(
            " cm"
        );
    }

    else
    {
        Serial.println(
            "FUERA DE RANGO"
        );
    }


    Serial.print(
        "LENTES: "
    );

    Serial.println(
        estadoLentes
    );


    if (estadoLentes == "PUESTO")
    {
        Serial.println(
            "ESTADO: CORRECTO"
        );
    }

    else
    {
        Serial.println(
            "🚨 ALERTA: LENTES RETIRADOS"
        );

        Serial.println(
            "DISTANCIA MAYOR A 5 CM"
        );
    }


    Serial.println(
        "========================================"
    );
}


// ==========================================================
// /estado
// ==========================================================

void manejarEstado()
{
    float distanciaCM =
        -1;


    if (distanciaMM >= 0)
    {
        distanciaCM =
            distanciaMM / 10.0;
    }


    // ======================================================
    // JSON PARA EL CASCO
    // ======================================================

    String json =
        "{"

        "\"epp\":\"LENTES\","

        "\"estado\":\"" +
        estadoLentes +
        "\","

        "\"distancia_mm\":" +
        String(distanciaMM) +
        ","

        "\"distancia_cm\":" +
        String(distanciaCM, 1) +
        ","

        "\"conexion\":\"CONECTADO\","

        "\"tipo\":\"SECUNDARIO\""

        "}";


    server.send(
        200,
        "application/json",
        json
    );


    Serial.println();

    Serial.println(
        "SOLICITUD /estado"
    );


    Serial.println(
        json
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
        "{\"ok\":true,\"epp\":\"LENTES\"}"
    );


    Serial.println(
        "PING RECIBIDO - LENTES"
    );
}


// ==========================================================
// PAGINA PRINCIPAL
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

<title>
SafeVisionEPP - Lentes
</title>

</head>

<body>

<h1>
SafeVisionEPP
</h1>

<h2>
ESP32-C3 - LENTES
</h2>

<p>
IP: 192.168.4.11
</p>

<p>
Sensor: VL53L0X
</p>

<p>
Limite: 5 centimetros
</p>

<p>
<a href="/estado">
Consultar estado
</a>
</p>

<p>
<a href="/ping">
Probar conexion
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
        "       LENTES"
    );

    Serial.println(
        "========================================"
    );


    Serial.println();

    Serial.println(
        "CONECTANDO A LA CENTRAL..."
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
    WiFi.setAutoReconnect(true);
    WiFi.setSleep(false);
    delay(100);
// IMPORTANTE PARA ESP32-C3 SUPER MINI
// Misma configuración que permitió conectar
// CHALECO y GUANTE al CASCO.
WiFi.setTxPower(WIFI_POWER_8_5dBm);

    // ======================================================
    // IP FIJA
    // ======================================================

    bool configurado =
        WiFi.config(
            IP_LENTES,
            GATEWAY,
            SUBNET,
            DNS
        );


    if (configurado)
    {
        Serial.println(
            "IP FIJA: 192.168.4.11"
        );
    }

    else
    {
        Serial.println(
            "ERROR CONFIGURANDO IP"
        );
    }


    // ======================================================
    // CONECTAR
    // ======================================================

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


    // ======================================================
    // RESULTADO
    // ======================================================

    if (
        WiFi.status() ==
        WL_CONNECTED
    )
    {
        Serial.print("[WIFI] Confirmado WL_CONNECTED a millis: ");
        Serial.println(millis());
        Serial.println();

        Serial.println(
            "========================================"
        );

        Serial.println(
            "LENTES CONECTADOS A LA CENTRAL"
        );

        Serial.println(
            "========================================"
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
// SERVIDOR
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
    Serial.print("[HTTP] Servidor iniciado a millis: ");
    Serial.println(millis());

    Serial.println(
        "========================================"
    );

    Serial.println(
        "SERVIDOR DE LENTES INICIADO"
    );

    Serial.println(
        "========================================"
    );


    Serial.println(
        "http://192.168.4.11"
    );

    Serial.println(
        "http://192.168.4.11/estado"
    );

    Serial.println(
        "http://192.168.4.11/ping"
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

    delay(200);

    Serial.println();
    Serial.print("[BOOT LENTES] Inicio setup a millis: ");
    Serial.println(millis());
    Serial.println(
        "========================================"
    );

    Serial.println(
        "INICIANDO LENTES SAFEVISION"
    );

    Serial.println(
        "========================================"
    );


    // ======================================================
    // I2C
    // ======================================================

    Wire.begin(
        SDA_PIN,
        SCL_PIN
    );


    // ======================================================
    // SENSOR VL53L0X
    // ======================================================

    Serial.println(
        "BUSCANDO VL53L0X..."
    );

    int reintentosSensor = 0;
    while (!sensorIniciado && reintentosSensor < 3)
    {
        sensorIniciado = sensor.begin();
        if (!sensorIniciado)
        {
            delay(100);
            reintentosSensor++;
        }
    }

    if (sensorIniciado)
    {
        Serial.println(
            "✅ VL53L0X DETECTADO"
        );
    }
    else
    {
        Serial.println(
            "⚠️ VL53L0X NO DETECTADO EN BOOT. CONTINUANDO..."
        );
    }

    // ======================================================
    // WIFI
    // ======================================================

    conectarWiFi();


    // ======================================================
    // SERVIDOR
    // ======================================================

    iniciarServidor();


    // ======================================================
    // ESTADO INICIAL
    // ======================================================

    actualizarEstado();


    estadoAnterior =
        estadoLentes;


    mostrarEstado();
}


// ==========================================================
// LOOP
// ==========================================================

void loop()
{
    // ======================================================
    // PETICIONES HTTP
    // ======================================================

    if (
        WiFi.status() ==
        WL_CONNECTED
    )
    {
        server.handleClient();
    }


    // ======================================================
    // MEDIR CADA 250 ms
    // ======================================================

    static unsigned long
        ultimaMedicion = 0;


    if (
        millis() -
        ultimaMedicion >=
        250
    )
    {
        ultimaMedicion =
            millis();


        actualizarEstado();


        // ==================================================
        // SI CAMBIA PUESTO <-> RETIRADO
        // ==================================================

        if (
            estadoLentes !=
            estadoAnterior
        )
        {
            estadoAnterior =
                estadoLentes;


            mostrarEstado();
        }
    }


    // ======================================================
    // RECONEXION WIFI CONTROLADA NO BLOQUEANTE
    // ======================================================

    if (
        WiFi.status() !=
        WL_CONNECTED
    )
    {
        static unsigned long
            ultimoIntento = 0;


        if (
            millis() -
            ultimoIntento >
            5000
        )
        {
            ultimoIntento =
                millis();


            Serial.println();
            Serial.print("[WIFI] RECONECTANDO LENTES AL CASCO... millis: ");
            Serial.println(millis());

            WiFi.reconnect();
        }
    }
    delay(10);
}