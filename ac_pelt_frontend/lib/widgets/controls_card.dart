import 'package:flutter/material.dart';

import 'common_widgets.dart';

class ControlsCard extends StatelessWidget {
  final bool locked;
  final bool deviceOnline;
  final bool uiSwing;
  final bool uiPeltierOn;
  final double uiColdFan;
  final double uiHotFan;
  final ValueChanged<bool>? onSwingChanged;
  final ValueChanged<bool>? onPeltierChanged;
  final ValueChanged<double>? onColdFanChanged;
  final ValueChanged<double>? onColdFanChangeEnd;
  final ValueChanged<double>? onHotFanChanged;
  final ValueChanged<double>? onHotFanChangeEnd;

  const ControlsCard({
    super.key,
    required this.locked,
    required this.deviceOnline,
    required this.uiSwing,
    required this.uiPeltierOn,
    required this.uiColdFan,
    required this.uiHotFan,
    required this.onSwingChanged,
    required this.onPeltierChanged,
    required this.onColdFanChanged,
    required this.onColdFanChangeEnd,
    required this.onHotFanChanged,
    required this.onHotFanChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final slidersEnabled = deviceOnline && !locked;

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
              onChanged: slidersEnabled ? onSwingChanged : null,
            ),
            SwitchListTile(
              title: const Text("Peltier"),
              subtitle: const Text("On / Off"),
              value: uiPeltierOn,
              onChanged: slidersEnabled ? onPeltierChanged : null,
            ),
            const SizedBox(height: 6),
            SliderRow(
              title: "Cold fan",
              value: uiColdFan,
              onChanged: slidersEnabled ? onColdFanChanged : null,
              onChangeEnd: slidersEnabled ? onColdFanChangeEnd : null,
            ),
            SliderRow(
              title: "Hot fan",
              value: uiHotFan,
              onChanged: slidersEnabled ? onHotFanChanged : null,
              onChangeEnd: slidersEnabled ? onHotFanChangeEnd : null,
            ),
          ],
        ),
      ),
    );
  }
}