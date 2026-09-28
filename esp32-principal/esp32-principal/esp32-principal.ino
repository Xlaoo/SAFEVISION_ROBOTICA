#include <HTTPClient.h>
#include <WiFi.h>
#include <WebServer.h>

// ==========================================================
// SAFE VISION EPP
// ESP32 CENTRAL - CASCO
// ==========================================================
//
// CENTRAL:
// 192.168.4.1
//
// CHALECO:
// 192.168.4.10
//
// LENTES:
// 192.168.4.11
//
// ==========================================================


// ==========================================================
// WIFI CREADO POR EL CASCO
// ==========================================================

const char* AP_SSID = "SAFEVISION_EPP";
const char* AP_PASSWORD = "SafeVision123";


// ==========================================================
// IP CENTRAL
// ==========================================================

IPAddress IP_CENTRAL(
    192,
    168,
    4,
    1
);

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


// ==========================================================
// SENSOR CASCO
// ==========================================================

const int SENSOR_CASCO = 4;


// ==========================================================
// SERVIDOR
// ==========================================================

WebServer server(80);


// ==========================================================
// ESTADO ANTERIOR CASCO
// ==========================================================

int ultimoEstado = -1;


// ==========================================================
// EXTRAER TEXTO DE JSON
//
// Ejemplo:
//
// "estado":"PUESTO"
//
// ==========================================================

String extraerTexto(
    const String& json,
    const String& campo
)
{
    String patron =
        "\"" +
        campo +
        "\":\"";

    int posicion =
        json.indexOf(
            patron
        );

    if (posicion < 0)
    {
        return "";
    }

    int inicio =
        posicion +
        patron.length();

    int fin =
        json.indexOf(
            "\"",
            inicio
        );

    if (fin < 0)
    {
        return "";
    }

    return json.substring(
        inicio,
        fin
    );
}


// ==========================================================
// EXTRAER NÚMERO DE JSON
//
// Ejemplo:
//
// "distancia_cm":4.7
//
// ==========================================================

float extraerNumero(
    const String& json,
    const String& campo
)
{
    String patron =
        "\"" +
        campo +
        "\":";

    int posicion =
        json.indexOf(
            patron
        );

    if (posicion < 0)
    {
        return -1.0;
    }

    int inicio =
        posicion +
        patron.length();

    int fin =
        json.indexOf(
            ",",
            inicio
        );

    if (fin < 0)
    {
        fin =
            json.indexOf(
                "}",
                inicio
            );
    }

    if (fin < 0)
    {
        return -1.0;
    }

    String numero =
        json.substring(
            inicio,
            fin
        );

    numero.trim();

    return numero.toFloat();
}


// ==========================================================
// CONSULTAR EPP SECUNDARIO
// ==========================================================

bool consultarEpp(
    const char* nombre,
    const char* url,
    String& estado,
    String& conexion,
    float* distanciaCm = nullptr
)
{
    HTTPClient http;

    http.setConnectTimeout(
        500
    );

    http.setTimeout(
        700
    );


    Serial.println();

    Serial.println(
        "----------------------------------------"
    );

    Serial.print(
        "CONSULTANDO "
    );

    Serial.println(
        nombre
    );

    Serial.print(
        "URL: "
    );

    Serial.println(
        url
    );


    http.begin(
        url
    );


    int codigo =
        http.GET();


    // ======================================================
    // RESPONDIÓ
    // ======================================================

    if (codigo == 200)
    {
        String respuesta =
            http.getString();


        conexion =
            "CONECTADO";


        String estadoRecibido =
            extraerTexto(
                respuesta,
                "estado"
            );


        if (
            estadoRecibido.length() > 0
        )
        {
            estado =
                estadoRecibido;
        }
        else
        {
            estado =
                "DESCONOCIDO";
        }


        // ==================================================
        // DISTANCIA OPCIONAL
        // ==================================================

        if (distanciaCm != nullptr)
        {
            *distanciaCm =
                extraerNumero(
                    respuesta,
                    "distancia_cm"
                );
        }


        Serial.print(
            nombre
        );

        Serial.println(
            ": CONECTADO"
        );


        Serial.print(
            "HTTP: "
        );

        Serial.println(
            codigo
        );


        Serial.print(
            "RESPUESTA: "
        );

        Serial.println(
            respuesta
        );


        Serial.print(
            "ESTADO: "
        );

        Serial.println(
            estado
        );


        http.end();

        return true;
    }


    // ======================================================
    // DESCONECTADO
    // ======================================================

    conexion =
        "DESCONECTADO";

    estado =
        "DESCONOCIDO";


    if (distanciaCm != nullptr)
    {
        *distanciaCm =
            -1.0;
    }


    Serial.print(
        nombre
    );

    Serial.println(
        ": DESCONECTADO"
    );


    Serial.print(
        "ERROR HTTP: "
    );

    Serial.println(
        codigo
    );


    http.end();

    return false;
}


