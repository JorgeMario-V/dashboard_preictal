# Documentación del Firmware ESP32 – Tabla Completa

A continuación se presenta toda la documentación del código en una sola tabla.  
Las columnas incluyen: sección del sistema, descripción y fragmento de código correspondiente.

---

| Sección | Descripción | Código |
|--------|-------------|--------|
| **Bibliotecas** | Bibliotecas necesarias para conexión WiFi, WebSocket, comunicación I2C, uso del sensor y JSON. | ```cpp\n#include <WiFi.h>\n#include <WebSocketsServer.h>\n#include <Wire.h>\n#include <MPU6050.h>\n#include <ArduinoJson.h>\n``` |
| **Objetos principales** | Inicialización del sensor MPU6050 y del servidor WebSocket en el puerto 81. | ```cpp\nMPU6050 mpu;\nWebSocketsServer webSocket(81);\n``` |
| **Configuración WiFi** | SSID y contraseña de la red a la que se conectará el ESP32. | ```cpp\nconst char* ssid = "EXT";\nconst char* password = "juan3218";\n``` |
| **Parámetros del sistema** | Definición de umbrales, pines, tiempos y límites del algoritmo preictal. | ```cpp\nconst int LED_PIN = 2;\nconst float UMBRAL_PREICTAL = 2.5;\nconst int DURACION_VENTANA = 5000;\nconst int FRECUENCIA_MUESTREO = 50;\nconst int LIMITE_EVENTOS = 15;\nconst unsigned long REINTENTO_WIFI_MS = 10000;\n``` |
| **Variables temporales** | Controlan intervalos de reconexión WiFi y envío de datos JSON. | ```cpp\nunsigned long ultimoIntentoWiFi = 0;\nunsigned long ultimoEnvio = 0;\n``` |
| **Inicialización del MPU6050** | Escanea dispositivos I2C, inicializa el sensor y verifica conexión. | ```cpp\nbool inicializarMPU() {\n  Serial.println(" Escaneando bus I2C...");\n  byte count = 0;\n  for (byte i = 1; i < 127; i++) {\n    Wire.beginTransmission(i);\n    if (Wire.endTransmission() == 0) {\n      Serial.printf(" Dispositivo I2C detectado en 0x%02X\\n", i);\n      count++;\n    }\n  }\n  Serial.printf(" Total dispositivos encontrados: %d\\n", count);\n  Serial.println(" Inicializando MPU6050...");\n  mpu.initialize();\n  delay(200);\n  return mpu.testConnection();\n}\n``` |
| **Eventos WebSocket** | Detecta conexiones de nuevos clientes y muestra su IP. | ```cpp\nvoid onWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {\n  if (type == WStype_CONNECTED) {\n    IPAddress ip = webSocket.remoteIP(num);\n    Serial.printf(" Cliente conectado: %d.%d.%d.%d\\n", ip[0], ip[1], ip[2], ip[3]);\n  }\n}\n``` |
| **Setup del dispositivo** | Inicializa serial, LED, I2C, WiFi y servidor WebSocket. | ```cpp\nvoid setup() {\n  Serial.begin(115200);\n  delay(1000);\n  pinMode(LED_PIN, OUTPUT);\n  Wire.begin(21, 22);\n  delay(500);\n  inicializarMPU();\n  WiFi.begin(ssid, password);\n  while (WiFi.status() != WL_CONNECTED) {\n    delay(500);\n    Serial.print(".");\n  }\n  webSocket.begin();\n  webSocket.onEvent(onWebSocketEvent);\n}\n``` |
| **Verificación WiFi** | Reconexión automática si se pierde la conexión. | ```cpp\nvoid verificarWiFi() {\n  if (WiFi.status() != WL_CONNECTED && millis() - ultimoIntentoWiFi > REINTENTO_WIFI_MS) {\n    WiFi.disconnect();\n    WiFi.begin(ssid, password);\n    ultimoIntentoWiFi = millis();\n  }\n}\n``` |
| **Variables del loop** | Variables usadas en la ventana de muestreo de 5 segundos. | ```cpp\nint16_t ax, ay, az;\nint eventos_irregulares = 0;\nunsigned long inicio = millis();\n``` |
| **Bucle de muestreo** | Lee aceleraciones, calcula magnitud, cuenta picos y envía datos. | ```cpp\nwhile (millis() - inicio < DURACION_VENTANA) {\n  mpu.getAcceleration(&ax, &ay, &az);\n  float ax_g = ax / 16384.0;\n  float ay_g = ay / 16384.0;\n  float az_g = az / 16384.0;\n  float a_total = sqrt(ax_g * ax_g + ay_g * ay_g + az_g * az_g);\n  if (a_total > UMBRAL_PREICTAL) eventos_irregulares++;\n  if (millis() - ultimoEnvio > 200) {\n    StaticJsonDocument<200> doc;\n    doc["type"] = "sample";\n    doc["ax"] = ax_g;\n    doc["ay"] = ay_g;\n    doc["az"] = az_g;\n    doc["a_total"] = a_total;\n    String payload;\n    serializeJson(doc, payload);\n    webSocket.broadcastTXT(payload);\n    ultimoEnvio = millis();\n  }\n  delay(1000 / FRECUENCIA_MUESTREO);\n}\n``` |
| **Evaluación de ventana** | Determina si hay posible estado preictal o actividad normal. | ```cpp\nif (eventos_irregulares > LIMITE_EVENTOS) {\n  digitalWrite(LED_PIN, HIGH);\n  StaticJsonDocument<200> alert;\n  alert["type"] = "alert";\n  alert["reason"] = "preictal_detected";\n  alert["count"] = eventos_irregulares;\n  String alertMsg;\n  serializeJson(alert, alertMsg);\n  webSocket.broadcastTXT(alertMsg);\n  delay(3000);\n  digitalWrite(LED_PIN, LOW);\n} else {\n  StaticJsonDocument<100> normal;\n  normal["type"] = "status";\n  normal["status"] = "ok";\n  String msg;\n  serializeJson(normal, msg);\n  webSocket.broadcastTXT(msg);\n}\n``` |
| **Intervalo antes de la siguiente ventana** | Pausa de un segundo antes del siguiente ciclo. | ```cpp\ndelay(1000);\n``` |

---

# Fin del documento

