import 'package:ac_pelt_frontend/models/device_state.dart';
import 'package:ac_pelt_frontend/widgets/status_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StatusCard renders', (WidgetTester tester) async {
    final device = DeviceState()..deviceOnline = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatusCard(
            device: device,
            onlineColor: Colors.green,
            formatTs: (_) => '00:00:00',
            chipBuilder: (label, value) => Chip(label: Text('$label: $value')),
          ),
        ),
      ),
    );

    expect(find.text('Device Online'), findsOneWidget);
  });
}