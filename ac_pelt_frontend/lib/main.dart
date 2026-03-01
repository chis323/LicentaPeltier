import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

const String baseUrl = "http://192.168.1.121:8080";
const String apiKey = "CHANGE_ME_API_KEY";

class Api {
  static Uri _uri(String path, [Map<String, String>? query]) {
    final q = <String, String>{'key': apiKey, ...?query};
    return Uri.parse("$baseUrl$path").replace(queryParameters: q);
  }

  static Future<Map<String, dynamic>> getStatus() async {
    final res = await http.get(_uri("/api/status"));
    if (res.statusCode != 200) throw Exception("Status error: ${res.statusCode} ${res.body}");
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<void> sendCommand(Map<String, dynamic> payload) async {
    final res = await http.post(
      _uri("/api/command"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (res.statusCode != 200) throw Exception("Command error: ${res.statusCode} ${res.body}");
  }

  static Future<List<DailyStat>> getDailyHistory({int days = 7}) async {
    final res = await http.get(_uri("/api/history/daily", {"days": "$days"}));
    if (res.statusCode != 200) throw Exception("History error: ${res.statusCode} ${res.body}");
    final obj = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (obj["days"] as List<dynamic>? ?? []);
    return list.map((e) => DailyStat.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<ProfileSummary>> listProfiles() async {
    final res = await http.get(_uri("/api/profiles"));
    if (res.statusCode != 200) throw Exception("Profiles error: ${res.statusCode} ${res.body}");
    final obj = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (obj["profiles"] as List<dynamic>? ?? []);
    return list.map((e) => ProfileSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Profile> getProfile(String id) async {
    final res = await http.get(_uri("/api/profiles/$id"));
    if (res.statusCode != 200) throw Exception("Profile load error: ${res.statusCode} ${res.body}");
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Profile> createProfile(String name) async {
    final res = await http.post(
      _uri("/api/profiles"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"name": name}),
    );
    if (res.statusCode != 200) throw Exception("Profile create error: ${res.statusCode} ${res.body}");
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<Profile> saveProfile(Profile p) async {
    final res = await http.put(
      _uri("/api/profiles/${p.id}"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(p.toJson()),
    );
    if (res.statusCode != 200) throw Exception("Profile save error: ${res.statusCode} ${res.body}");
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> setProfileEnabled(String id, bool enabled) async {
    final res = await http.post(
      _uri("/api/profiles/$id/enable"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"enabled": enabled}),
    );
    if (res.statusCode != 200) throw Exception("Profile enable error: ${res.statusCode} ${res.body}");
  }

  static Future<void> deleteProfile(String id) async {
    final res = await http.delete(_uri("/api/profiles/$id"));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Profile delete error: ${res.statusCode} ${res.body}");
    }
  }
}

class DailyStat {
  final DateTime day;
  final double? minAmbientTempC;
  final double? maxAmbientTempC;

  DailyStat({required this.day, required this.minAmbientTempC, required this.maxAmbientTempC});

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory DailyStat.fromJson(Map<String, dynamic> j) {
    final dayStr = (j["day"] ?? "").toString();
    final parts = dayStr.split("-");
    final dt = (parts.length == 3)
        ? DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]))
        : DateTime.now();

    return DailyStat(
      day: dt,
      minAmbientTempC: _asDouble(j["minAmbientTempC"]),
      maxAmbientTempC: _asDouble(j["maxAmbientTempC"]),
    );
  }
}

class ProfileSummary {
  final String id;
  final String name;
  final bool enabled;
  ProfileSummary({required this.id, required this.name, required this.enabled});
  factory ProfileSummary.fromJson(Map<String, dynamic> j) => ProfileSummary(
        id: (j["id"] ?? "").toString(),
        name: (j["name"] ?? "").toString(),
        enabled: j["enabled"] == true,
      );
}

class Rule {
  int dayOfWeek;
  String start;
  String end;
  int coldFanPwm;
  int hotFanPwm;
  bool peltierOn;
  bool swingOn;

  Rule({
    required this.dayOfWeek,
    required this.start,
    required this.end,
    required this.coldFanPwm,
    required this.hotFanPwm,
    required this.peltierOn,
    required this.swingOn,
  });

  factory Rule.fromJson(Map<String, dynamic> j) => Rule(
        dayOfWeek: (j["dayOfWeek"] is num) ? (j["dayOfWeek"] as num).toInt() : int.parse(j["dayOfWeek"].toString()),
        start: (j["start"] ?? "08:00").toString(),
        end: (j["end"] ?? "09:00").toString(),
        coldFanPwm: (j["coldFanPwm"] is num) ? (j["coldFanPwm"] as num).toInt() : 0,
        hotFanPwm: (j["hotFanPwm"] is num) ? (j["hotFanPwm"] as num).toInt() : 0,
        peltierOn: j["peltierOn"] == true,
        swingOn: j["swingOn"] == true,
      );

  Map<String, dynamic> toJson() => {
        "dayOfWeek": dayOfWeek,
        "start": start,
        "end": end,
        "coldFanPwm": coldFanPwm,
        "hotFanPwm": hotFanPwm,
        "peltierOn": peltierOn,
        "swingOn": swingOn,
      };
}

class Profile {
  final String id;
  String name;
  bool enabled;
  List<Rule> rules;

  Profile({required this.id, required this.name, required this.enabled, required this.rules});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: (j["id"] ?? "").toString(),
        name: (j["name"] ?? "").toString(),
        enabled: j["enabled"] == true,
        rules: ((j["rules"] as List<dynamic>? ?? [])).map((e) => Rule.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "enabled": enabled,
        "rules": rules.map((r) => r.toJson()).toList(),
      };
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
  Timer? _statusTimer;
  Timer? _historyTimer;

  bool _loading = true;
  String? _error;

  bool deviceOnline = false;
  double? ambientTempC;
  double? humidityPct;
  int? coldFanPwm;
  int? hotFanPwm;
  int? peltierPwm;
  bool? swingOn;
  int? ts;

  double uiColdFan = 0;
  double uiHotFan = 0;
  bool uiSwing = false;
  bool uiPeltierOn = false;

  bool historyLoading = true;
  List<DailyStat> history = const [];

  bool profilesLoading = true;
  List<ProfileSummary> profiles = const [];
  Profile? selectedProfile;
  String? selectedProfileId;
  bool creatingProfile = false;

  Timer? _autosaveTimer;
  bool _autosaving = false;

  final TextEditingController _profileNameCtrl = TextEditingController();
  bool _syncingNameField = false;

  bool get _profileControlsDevice => profiles.any((p) => p.enabled);

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());
    _historyTimer = Timer.periodic(const Duration(minutes: 5), (_) => _pollHistory());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _historyTimer?.cancel();
    _autosaveTimer?.cancel();
    _profileNameCtrl.dispose();
    super.dispose();
  }

  void _showError(Object e) {
    final msg = e.toString();
    debugPrint("[UI] ERROR: $msg");
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await Future.wait([
      _pollStatus(),
      _pollHistory(),
      _loadProfilesAndSelect(),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _pollStatus() async {
    try {
      final s = await Api.getStatus();
      if (!mounted) return;
      setState(() {
        _error = null;

        deviceOnline = (s['deviceOnline'] == true);
        ambientTempC = _asDouble(s['ambientTempC']);
        humidityPct = _asDouble(s['humidityPct']);
        coldFanPwm = _asInt(s['coldFanPwm']);
        hotFanPwm = _asInt(s['hotFanPwm']);
        peltierPwm = _asInt(s['peltierPwm']);
        swingOn = s['swingOn'] is bool ? s['swingOn'] as bool : null;
        ts = _asInt(s['ts']);

        if (!_profileControlsDevice) {
          if (coldFanPwm != null) uiColdFan = coldFanPwm!.toDouble();
          if (hotFanPwm != null) uiHotFan = hotFanPwm!.toDouble();
          if (swingOn != null) uiSwing = swingOn!;
          if (peltierPwm != null) uiPeltierOn = (peltierPwm ?? 0) > 0;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pollHistory() async {
    if (mounted) setState(() => historyLoading = true);
    try {
      final h = await Api.getDailyHistory(days: 7);
      h.sort((a, b) => a.day.compareTo(b.day));
      if (!mounted) return;
      setState(() {
        history = h;
        historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        historyLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadProfilesAndSelect() async {
    if (mounted) setState(() => profilesLoading = true);
    try {
      final list = await Api.listProfiles();

      final enabled = list.where((p) => p.enabled).toList();
      final pickId =
          selectedProfileId ?? (enabled.isNotEmpty ? enabled.first.id : (list.isNotEmpty ? list.first.id : null));

      Profile? full;
      if (pickId != null) {
        full = await Api.getProfile(pickId);
      }

      if (!mounted) return;
      setState(() {
        profiles = list;
        selectedProfileId = pickId;
        selectedProfile = full;
        profilesLoading = false;
      });

      if (full != null) {
        _setProfileNameField(full.name);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        profilesLoading = false;
        _error = e.toString();
      });
    }
  }

  void _setProfileNameField(String name) {
    _syncingNameField = true;
    _profileNameCtrl.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    _syncingNameField = false;
  }

  void _scheduleAutosave() {
    final p = selectedProfile;
    if (p == null) return;

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 700), () async {
      await _autosaveNow();
    });
  }

  Future<void> _autosaveNow() async {
    final p = selectedProfile;
    if (p == null) return;
    if (_autosaving) return;

    if (mounted) setState(() => _autosaving = true);
    try {
      final saved = await Api.saveProfile(p);
      final summaries = await Api.listProfiles();

      if (!mounted) return;
      setState(() {
        selectedProfile = saved;
        profiles = summaries;
        selectedProfileId = saved.id;
        _error = null;
      });

      _setProfileNameField(saved.name);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _autosaving = false);
    }
  }

  void _showManualLockedToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Disable the active profile to use manual controls.")),
    );
  }

  Future<void> _sendSwing(bool on) async {
    if (_profileControlsDevice) {
      _showManualLockedToast();
      return;
    }
    if (mounted) setState(() => uiSwing = on);
    try {
      await Api.sendCommand({"swingOn": on});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _sendPeltier(bool on) async {
    if (_profileControlsDevice) {
      _showManualLockedToast();
      return;
    }
    if (mounted) setState(() => uiPeltierOn = on);
    try {
      await Api.sendCommand({"peltierPwm": on ? 100 : 0});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _sendSlider(String field, int value) async {
    if (_profileControlsDevice) {
      _showManualLockedToast();
      return;
    }
    try {
      await Api.sendCommand({field: value});
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pickProfile(String id) async {
    if (mounted) {
      setState(() {
        selectedProfileId = id;
        selectedProfile = null;
        profilesLoading = true;
      });
    }
    try {
      final full = await Api.getProfile(id);
      if (!mounted) return;
      setState(() {
        selectedProfile = full;
        profilesLoading = false;
      });
      _setProfileNameField(full.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        profilesLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createProfileFlow() async {
    if (profiles.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Max 3 profiles allowed. Delete one to create another.")),
      );
      return;
    }

    final nameController = TextEditingController(text: "New Profile");

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create profile"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Profile name"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    if (mounted) setState(() => creatingProfile = true);

    try {
      final created = await Api.createProfile(name);
      final full = await Api.getProfile(created.id);

      if (!mounted) return;
      setState(() {
        selectedProfileId = full.id;
        selectedProfile = full;
      });
      _setProfileNameField(full.name);

      await _loadProfilesAndSelect();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile created ✅")),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => creatingProfile = false);
    }
  }

  Future<void> _toggleEnableProfile(bool enabled) async {
    final p = selectedProfile;
    if (p == null) return;

    try {
      await Api.setProfileEnabled(p.id, enabled);
      await _loadProfilesAndSelect();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteSelectedProfile() async {
    final p = selectedProfile;
    if (p == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete profile?"),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      if (p.enabled) {
        await Api.setProfileEnabled(p.id, false);
      }
      await Api.deleteProfile(p.id);

      if (!mounted) return;
      setState(() {
        selectedProfile = null;
        selectedProfileId = null;
      });

      await _loadProfilesAndSelect();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile deleted ✅")));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _addBlock() async {
    final p = selectedProfile;
    if (p == null) return;

    final r = await _showRuleEditorDialog(
      title: "Add time block",
      initial: Rule(
        dayOfWeek: 1,
        start: "08:00",
        end: "09:00",
        coldFanPwm: 50,
        hotFanPwm: 100,
        peltierOn: true,
        swingOn: true,
      ),
    );

    if (r == null) return;
    if (mounted) setState(() => p.rules.add(r));
    _scheduleAutosave();
  }

  Future<void> _editBlock(Profile p, Rule r) async {
    final updated = await _showRuleEditorDialog(title: "Edit time block", initial: r);
    if (updated == null) return;

    if (mounted) {
      setState(() {
        r.dayOfWeek = updated.dayOfWeek;
        r.start = updated.start;
        r.end = updated.end;
        r.coldFanPwm = updated.coldFanPwm;
        r.hotFanPwm = updated.hotFanPwm;
        r.peltierOn = updated.peltierOn;
        r.swingOn = updated.swingOn;
      });
    }
    _scheduleAutosave();
  }

  Future<Rule?> _showRuleEditorDialog({required String title, required Rule initial}) async {
    int day = initial.dayOfWeek;
    final startCtrl = TextEditingController(text: initial.start);
    final endCtrl = TextEditingController(text: initial.end);
    double cold = initial.coldFanPwm.toDouble();
    double hot = initial.hotFanPwm.toDouble();
    bool peltier = initial.peltierOn;
    bool swing = initial.swingOn;

    String? validateTime(String s) {
      final m = RegExp(r'^\d{2}:\d{2}$').firstMatch(s);
      if (m == null) return "Use HH:mm";
      final hh = int.tryParse(s.substring(0, 2)) ?? -1;
      final mm = int.tryParse(s.substring(3, 5)) ?? -1;
      if (hh < 0 || hh > 23 || mm < 0 || mm > 59) return "Invalid time";
      return null;
    }

    return showDialog<Rule>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: day,
                  decoration: const InputDecoration(labelText: "Day"),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Monday")),
                    DropdownMenuItem(value: 2, child: Text("Tuesday")),
                    DropdownMenuItem(value: 3, child: Text("Wednesday")),
                    DropdownMenuItem(value: 4, child: Text("Thursday")),
                    DropdownMenuItem(value: 5, child: Text("Friday")),
                    DropdownMenuItem(value: 6, child: Text("Saturday")),
                    DropdownMenuItem(value: 7, child: Text("Sunday")),
                  ],
                  onChanged: (v) => setLocal(() => day = v ?? day),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: startCtrl,
                  decoration: InputDecoration(
                    labelText: "Start (HH:mm)",
                    errorText: validateTime(startCtrl.text.trim()),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: endCtrl,
                  decoration: InputDecoration(
                    labelText: "End (HH:mm)",
                    errorText: validateTime(endCtrl.text.trim()),
                  ),
                  onChanged: (_) => setLocal(() {}),
                ),
                const SizedBox(height: 10),
                _sliderLocal("Cold fan", cold, (v) => setLocal(() => cold = v)),
                _sliderLocal("Hot fan", hot, (v) => setLocal(() => hot = v)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Peltier"),
                  subtitle: const Text("On / Off"),
                  value: peltier,
                  onChanged: (v) => setLocal(() => peltier = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Swing"),
                  value: swing,
                  onChanged: (v) => setLocal(() => swing = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                final e1 = validateTime(startCtrl.text.trim());
                final e2 = validateTime(endCtrl.text.trim());
                if (e1 != null || e2 != null) return;

                Navigator.pop(
                  ctx,
                  Rule(
                    dayOfWeek: day,
                    start: startCtrl.text.trim(),
                    end: endCtrl.text.trim(),
                    coldFanPwm: cold.round(),
                    hotFanPwm: hot.round(),
                    peltierOn: peltier,
                    swingOn: swing,
                  ),
                );
              },
              child: const Text("OK"),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sliderLocal(String title, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(title)), Text(value.round().toString())]),
        Slider(min: 0, max: 100, divisions: 100, value: value.clamp(0, 100), onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlineColor = deviceOnline ? Colors.green : Colors.red;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Peltier AC Remote"),
        actions: [
          IconButton(onPressed: _refreshAll, icon: const Icon(Icons.refresh), tooltip: "Refresh"),
        ],
      ),

      body: SafeArea(
        bottom: true,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                children: [
                  _statusCard(onlineColor),
                  const SizedBox(height: 12),
                  _historyCard(),
                  const SizedBox(height: 12),
                  _profilesCard(),
                  const SizedBox(height: 12),
                  _controlsCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorCard(_error!),
                  ],
                ],
              ),
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
              Text(
                deviceOnline ? "Device Online" : "Device Offline",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(ts == null ? "" : _formatTs(ts!), style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _chip("Ambient", ambientTempC == null ? "--" : "${ambientTempC!.toStringAsFixed(1)} °C"),
              _chip("Humidity", humidityPct == null ? "--" : "${humidityPct!.toStringAsFixed(0)} %"),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _historyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Text("Last 7 days (daily min/max)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (historyLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton(onPressed: _pollHistory, icon: const Icon(Icons.refresh), tooltip: "Refresh history"),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: history.isEmpty
                ? Center(
                    child: Text(historyLoading ? "Loading..." : "No data yet", style: TextStyle(color: Colors.grey.shade700)),
                  )
                : _minMaxChart(history),
          ),
        ]),
      ),
    );
  }

  Widget _minMaxChart(List<DailyStat> data) {
    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];
    double? minY;
    double? maxY;

    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      if (d.minAmbientTempC != null) {
        minSpots.add(FlSpot(i.toDouble(), d.minAmbientTempC!));
        minY = (minY == null) ? d.minAmbientTempC : (d.minAmbientTempC! < minY ? d.minAmbientTempC : minY);
        maxY = (maxY == null) ? d.minAmbientTempC : (d.minAmbientTempC! > maxY ? d.minAmbientTempC : maxY);
      }
      if (d.maxAmbientTempC != null) {
        maxSpots.add(FlSpot(i.toDouble(), d.maxAmbientTempC!));
        minY = (minY == null) ? d.maxAmbientTempC : (d.maxAmbientTempC! < minY ? d.maxAmbientTempC : minY);
        maxY = (maxY == null) ? d.maxAmbientTempC : (d.maxAmbientTempC! > maxY ? d.maxAmbientTempC : maxY);
      }
    }

    final yMin = (minY ?? 0) - 1.0;
    final yMax = (maxY ?? 30) + 1.0;
    double intervalFor(double min, double max) {
      final span = (max - min).abs();
      if (span <= 2) return 0.5;
      if (span <= 6) return 1.0;
      if (span <= 15) return 2.0;
      return 5.0;
    }

    final yInterval = intervalFor(yMin, yMax);

    return LineChart(
      LineChartData(
        minY: yMin,
        maxY: yMax,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: yInterval,
              getTitlesWidget: (v, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    v.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 11),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),

          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final dt = data[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text("${dt.month}/${dt.day}", style: const TextStyle(fontSize: 11)),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          LineChartBarData(spots: minSpots, isCurved: true, dotData: const FlDotData(show: true)),
          LineChartBarData(spots: maxSpots, isCurved: true, dotData: const FlDotData(show: true)),
        ],
      ),
    );
  }

  Widget _profilesCard() {
    final p = selectedProfile;
    final maxReached = profiles.length >= 3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Text("Profiles & Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (profilesLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton(onPressed: _loadProfilesAndSelect, icon: const Icon(Icons.refresh), tooltip: "Refresh profiles"),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedProfileId,
                  decoration: const InputDecoration(labelText: "Profile"),
                  items: profiles
                      .map((x) => DropdownMenuItem(
                            value: x.id,
                            child: Text("${x.name}${x.enabled ? " (enabled)" : ""}"),
                          ))
                      .toList(),
                  onChanged: (v) => v == null ? null : _pickProfile(v),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: (creatingProfile || maxReached) ? null : _createProfileFlow,
                icon: creatingProfile
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.add),
                label: Text(creatingProfile ? "Creating..." : "Create"),
              ),
            ],
          ),
          if (maxReached) ...[
            const SizedBox(height: 8),
            Text("Max 3 profiles. Delete one to create another.", style: TextStyle(color: Colors.grey.shade700)),
          ],
          if (p == null) ...[
            const SizedBox(height: 10),
            Text("Create a profile to add schedules.", style: TextStyle(color: Colors.grey.shade700)),
          ] else ...[
            const SizedBox(height: 12),
            TextField(
              controller: _profileNameCtrl,
              decoration: InputDecoration(
                labelText: "Profile name",
                suffixIcon: _autosaving
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
              onChanged: (v) {
                if (_syncingNameField) return;
                p.name = v;
                _scheduleAutosave();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Switch(value: p.enabled, onChanged: _toggleEnableProfile),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.enabled ? "Enabled (scheduler active)" : "Disabled",
                      style: TextStyle(color: Colors.grey.shade700)),
                ),
                IconButton(
                  tooltip: "Delete profile",
                  onPressed: _deleteSelectedProfile,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Text("Schedule blocks", style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addBlock,
                  icon: const Icon(Icons.add),
                  label: const Text("Add block"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._allBlocksList(p),
          ],
        ]),
      ),
    );
  }

  List<Widget> _allBlocksList(Profile p) {
    if (p.rules.isEmpty) {
      return [Text("No blocks yet.", style: TextStyle(color: Colors.grey.shade700))];
    }

    final blocks = [...p.rules]
      ..sort((a, b) {
        final d = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (d != 0) return d;
        return a.start.compareTo(b.start);
      });

    String dayName(int d) => const ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][d.clamp(1, 7)];

    return blocks.map((r) {
      return Card(
        margin: const EdgeInsets.only(top: 8),
        child: ListTile(
          title: Text("${dayName(r.dayOfWeek)} • ${r.start} – ${r.end}"),
          subtitle: Text(
            "Cold ${r.coldFanPwm}% | Hot ${r.hotFanPwm}% | Peltier ${r.peltierOn ? "ON" : "OFF"} | Swing ${r.swingOn ? "ON" : "OFF"}",
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(icon: const Icon(Icons.edit), onPressed: () => _editBlock(p, r)),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  if (mounted) setState(() => p.rules.remove(r));
                  _scheduleAutosave();
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _controlsCard() {
    final locked = _profileControlsDevice;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Text("Manual Controls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (locked)
                Chip(
                  label: const Text("Locked by active profile"),
                  backgroundColor: Colors.orange.shade100,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (locked) ...[
            Text(
              "A profile is enabled, so scheduled settings override manual controls.",
              style: TextStyle(color: Colors.orange.shade900),
            ),
            const SizedBox(height: 8),
          ],
          SwitchListTile(
            title: const Text("Swing"),
            value: uiSwing,
            onChanged: (deviceOnline && !locked) ? _sendSwing : null,
          ),
          SwitchListTile(
            title: const Text("Peltier"),
            subtitle: const Text("On / Off"),
            value: uiPeltierOn,
            onChanged: (deviceOnline && !locked) ? _sendPeltier : null,
          ),
          const SizedBox(height: 6),
          _sliderRow(
            title: "Cold fan",
            value: uiColdFan,
            onChanged: (v) => setState(() => uiColdFan = v),
            onChangeEnd: (deviceOnline && !locked) ? (v) => _sendSlider("coldFanPwm", v.round()) : null,
          ),
          _sliderRow(
            title: "Hot fan",
            value: uiHotFan,
            onChanged: (v) => setState(() => uiHotFan = v),
            onChangeEnd: (deviceOnline && !locked) ? (v) => _sendSlider("hotFanPwm", v.round()) : null,
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
        Row(children: [Expanded(child: Text(title)), Text(value.round().toString())]),
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

  Widget _chip(String label, String value) => Chip(label: Text("$label: $value"));

  Widget _errorCard(String msg) => Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(msg, style: TextStyle(color: Colors.red.shade800)),
        ),
      );

  String _formatTs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
  }
}