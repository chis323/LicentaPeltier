import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../models/profile_summary.dart';
import '../models/rule.dart';

class ProfilesCard extends StatelessWidget {
  final List<ProfileSummary> profiles;
  final Profile? selectedProfile;
  final String? selectedProfileId;
  final bool profilesLoading;
  final bool creatingProfile;
  final bool autosaving;
  final bool syncingNameField;
  final TextEditingController profileNameCtrl;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String id) onPickProfile;
  final Future<void> Function() onCreateProfile;
  final Future<void> Function(bool enabled) onToggleEnableProfile;
  final Future<void> Function() onDeleteSelectedProfile;
  final Future<void> Function() onAddBlock;
  final Future<void> Function(Profile p, Rule r) onEditBlock;
  final VoidCallback onProfileChanged;

  const ProfilesCard({
    super.key,
    required this.profiles,
    required this.selectedProfile,
    required this.selectedProfileId,
    required this.profilesLoading,
    required this.creatingProfile,
    required this.autosaving,
    required this.syncingNameField,
    required this.profileNameCtrl,
    required this.onRefresh,
    required this.onPickProfile,
    required this.onCreateProfile,
    required this.onToggleEnableProfile,
    required this.onDeleteSelectedProfile,
    required this.onAddBlock,
    required this.onEditBlock,
    required this.onProfileChanged,
  });

  @override
  Widget build(BuildContext context) {
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
                  onPressed: onRefresh,
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
                    onChanged: (v) {
                      if (v != null) {
                        onPickProfile(v);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: (creatingProfile || maxReached)
                      ? null
                      : () => onCreateProfile(),
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
                  onProfileChanged();
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Switch(
                    value: p.enabled,
                    onChanged: (v) => onToggleEnableProfile(v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.enabled ? "Enabled (scheduler active)" : "Disabled",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  IconButton(
                    tooltip: "Delete profile",
                    onPressed: () => onDeleteSelectedProfile(),
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
                    onPressed: () => onAddBlock(),
                    icon: const Icon(Icons.add),
                    label: const Text("Add block"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._allBlocksList(p),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _allBlocksList(Profile p) {
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
                onPressed: () => onEditBlock(p, r),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  p.rules.remove(r);
                  onProfileChanged();
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}