// ==========================================================
// /estado
// ==========================================================

void manejarEstado()
{
    // ======================================================
    // CASCO
    // ======================================================

    int lectura =
        digitalRead(
            SENSOR_CASCO
        );


    String estadoCasco;


    if (lectura == HIGH)
    {
        estadoCasco =
            "PUESTO";
    }
    else
    {
        estadoCasco =
            "RETIRADO";
    }


    // ======================================================
    // CHALECO
    // ======================================================

    String estadoChaleco =
        "DESCONOCIDO";

    String conexionChaleco =
        "DESCONECTADO";


    consultarEpp(
        "CHALECO",
        "http://192.168.4.10/estado",
        estadoChaleco,
        conexionChaleco
    );


    // ======================================================
    // LENTES
    // ======================================================

    String estadoLentes =
        "DESCONOCIDO";

    String conexionLentes =
        "DESCONECTADO";

    float distanciaLentesCm =
        -1.0;


    consultarEpp(
        "LENTES",
        "http://192.168.4.11/estado",
        estadoLentes,
        conexionLentes,
        &distanciaLentesCm
    );


    // ======================================================
    // JSON COMPLETO PARA FLUTTER
    // ======================================================

    String json =
        "{"

        // --------------------------------------------------
        // CASCO
        // --------------------------------------------------

        "\"casco\":{"

        "\"epp\":\"CASCO\","

        "\"estado\":\"" +
        estadoCasco +
        "\","

        "\"sensor\":" +
        String(lectura) +
        ","

        "\"conexion\":\"CONECTADO\","

        "\"tipo\":\"CENTRAL\""

        "},"


        // --------------------------------------------------
        // CHALECO
        // --------------------------------------------------

        "\"chaleco\":{"

        "\"epp\":\"CHALECO\","

        "\"estado\":\"" +
        estadoChaleco +
        "\","

        "\"conexion\":\"" +
        conexionChaleco +
        "\","

        "\"tipo\":\"SECUNDARIO\""

        "},"


        // --------------------------------------------------
        // LENTES
        // --------------------------------------------------

        "\"lentes\":{"

        "\"epp\":\"LENTES\","

        "\"estado\":\"" +
        estadoLentes +
        "\","

        "\"conexion\":\"" +
        conexionLentes +
        "\","

        "\"distancia_cm\":" +
        String(
            distanciaLentesCm,
            1
        ) +
        ","

        "\"tipo\":\"SECUNDARIO\""

        "},"


        // --------------------------------------------------
        // SISTEMA
        // --------------------------------------------------

        "\"sistema\":{"

        "\"estado\":\"CONECTADO\","

        "\"central\":\"CASCO\""

        "}"

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
        "RESPUESTA PARA SAFE VISION:"
    );

    Serial.println(
        "========================================"
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
        "{\"ok\":true,\"epp\":\"CASCO\",\"central\":true}"
    );
}


// ==========================================================
// PAGINA PRINCIPAL
// ==========================================================

