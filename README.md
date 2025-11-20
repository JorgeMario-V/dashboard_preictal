# Sistema de Detección Preictal para Perros — Dashboard + Sensor MPU6050

Proyecto orientado a detectar posibles estados preictales en perros mediante el uso de un sensor MPU6050, transmisión de datos en tiempo real vía WebSocket, procesamiento en Arduino IDE y visualización mediante una aplicación Flutter.  
El sistema forma parte de un estudio que busca reconocer patrones fisiológicos y de movimiento asociados a la fase preictal en perros con epilepsia.

---

## Características principales

- Uso de un sensor MPU6050 para medición de acelerometría.
- Microcontrolador ESP32 transmitiendo datos en tiempo real usando WebSocket.
- Procesamiento en ventanas de 5 segundos con conteo de picos anómalos.
- Umbral configurable para la identificación de patrones compatibles con fase preictal.
- Aplicación Flutter para graficar datos, mostrar estados y generar alertas.
- Comunicación estable optimizada para 50 Hz.
- Reconexión automática de WiFi.

---

# Arquitectura del sistema

El sistema está diseñado en tres capas principales:

1. Capa de adquisición (ESP32 + MPU6050)  
2. Capa de comunicación (Servidor WebSocket)  
3. Capa de visualización y análisis (Aplicación Flutter)

---

## 1. Capa de Adquisición  
(ESP32 + sensor MPU6050)

Esta capa obtiene datos crudos del movimiento del perro.

### Componentes utilizados
- ESP32 como microcontrolador principal.
- MPU6050 con comunicación I2C (SDA: 21, SCL: 22).
- LED indicador para alertas preictales.

### Funciones principales
- Lectura de aceleración en ejes X, Y y Z.
- Conversión de valores a unidades g.
- Cálculo de magnitud vectorial total (|a|).
- Muestreo a 50 Hz.
- Evaluación en ventanas de 5 segundos para detección de picos.
- Activación de alerta preictal si se supera el límite establecido.

---

## 2. Capa de Comunicación  
(Servidor WebSocket en ESP32)

El ESP32 actúa como servidor WebSocket en el puerto 81.

### Tipos de mensajes enviados

#### Muestras en tiempo real:
```json
{
  "type": "sample",
  "ax": 0.12,
  "ay": 0.03,
  "az": 1.01,
  "a_total": 1.04
}


{
  "type": "alert",
  "reason": "preictal_detected",
  "count": 18
}
```
## 3. Capa de Visualización y Análisis

(Aplicación Flutter — Dashboard Preictal)

La aplicación Flutter cumple las siguientes funciones:

Conexión al servidor WebSocket.

Recepción de datos ax, ay, az y a_total.

Graficación de variables en tiempo real.

Visualización del estado del sensor.

Generación de alertas visuales cuando se detecta un posible estado preictal.

Registro básico de actividad durante la sesión.
/lib
 ├── models/
 ├── services/websocket_service.dart
 ├── ui/dashboard.dart
 ├── ui/components/
 └── main.dart
 
Flujo general del sistema
Perro (movimiento)
        |
        v
MPU6050 (captura de aceleración)
        |
        v
ESP32 (procesamiento)
 - Cálculo de |a|
 - Conteo de picos
 - Evaluación en ventana de 5s
        |
        v
Servidor WebSocket (puerto 81)
        |
        v
Dashboard Flutter
 - Gráficas
 - Estado del dispositivo
 - Alertas visuales

###Lógica de detección preictal

La fase preictal se caracteriza por patrones irregulares de movimiento.
El sistema evalúa:

Aceleración total |a|

Número de eventos que superan el umbral UMBRAL_PREICTAL

Cantidad total de picos dentro de una ventana de tiempo

Frecuencia de irregularidades consecutivas

Si la cantidad de picos supera el límite, el sistema emite una alerta preictal.

