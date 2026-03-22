import 'package:flutter/material.dart';

import '../models/device_state.dart';

class StatusCard extends StatelessWidget {
  final DeviceState device;
  final Color onlineColor;
  final String Function(int ms) formatTs;
  final Widget Function(String label, String value) chipBuilder;

  const StatusCard({
    super.key,
    required this.device,
    required this.onlineColor,
    required this.formatTs,
    required this.chipBuilder,
  });

  @override
  Widget build(BuildContext context) {
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
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
                chipBuilder(
                  "Ambient",
                  device.ambientTempC == null
                      ? "--"
                      : "${device.ambientTempC!.toStringAsFixed(1)} °C",
                ),
                chipBuilder(
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
}