void manejarInicio()
{
    String html = R"rawliteral(

<!DOCTYPE html>

<html>

<head>

<meta charset="UTF-8">

<meta name="viewport"
content="width=device-width, initial-scale=1.0">

<title>
SafeVision EPP
</title>

</head>

<body>

<h1>
SafeVision EPP
</h1>

<h2>
ESP32 CENTRAL - CASCO
</h2>

<p>
SSID: SAFEVISION_EPP
</p>

<p>
IP CENTRAL: 192.168.4.1
</p>

<p>
CHALECO: 192.168.4.10
</p>

<p>
LENTES: 192.168.4.11
</p>

<p>
<a href="/estado">
Consultar sistema
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
// CREAR WIFI
// ==========================================================

void crearRedWiFi()
{
    Serial.println();

    Serial.println(
        "========================================"
    );

    Serial.println(
        "SAFE VISION EPP"
    );

    Serial.println(
        "CENTRAL - CASCO"
    );

    Serial.println(
        "========================================"
    );


    WiFi.mode(
        WIFI_AP
    );


    delay(
        500
    );


    bool ipConfigurada =
        WiFi.softAPConfig(
            IP_CENTRAL,
            GATEWAY,
            SUBNET
        );


    if (ipConfigurada)
    {
        Serial.println(
            "IP CENTRAL CONFIGURADA"
        );
    }
    else
    {
        Serial.println(
            "ERROR CONFIGURANDO IP"
        );
    }


    // ======================================================
    // CREAR RED
    //
    // Máximo 8 dispositivos.
    // Nos servirá luego para guantes y botas.
    // ======================================================

    bool resultado =
        WiFi.softAP(
            AP_SSID,
            AP_PASSWORD,
            1,
            false,
            8
        );


    if (resultado)
    {
        Serial.println();

        Serial.println(
            "========================================"
        );

        Serial.println(
            "WIFI SAFE VISION CREADO"
        );

        Serial.println(
            "========================================"
        );


        Serial.print(
            "SSID: "
        );

        Serial.println(
            AP_SSID
        );


        Serial.print(
            "IP CENTRAL: "
        );

        Serial.println(
            WiFi.softAPIP()
        );


        Serial.println(
            "========================================"
        );
    }
    else
    {
        Serial.println(
            "ERROR CREANDO WIFI"
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

    Serial.println(
        "========================================"
    );

    Serial.println(
        "SERVIDOR CASCO INICIADO"
    );

    Serial.println(
        "========================================"
    );


    Serial.println(
        "http://192.168.4.1"
    );


    Serial.println(
        "http://192.168.4.1/estado"
    );


    Serial.println(
        "http://192.168.4.1/ping"
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


    delay(
        2000
    );


    pinMode(
        SENSOR_CASCO,
        INPUT_PULLDOWN
    );


    crearRedWiFi();


    iniciarServidor();


    int lectura =
        digitalRead(
            SENSOR_CASCO
        );


    ultimoEstado =
        lectura;


    Serial.println();

    Serial.println(
        "========================================"
    );

    Serial.println(
        "ESTADO INICIAL CASCO"
    );

    Serial.println(
        "========================================"
    );


    Serial.print(
        "GPIO 4 = "
    );

    Serial.println(
        lectura
    );


    if (lectura == HIGH)
    {
        Serial.println(
            "CASCO: PUESTO"
        );
    }
    else
    {
        Serial.println(
            "CASCO: RETIRADO"
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
    server.handleClient();


    int lectura =
        digitalRead(
            SENSOR_CASCO
        );


    if (
        lectura !=
        ultimoEstado
    )
    {
        ultimoEstado =
            lectura;


        Serial.println();

        Serial.println(
            "----------------------------------------"
        );

        Serial.println(
            "CAMBIO DETECTADO EN CASCO"
        );


        if (lectura == HIGH)
        {
            Serial.println(
                "CASCO: PUESTO"
            );
        }
        else
        {
            Serial.println(
                "CASCO: RETIRADO"
            );
        }


        Serial.println(
            "----------------------------------------"
        );
    }


    delay(
        50
    );
}