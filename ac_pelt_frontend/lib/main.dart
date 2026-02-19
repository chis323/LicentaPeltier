import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

/// ====== CONFIG ======
/// For LOCAL LAN testing (phone must be on same Wi-Fi):
///   baseUrl = "http://192.168.1.71:8080"
///
/// For Render later:
///   baseUrl = "https://your-app.onrender.com"
const String baseUrl = "http://10.0.2.2:8080";
const String apiKey = "CHANGE_ME_API_KEY";
/// ====================

class Api {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final q = <String, String>{'key': apiKey, ...?query};
    return Uri.parse("$baseUrl$path").replace(queryParameters: q);
  }

  static Future<Map<String, dynamic>> getStatus() async {
    final res = await http.get(_uri("/api/status"));
    if (res.statusCode != 200) {
      throw Exception("Status error: ${res.statusCode} ${res.body}");
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> sendCommand(Map<String, dynamic> payload) async {
    final res = await http.post(
      _uri("/api/command"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) {
      throw Exception("Command error: ${res.statusCode} ${res.body}");
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peltier AC Remote',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  bool _loading = true;
  String? _error;

  // Status from backend
  bool deviceOnline = false;
  double? ambientTempC;
  double? humidityPct;
  double? hotSideTempC;
  double? coldSideTempC;
  int? coldFanPwm;
  int? hotFanPwm;
  int? peltierPwm;
  bool? swingOn;
  int? ts;

  // UI state (sliders)
  double uiColdFan = 0;
  double uiHotFan = 0;
  double uiPeltier = 0;
  bool uiSwing = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final s = await Api.getStatus();

      setState(() {
        _loading = false;
        _error = null;

        deviceOnline = (s['deviceOnline'] == true);
        ambientTempC = _asDouble(s['ambientTempC']);
        humidityPct = _asDouble(s['humidityPct']);
        hotSideTempC = _asDouble(s['hotSideTempC']);
        coldSideTempC = _asDouble(s['coldSideTempC']);

        coldFanPwm = _asInt(s['coldFanPwm']);
        hotFanPwm = _asInt(s['hotFanPwm']);
        peltierPwm = _asInt(s['peltierPwm']);
        swingOn = s['swingOn'] is bool ? s['swingOn'] as bool : null;

        ts = _asInt(s['ts']);

        // If backend provided values, sync UI sliders/toggle (but don’t override while dragging)
        if (coldFanPwm != null) uiColdFan = coldFanPwm!.toDouble();
        if (hotFanPwm != null) uiHotFan = hotFanPwm!.toDouble();
        if (peltierPwm != null) uiPeltier = peltierPwm!.toDouble();
        if (swingOn != null) uiSwing = swingOn!;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _sendSwing(bool on) async {
    setState(() => uiSwing = on);
    try {
      await Api.sendCommand({"swingOn": on});
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _sendSlider(String field, int value) async {
    try {
      await Api.sendCommand({field: value});
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineColor = deviceOnline ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Peltier AC Remote"),
        actions: [
          IconButton(
            onPressed: _poll,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statusCard(onlineColor),
                const SizedBox(height: 12),
                _controlsCard(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _errorCard(_error!),
                ],
              ],
            ),
    );
  }

  Widget _statusCard(Color onlineColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: onlineColor, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(deviceOnline ? "Device Online" : "Device Offline",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(ts == null ? "" : _formatTs(ts!),
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _chip("Ambient", ambientTempC == null ? "--" : "${ambientTempC!.toStringAsFixed(1)} °C"),
              _chip("Humidity", humidityPct == null ? "--" : "${humidityPct!.toStringAsFixed(0)} %"),
              _chip("Hot side", hotSideTempC == null ? "--" : "${hotSideTempC!.toStringAsFixed(1)} °C"),
              _chip("Cold side", coldSideTempC == null ? "--" : "${coldSideTempC!.toStringAsFixed(1)} °C"),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _controlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Controls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          SwitchListTile(
            title: const Text("Swing"),
            value: uiSwing,
            onChanged: deviceOnline ? _sendSwing : null,
          ),

          const SizedBox(height: 6),
          _sliderRow(
            title: "Cold fan",
            value: uiColdFan,
            onChanged: (v) => setState(() => uiColdFan = v),
            onChangeEnd: deviceOnline ? (v) => _sendSlider("coldFanPwm", v.round()) : null,
          ),

          _sliderRow(
            title: "Hot fan",
            value: uiHotFan,
            onChanged: (v) => setState(() => uiHotFan = v),
            onChangeEnd: deviceOnline ? (v) => _sendSlider("hotFanPwm", v.round()) : null,
          ),

          _sliderRow(
            title: "Peltier",
            value: uiPeltier,
            onChanged: (v) => setState(() => uiPeltier = v),
            onChangeEnd: deviceOnline ? (v) => _sendSlider("peltierPwm", v.round()) : null,
          ),

          if (!deviceOnline)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                "Device is offline. Start the Pi bridge and check /health.",
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _sliderRow({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    required ValueChanged<double>? onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(title)),
          Text(value.round().toString(), style: const TextStyle(fontFeatures: [])),
        ]),
        Slider(
          min: 0,
          max: 100,
          divisions: 100,
          value: value.clamp(0, 100),
          onChanged: deviceOnline ? onChanged : null,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text("$label: $value"),
    );
  }

  Widget _errorCard(String msg) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(msg, style: TextStyle(color: Colors.red.shade800)),
      ),
    );
  }

  String _formatTs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }
}
