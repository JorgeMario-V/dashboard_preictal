import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

void main() => runApp(const MpuDashboardApp());

class MpuDashboardApp extends StatelessWidget {
  const MpuDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dashboard Preictal',
      theme: ThemeData.dark(useMaterial3: true),
      home: const DashboardHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const MpuDashboardPage(), const WifiStatusPage()];

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.black,
        indicatorColor: Colors.tealAccent.withOpacity(0.2),
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => setState(() => currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sensors), label: "MPU6050"),
          NavigationDestination(icon: Icon(Icons.wifi), label: "WiFi"),
        ],
      ),
    );
  }
}

/// ===============================
/// PÁGINA 1: Monitoreo MPU6050
/// ===============================
class MpuDashboardPage extends StatefulWidget {
  const MpuDashboardPage({super.key});

  @override
  State<MpuDashboardPage> createState() => _MpuDashboardPageState();
}

class _MpuDashboardPageState extends State<MpuDashboardPage> {
  // ⚠ CAMBIA ESTA IP por la IP local del ESP32 (vista en el Monitor Serie).
  // Debe ser la MISMA en esta página y en la de WiFi.
  final String espIp = "172.16.12.251";

  WebSocketChannel? channel;
  List<_AccelData> data = [];
  List<String> alertHistory = [];

  double ax = 0, ay = 0, az = 0, aTotal = 0;
  String status = "Desconectado";
  String alertMsg = "";

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      channel = IOWebSocketChannel.connect('ws://$espIp:81');
      setState(() => status = "🟢 Conectado");

      channel!.stream.listen(
        (msg) {
          final decoded = jsonDecode(msg);

          if (decoded["type"] == "sample") {
            setState(() {
              ax = (decoded["ax"] ?? 0).toDouble();
              ay = (decoded["ay"] ?? 0).toDouble();
              az = (decoded["az"] ?? 0).toDouble();
              aTotal = (decoded["a_total"] ?? 0).toDouble();

              data.add(_AccelData(DateTime.now(), aTotal));
              if (data.length > 100) data.removeAt(0);
            });
          } else if (decoded["type"] == "alert") {
            setState(() {
              alertMsg = "⚠ Preictal detectado (${decoded["count"]} eventos)";
              alertHistory.insert(
                0,
                "${DateTime.now().toString().substring(11, 19)} - ALERTA (${decoded["count"]})",
              );
            });
          } else if (decoded["type"] == "status") {
            setState(() {
              alertMsg = "✅ Actividad normal";
              alertHistory.insert(
                0,
                "${DateTime.now().toString().substring(11, 19)} - Estado normal",
              );
            });
          }
        },
        onError: (e) {
          setState(() => status = "🔴 Error de conexión");
        },
        onDone: () {
          setState(() => status = "🔴 Desconectado");
        },
      );
    } catch (e) {
      setState(() => status = "🔴 Error de conexión");
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text("Monitoreo MPU6050"),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              channel?.sink.close();
              _connectWebSocket();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 10),
            _buildCurrentValues(),
            const SizedBox(height: 10),
            Expanded(child: _buildChart()),
            const SizedBox(height: 10),
            _buildAlertsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() => Card(
    color: Colors.black26,
    child: ListTile(
      title: Text("Estado: $status"),
      trailing: ElevatedButton.icon(
        onPressed: () {
          channel?.sink.close();
          _connectWebSocket();
        },
        icon: const Icon(Icons.power_settings_new),
        label: const Text("Reconectar"),
      ),
    ),
  );

  Widget _buildCurrentValues() => Card(
    color: Colors.black38,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          const Text("Lecturas actuales", style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _valueBox("AX", ax),
              _valueBox("AY", ay),
              _valueBox("AZ", az),
              _valueBox("A Total", aTotal, highlight: true),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _valueBox(String label, double value, {bool highlight = false}) =>
      Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.tealAccent : Colors.white70,
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 16,
              color: highlight ? Colors.tealAccent : Colors.white,
            ),
          ),
        ],
      );

  Widget _buildChart() => SfCartesianChart(
    title: ChartTitle(text: 'Aceleración Total (g)'),
    primaryXAxis: DateTimeAxis(
      intervalType: DateTimeIntervalType.seconds,
      edgeLabelPlacement: EdgeLabelPlacement.shift,
    ),
    primaryYAxis: NumericAxis(minimum: 0, maximum: 5),
    series: <LineSeries<_AccelData, DateTime>>[
      LineSeries<_AccelData, DateTime>(
        dataSource: data,
        xValueMapper: (_AccelData d, _) => d.time,
        yValueMapper: (_AccelData d, _) => d.value,
        color: Colors.tealAccent,
      ),
    ],
  );

  Widget _buildAlertsSection() => Expanded(
    child: Card(
      color: Colors.black38,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Historial de alertas",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: ListView.builder(
                itemCount: alertHistory.length,
                itemBuilder: (context, index) {
                  return Text(
                    alertHistory[index],
                    style: TextStyle(
                      color: alertHistory[index].contains("ALERTA")
                          ? Colors.redAccent
                          : Colors.greenAccent,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 5),
            Text(
              alertMsg,
              style: TextStyle(
                fontSize: 18,
                color: alertMsg.contains("⚠")
                    ? Colors.redAccent
                    : Colors.greenAccent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AccelData {
  final DateTime time;
  final double value;
  _AccelData(this.time, this.value);
}

/// ===============================
/// PÁGINA 2: Estado WiFi ESP32
/// ===============================
class WifiStatusPage extends StatefulWidget {
  const WifiStatusPage({super.key});

  @override
  State<WifiStatusPage> createState() => _WifiStatusPageState();
}

class _WifiStatusPageState extends State<WifiStatusPage> {
  final String espIp = "172.16.12.251"; // MISMA IP del ESP32
  WebSocketChannel? channel;
  String ssid = "";
  String ip = "";
  int rssi = 0;
  String uptime = "";
  String status = "Desconectado";

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  void _connectWebSocket() {
    try {
      channel = IOWebSocketChannel.connect('ws://$espIp:81');
      setState(() => status = "🟢 Conectado");

      channel!.stream.listen((msg) {
        final decoded = jsonDecode(msg);

        if (decoded["type"] == "wifi_status") {
          setState(() {
            ssid = decoded["ssid"] ?? "";
            ip = decoded["ip"] ?? "";
            rssi = decoded["rssi"] ?? 0;
            uptime = decoded["uptime"] ?? "";
          });
        }
      }, onDone: () => setState(() => status = "🔴 Desconectado"));
    } catch (e) {
      setState(() => status = "🔴 Error de conexión");
    }
  }

  @override
  void dispose() {
    channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text("Estado de conexión WiFi"),
        backgroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Estado: $status",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _wifiInfo("SSID", ssid),
            _wifiInfo("Dirección IP", ip),
            _wifiInfo("Señal RSSI", "$rssi dBm"),
            _wifiInfo("Tiempo activo", uptime),
          ],
        ),
      ),
    );
  }

  Widget _wifiInfo(String label, String value) {
    return Card(
      color: Colors.black26,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.white70)),
        trailing: Text(
          value.isEmpty ? "--" : value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.tealAccent,
          ),
        ),
      ),
    );
  }
}
