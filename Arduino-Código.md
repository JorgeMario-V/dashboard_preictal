README_FIRMWARE.md
# Documentación del Firmware ESP32 – Sistema de Detección Preictal

Este documento describe detalladamente el funcionamiento del firmware utilizado en el ESP32 para detectar patrones irregulares de movimiento mediante un sensor MPU6050. El sistema procesa aceleraciones en ventanas de tiempo definidas y transmite los datos a través de un servidor WebSocket, permitiendo su visualización en una aplicación externa.

---

## 1. Bibliotecas utilizadas

cpp
#include <WiFi.h>
#include <WebSocketsServer.h>
#include <Wire.h>
#include <MPU6050.h>
#include <ArduinoJson.h>


Descripción de bibliotecas:

WiFi.h: manejo de red WiFi.

WebSocketsServer.h: servidor WebSocket para transmisión en tiempo real.

Wire.h: comunicación I2C con el MPU6050.

MPU6050.h: lectura y control del sensor.

ArduinoJson.h: envío de datos en formato JSON.

2. Objetos principales
MPU6050 mpu;
WebSocketsServer webSocket(81);


mpu: objeto que controla el MPU6050.

webSocket: servidor WebSocket en el puerto 81.

3. Configuración WiFi
const char* ssid = "EXT";
const char* password = "juan3218";


Datos de la red WiFi a la que se conectará el dispositivo.

4. Parámetros del sistema
const int LED_PIN = 2;
const float UMBRAL_PREICTAL = 2.5;
const int DURACION_VENTANA = 5000;
const int FRECUENCIA_MUESTREO = 50;
const int LIMITE_EVENTOS = 15;
const unsigned long REINTENTO_WIFI_MS = 10000;


Descripción:

LED_PIN: pin para encender un LED de alerta.

UMBRAL_PREICTAL: aceleración mínima para considerar un evento irregular.

DURACION_VENTANA: duración de la ventana de análisis en milisegundos.

FRECUENCIA_MUESTREO: frecuencia de lectura del sensor.

LIMITE_EVENTOS: número mínimo de picos para activar alerta.

REINTENTO_WIFI_MS: tiempo entre intentos de reconexión WiFi.

5. Variables de control de tiempo
unsigned long ultimoIntentoWiFi = 0;
unsigned long ultimoEnvio = 0;


Permiten controlar la frecuencia de reconexiones y envíos.

6. Inicialización del MPU6050
bool inicializarMPU() {
  Serial.println(" Escaneando bus I2C...");
  byte count = 0;
  for (byte i = 1; i < 127; i++) {
    Wire.beginTransmission(i);
    if (Wire.endTransmission() == 0) {
      Serial.printf(" Dispositivo I2C detectado en 0x%02X\n", i);
      count++;
    }
  }
  Serial.printf(" Total dispositivos encontrados: %d\n", count);

  Serial.println(" Inicializando MPU6050...");
  mpu.initialize();
  delay(200);

  if (mpu.testConnection()) {
    Serial.println(" MPU6050 conectado correctamente.\n");
    return true;
  } else {
    Serial.println(" No se detecta MPU6050. Verifica SDA/SCL/VCC/GND.\n");
    return false;
  }
}


Esta función:

Escanea el bus I2C.

Inicializa el sensor.

Verifica conexión mediante testConnection().

7. Manejo de eventos WebSocket
void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  if (type == WStype_CONNECTED) {
    IPAddress ip = webSocket.remoteIP(num);
    Serial.printf(" Cliente conectado: %d.%d.%d.%d\n", ip[0], ip[1], ip[2], ip[3]);
  }
}


Registra los clientes que se conectan al WebSocket.

8. Configuración inicial del sistema (setup)
void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(LED_PIN, OUTPUT);
  Wire.begin(21, 22);
  delay(500);

  inicializarMPU();

  Serial.printf("Conectando a WiFi (%s)...\n", ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\n WiFi conectado. IP: %s\n", WiFi.localIP().toString().c_str());

  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);
  Serial.println(" Servidor WebSocket iniciado en puerto 81\n");
}


Realiza:

Inicialización serial.

Configuración del LED.

Inicio de comunicación I2C.

Inicialización del MPU6050.

Conexión a la red WiFi.

Inicio del servidor WebSocket.

9. Verificación de conexión WiFi
void verificarWiFi() {
  if (WiFi.status() != WL_CONNECTED && millis() - ultimoIntentoWiFi > REINTENTO_WIFI_MS) {
    Serial.println(" WiFi desconectado. Reintentando...");
    WiFi.disconnect();
    WiFi.begin(ssid, password);
    ultimoIntentoWiFi = millis();
  }
}


Si el ESP32 pierde conexión, intenta reconectar después del tiempo indicado.

10. Bucle principal del programa
void loop() {
  webSocket.loop();
  verificarWiFi();

  int16_t ax, ay, az;
  int eventos_irregulares = 0;
  unsigned long inicio = millis();

  Serial.println(" Nueva ventana de muestreo...");

  while (millis() - inicio < DURACION_VENTANA) {
    mpu.getAcceleration(&ax, &ay, &az);

    float ax_g = ax / 16384.0;
    float ay_g = ay / 16384.0;
    float az_g = az / 16384.0;
    float a_total = sqrt(ax_g * ax_g + ay_g * ay_g + az_g * az_g);

    if (a_total > UMBRAL_PREICTAL) eventos_irregulares++;

    if (millis() - ultimoEnvio > 200) {
      StaticJsonDocument<200> doc;
      doc["type"] = "sample";
      doc["ax"] = ax_g;
      doc["ay"] = ay_g;
      doc["az"] = az_g;
      doc["a_total"] = a_total;
      String payload;
      serializeJson(doc, payload);
      webSocket.broadcastTXT(payload);
      ultimoEnvio = millis();
    }

    delay(1000 / FRECUENCIA_MUESTREO);
  }


Dentro del ciclo principal:

Se leen aceleraciones x, y y z.

Se convierten a unidades g.

Se calcula aceleración total.

Se cuentan los picos que superan el umbral.

Se envían datos al dashboard cada 200 ms en formato JSON.

Ejemplo de mensaje:

{
  "type": "sample",
  "ax": 0.12,
  "ay": 0.03,
  "az": 1.01,
  "a_total": 1.04
}

11. Evaluación de la ventana de análisis
if (eventos_irregulares > LIMITE_EVENTOS) {
  Serial.println(" Posible estado preictal detectado.");
  digitalWrite(LED_PIN, HIGH);

  StaticJsonDocument<200> alert;
  alert["type"] = "alert";
  alert["reason"] = "preictal_detected";
  alert["count"] = eventos_irregulares;
  String alertMsg;
  serializeJson(alert, alertMsg);
  webSocket.broadcastTXT(alertMsg);

  delay(3000);
  digitalWrite(LED_PIN, LOW);
} else {
  Serial.println(" Actividad normal.");
  StaticJsonDocument<100> normal;
  normal["type"] = "status";
  normal["status"] = "ok";
  String msg;
  serializeJson(normal, msg);
  webSocket.broadcastTXT(msg);
}


Si el número de eventos supera el umbral:

Se considera posible estado preictal.

Se enciende LED.

Se envía alerta JSON.

Ejemplo:

{
  "type": "alert",
  "reason": "preictal_detected",
  "count": 18
}


Si no supera el umbral, se reporta actividad normal.

12. Intervalo antes de la siguiente ventana
delay(1000);


Pausa de un segundo antes de iniciar la siguiente ventana.

Fin del documento
