import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/api/api_service.dart';
import '../../models/daily_stat.dart';
import '../../models/device_state.dart';
import '../../models/profile.dart';
import '../../models/profile_summary.dart';
import '../../models/rule.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService api = ApiService();

  Timer? _statusTimer;
  Timer? _historyTimer;
  Timer? _autosaveTimer;

  bool loading = true;
  bool historyLoading = true;
  bool profilesLoading = true;
  bool creatingProfile = false;
  bool autosaving = false;

  String? error;

  final device = DeviceState();
  List<DailyStat> history = const [];
  List<ProfileSummary> profiles = const [];
  Profile? selectedProfile;
  String? selectedProfileId;

  double uiColdFan = 0;
  double uiHotFan = 0;
  bool uiSwing = false;
  bool uiPeltierOn = false;

  final TextEditingController profileNameCtrl = TextEditingController();
  bool syncingNameField = false;

  bool get profileControlsDevice => profiles.any((p) => p.enabled);

  @override
  void initState() {
    super.initState();
    refreshAll();
    _statusTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => pollStatus());
    _historyTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => pollHistory());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _historyTimer?.cancel();
    _autosaveTimer?.cancel();
    profileNameCtrl.dispose();
    super.dispose();
  }

  Future<void> refreshAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    await Future.wait([
      pollStatus(),
      pollHistory(),
      loadProfilesAndSelect(),
    ]);

    if (mounted) setState(() => loading = false);
  }

  Future<void> pollStatus() async {
    try {
      final json = await api.getStatus();
      if (!mounted) return;

      setState(() {
        error = null;
        device.updateFromJson(json);

        if (!profileControlsDevice) {
          if (device.coldFanPwm != null) {
            uiColdFan = device.coldFanPwm!.toDouble();
          }
          if (device.hotFanPwm != null) {
            uiHotFan = device.hotFanPwm!.toDouble();
          }
          if (device.swingOn != null) uiSwing = device.swingOn!;
          if (device.peltierOn != null) uiPeltierOn = device.peltierOn!;
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> pollHistory() async {
    if (mounted) setState(() => historyLoading = true);

    try {
      final h = await api.getDailyHistory(days: 7)
        ..sort((a, b) => a.day.compareTo(b.day));

      if (!mounted) return;

      setState(() {
        history = h;
        historyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        historyLoading = false;
        error = e.toString();
      });
    }
  }

  Future<void> loadProfilesAndSelect() async {
    if (mounted) setState(() => profilesLoading = true);

    try {
      final list = await api.listProfiles();
      final enabled = list.where((p) => p.enabled).toList();

      final pickId = selectedProfileId ??
          (enabled.isNotEmpty
              ? enabled.first.id
              : (list.isNotEmpty ? list.first.id : null));

      Profile? full;
      if (pickId != null) {
        full = await api.getProfile(pickId);
      }

      if (!mounted) return;

      setState(() {
        profiles = list;
        selectedProfileId = pickId;
        selectedProfile = full;
        profilesLoading = false;
      });

      if (full != null) setProfileNameField(full.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        profilesLoading = false;
        error = e.toString();
      });
    }
  }

  void setProfileNameField(String name) {
    syncingNameField = true;
    profileNameCtrl.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    syncingNameField = false;
  }

  void scheduleAutosave() {
    if (selectedProfile == null) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 700), autosaveNow);
  }

  Future<void> autosaveNow() async {
    final p = selectedProfile;
    if (p == null || autosaving) return;

    if (mounted) setState(() => autosaving = true);

    try {
      final saved = await api.saveProfile(p);
      final summaries = await api.listProfiles();

      if (!mounted) return;

      setState(() {
        selectedProfile = saved;
        selectedProfileId = saved.id;
        profiles = summaries;
        error = null;
      });

      setProfileNameField(saved.name);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => autosaving = false);
    }
  }

  void showErrorDialog(Object e) {
    final msg = e.toString();
    debugPrint("[UI] ERROR: $msg");
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void showLockedToast() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Disable the active profile to use manual controls."),
      ),
    );
  }

  Future<void> sendSwing(bool on) async {
    if (profileControlsDevice) return showLockedToast();
    setState(() => uiSwing = on);

    try {
      await api.sendCommand({"swingOn": on});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> sendPeltier(bool on) async {
    if (profileControlsDevice) return showLockedToast();
    setState(() => uiPeltierOn = on);

    try {
      await api.sendCommand({"peltierOn": on});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> sendSlider(String field, int value) async {
    if (profileControlsDevice) return showLockedToast();

    try {
      await api.sendCommand({field: value});
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> pickProfile(String id) async {
    setState(() {
      selectedProfileId = id;
      selectedProfile = null;
      profilesLoading = true;
    });

    try {
      final full = await api.getProfile(id);
      if (!mounted) return;

      setState(() {
        selectedProfile = full;
        profilesLoading = false;
      });

      setProfileNameField(full.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        profilesLoading = false;
        error = e.toString();
      });
    }
  }

  Future<void> createProfileFlow() async {
    if (profiles.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Max 3 profiles allowed. Delete one to create another."),
        ),
      );
      return;
    }

    final ctrl = TextEditingController(text: "New Profile");
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create profile"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "Profile name"),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    setState(() => creatingProfile = true);

    try {
      final created = await api.createProfile(name);
      final full = await api.getProfile(created.id);

      if (!mounted) return;
      setState(() {
        selectedProfileId = full.id;
        selectedProfile = full;
      });

      setProfileNameField(full.name);
      await loadProfilesAndSelect();
    } catch (e) {
      showErrorDialog(e);
    } finally {
      if (mounted) setState(() => creatingProfile = false);
    }
  }

  Future<void> toggleEnableProfile(bool enabled) async {
    final p = selectedProfile;
    if (p == null) return;

    try {
      await api.setProfileEnabled(p.id, enabled);
      await loadProfilesAndSelect();
    } catch (e) {
      showErrorDialog(e);
    }
  }

  Future<void> deleteSelectedProfile() async {
    final p = selectedProfile;
    if (p == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete profile?"),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      if (p.enabled) {
        await api.setProfileEnabled(p.id, false);
      }

      await api.deleteProfile(p.id);

      if (!mounted) return;
      setState(() {
        selectedProfile = null;
        selectedProfileId = null;
      });

      await loadProfilesAndSelect();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile deleted ✅")),
      );
    } catch (e) {
      showErrorDialog(e);
    }
  }

  Future<void> addBlock() async {
    final p = selectedProfile;
    if (p == null) return;

    final rule = await showRuleEditorDialog(
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

    if (rule == null) return;

    setState(() => p.rules.add(rule));
    scheduleAutosave();
  }

  Future<void> editBlock(Profile p, Rule r) async {
    final updated = await showRuleEditorDialog(
      title: "Edit time block",
      initial: r,
    );
    if (updated == null) return;

    setState(() {
      r.dayOfWeek = updated.dayOfWeek;
      r.start = updated.start;
      r.end = updated.end;
      r.coldFanPwm = updated.coldFanPwm;
      r.hotFanPwm = updated.hotFanPwm;
      r.peltierOn = updated.peltierOn;
      r.swingOn = updated.swingOn;
    });

    scheduleAutosave();
  }

  Future<Rule?> showRuleEditorDialog({
    required String title,
    required Rule initial,
  }) async {
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
                localSlider("Cold fan", cold, (v) => setLocal(() => cold = v)),
                localSlider("Hot fan", hot, (v) => setLocal(() => hot = v)),
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
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

  static Widget localSlider(
    String title,
    double value,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(value.round().toString()),
          ],
        ),
        Slider(
          min: 0,
          max: 100,
          divisions: 100,
          value: value.clamp(0, 100),
          onChanged: onChanged,
        ),
      ],
    );
  }

  String formatTs(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}:"
        "${dt.second.toString().padLeft(2, '0')}";
  }

  Widget chip(String label, String value) => Chip(label: Text("$label: $value"));

  Widget errorCard(String msg) => Card(
        color: const Color(0xFF3A1F1F),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(msg, style: const TextStyle(color: Colors.white)),
        ),
      );

  Widget sliderRow({
    required String title,
    required double value,
    required ValueChanged<double>? onChanged,
    required ValueChanged<double>? onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title)),
            Text(value.round().toString()),
          ],
        ),
        Slider(
          min: 0,
          max: 100,
          divisions: 100,
          value: value.clamp(0, 100),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }

  Widget statusCard(Color onlineColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: onlineColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  device.deviceOnline ? "Device Online" : "Device Offline",
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  device.ts == null ? "" : formatTs(device.ts!),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                chip(
                  "Ambient",
                  device.ambientTempC == null
                      ? "--"
                      : "${device.ambientTempC!.toStringAsFixed(1)} °C",
                ),
                chip(
                  "Humidity",
                  device.humidityPct == null
                      ? "--"
                      : "${device.humidityPct!.toStringAsFixed(0)} %",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget historyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Last 7 days (daily min/max)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (historyLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  onPressed: pollHistory,
                  icon: const Icon(Icons.refresh),
                  tooltip: "Refresh history",
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: history.isEmpty
                  ? const Center(
                      child: Text(
                        "No data yet",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : minMaxChart(history),
            ),
          ],
        ),
      ),
    );
  }

  Widget minMaxChart(List<DailyStat> data) {
    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];
    double? minY;
    double? maxY;

    for (var i = 0; i < data.length; i++) {
      final d = data[i];

      if (d.minAmbientTempC != null) {
        minSpots.add(FlSpot(i.toDouble(), d.minAmbientTempC!));
        minY = minY == null
            ? d.minAmbientTempC
            : (d.minAmbientTempC! < minY ? d.minAmbientTempC : minY);
        maxY = maxY == null
            ? d.minAmbientTempC
            : (d.minAmbientTempC! > maxY ? d.minAmbientTempC : maxY);
      }

      if (d.maxAmbientTempC != null) {
        maxSpots.add(FlSpot(i.toDouble(), d.maxAmbientTempC!));
        minY = minY == null
            ? d.maxAmbientTempC
            : (d.maxAmbientTempC! < minY ? d.maxAmbientTempC : minY);
        maxY = maxY == null
            ? d.maxAmbientTempC
            : (d.maxAmbientTempC! > maxY ? d.maxAmbientTempC : maxY);
      }
    }

    final yMin = (minY ?? 0) - 1.0;
    final yMax = (maxY ?? 30) + 1.0;

    double yInterval(double min, double max) {
      final span = (max - min).abs();
      if (span <= 2) return 0.5;
      if (span <= 6) return 1.0;
      if (span <= 15) return 2.0;
      return 5.0;
    }

    return LineChart(
      LineChartData(
        minY: yMin,
        maxY: yMax,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: yInterval(yMin, yMax),
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  v.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= data.length) {
                  return const SizedBox.shrink();
                }
                final dt = data[i].day;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "${dt.month}/${dt.day}",
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          LineChartBarData(
            spots: minSpots,
            isCurved: true,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: maxSpots,
            isCurved: true,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget profilesCard() {
    final p = selectedProfile;
    final maxReached = profiles.length >= 3;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Profiles & Schedule",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (profilesLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                IconButton(
                  onPressed: loadProfilesAndSelect,
                  icon: const Icon(Icons.refresh),
                  tooltip: "Refresh profiles",
                ),
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
                        .map(
                          (x) => DropdownMenuItem(
                            value: x.id,
                            child: Text(
                              "${x.name}${x.enabled ? " (enabled)" : ""}",
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => v == null ? null : pickProfile(v),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed:
                      (creatingProfile || maxReached) ? null : createProfileFlow,
                  icon: creatingProfile
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(creatingProfile ? "Creating..." : "Create"),
                ),
              ],
            ),
            if (maxReached) ...[
              const SizedBox(height: 8),
              const Text(
                "Max 3 profiles. Delete one to create another.",
                style: TextStyle(color: Colors.white70),
              ),
            ],
            if (p == null) ...[
              const SizedBox(height: 10),
              const Text(
                "Create a profile to add schedules.",
                style: TextStyle(color: Colors.white70),
              ),
            ] else ...[
              const SizedBox(height: 12),
              TextField(
                controller: profileNameCtrl,
                decoration: InputDecoration(
                  labelText: "Profile name",
                  suffixIcon: autosaving
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (v) {
                  if (syncingNameField) return;
                  p.name = v;
                  scheduleAutosave();
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Switch(value: p.enabled, onChanged: toggleEnableProfile),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.enabled ? "Enabled (scheduler active)" : "Disabled",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  IconButton(
                    tooltip: "Delete profile",
                    onPressed: deleteSelectedProfile,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  const Text(
                    "Schedule blocks",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: addBlock,
                    icon: const Icon(Icons.add),
                    label: const Text("Add block"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...allBlocksList(p),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> allBlocksList(Profile p) {
    if (p.rules.isEmpty) {
      return const [
        Text("No blocks yet.", style: TextStyle(color: Colors.white70)),
      ];
    }

    final blocks = [...p.rules]
      ..sort((a, b) {
        final d = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (d != 0) return d;
        return a.start.compareTo(b.start);
      });

    String dayName(int d) =>
        const ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][
            d.clamp(1, 7)];

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
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => editBlock(p, r),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() => p.rules.remove(r));
                  scheduleAutosave();
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget controlsCard() {
    final locked = profileControlsDevice;
    final slidersEnabled = device.deviceOnline && !locked;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  "Manual Controls",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
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
                style: TextStyle(color: Colors.orange.shade200),
              ),
              const SizedBox(height: 8),
            ],
            SwitchListTile(
              title: const Text("Swing"),
              value: uiSwing,
              onChanged: slidersEnabled ? sendSwing : null,
            ),
            SwitchListTile(
              title: const Text("Peltier"),
              subtitle: const Text("On / Off"),
              value: uiPeltierOn,
              onChanged: slidersEnabled ? sendPeltier : null,
            ),
            const SizedBox(height: 6),
            sliderRow(
              title: "Cold fan",
              value: uiColdFan,
              onChanged:
                  slidersEnabled ? (v) => setState(() => uiColdFan = v) : null,
              onChangeEnd: slidersEnabled
                  ? (v) => sendSlider("coldFanPwm", v.round())
                  : null,
            ),
            sliderRow(
              title: "Hot fan",
              value: uiHotFan,
              onChanged:
                  slidersEnabled ? (v) => setState(() => uiHotFan = v) : null,
              onChangeEnd: slidersEnabled
                  ? (v) => sendSlider("hotFanPwm", v.round())
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onlineColor = device.deviceOnline ? Colors.green : Colors.red;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Peltier AC Remote"),
        actions: [
          IconButton(
            onPressed: refreshAll,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                children: [
                  statusCard(onlineColor),
                  const SizedBox(height: 12),
                  historyCard(),
                  const SizedBox(height: 12),
                  profilesCard(),
                  const SizedBox(height: 12),
                  controlsCard(),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    errorCard(error!),
                  ],
                ],
              ),
      ),
    );
  }
}