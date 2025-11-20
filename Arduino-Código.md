```cpp
#include <WiFi.h>
#include <WebSocketsServer.h>
#include <Wire.h>
#include <MPU6050.h>
#include <ArduinoJson.h>

// ---------------------------------------------------------------------------
// OBJETOS PRINCIPALES
// ---------------------------------------------------------------------------
MPU6050 mpu;                     // Controlador del sensor MPU6050
WebSocketsServer webSocket(81);  // Servidor WebSocket en el puerto 81

// ---------------------------------------------------------------------------
// CONFIGURACIÓN WIFI
// ---------------------------------------------------------------------------
const char* ssid = "EXT";        // Red WiFi
const char* password = "juan3218";

// ---------------------------------------------------------------------------
// PARÁMETROS DEL SISTEMA
// ---------------------------------------------------------------------------
const int LED_PIN = 2;                  // LED indicador de alerta
const float UMBRAL_PREICTAL = 2.5;      // Aceleración mínima considerada irregular (en g)
const int DURACION_VENTANA = 5000;      // Duración de la ventana de análisis (ms)
const int FRECUENCIA_MUESTREO = 50;     // Frecuencia del MPU6050 (Hz)
const int LIMITE_EVENTOS = 15;          // Número mínimo de picos para alerta preictal
const unsigned long REINTENTO_WIFI_MS = 10000;  // Reintentos WiFi

// ---------------------------------------------------------------------------
// VARIABLES DE TIEMPO
// ---------------------------------------------------------------------------
unsigned long ultimoIntentoWiFi = 0;    // Control de reconexión WiFi
unsigned long ultimoEnvio = 0;          // Control de envío JSON

// ---------------------------------------------------------------------------
// INICIALIZACIÓN DEL SENSOR MPU6050
// Escanea dispositivos I2C, inicializa el sensor y verifica conexión.
// ---------------------------------------------------------------------------
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
    Serial.println(" No se detecta MPU6050. Verifique conexiones SDA/SCL/VCC/GND.\n");
    return false;
  }
}

// ---------------------------------------------------------------------------
// MANEJO DE EVENTOS DEL SERVIDOR WEBSOCKET
// Registra cuando un cliente se conecta.
// ---------------------------------------------------------------------------
void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  if (type == WStype_CONNECTED) {
    IPAddress ip = webSocket.remoteIP(num);
    Serial.printf(" Cliente conectado: %d.%d.%d.%d\n", ip[0], ip[1], ip[2], ip[3]);
  }
}

// ---------------------------------------------------------------------------
// CONFIGURACIÓN INICIAL DEL SISTEMA
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(LED_PIN, OUTPUT);

  Wire.begin(21, 22); // Pines SDA y SCL
  delay(500);

  inicializarMPU();

  // Conexión a WiFi
  Serial.printf("Conectando a WiFi (%s)...\n", ssid);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.printf("\n WiFi conectado. IP: %s\n", WiFi.localIP().toString().c_str());

  // Inicio de WebSocket
  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);
  Serial.println(" Servidor WebSocket iniciado en puerto 81\n");
}

// ---------------------------------------------------------------------------
// VERIFICACIÓN Y RECONEXIÓN WIFI
// ---------------------------------------------------------------------------
void verificarWiFi() {
  if (WiFi.status() != WL_CONNECTED && millis() - ultimoIntentoWiFi > REINTENTO_WIFI_MS) {
    Serial.println(" WiFi desconectado. Reintentando...");
    WiFi.disconnect();
    WiFi.begin(ssid, password);
    ultimoIntentoWiFi = millis();
  }
}

// ---------------------------------------------------------------------------
// BUCLE PRINCIPAL
// Realiza el muestreo, envía datos y genera alertas.
// ---------------------------------------------------------------------------
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

    // Envío de datos al dashboard cada 200 ms
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

  // -------------------------------------------------------------------------
  // EVALUACIÓN DE LA VENTANA
  // Si supera el límite de picos, se detecta posible estado preictal.
  // -------------------------------------------------------------------------
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

  delay(1000);
}
