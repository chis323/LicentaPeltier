import 'package:flutter/material.dart';

Widget infoChip(String label, String value) {
  return Chip(label: Text("$label: $value"));
}

Widget errorCard(String msg) {
  return Card(
    color: const Color(0xFF3A1F1F),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(msg, style: const TextStyle(color: Colors.white)),
    ),
  );
}

class SliderRow extends StatelessWidget {
  final String title;
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const SliderRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
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
}