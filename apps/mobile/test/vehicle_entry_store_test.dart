import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/widgets/vehicle_entry_effect.dart';

void main() {
  testWidgets('vehicle store preview renders the selected animated vehicle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 340,
              height: 160,
              child: VehicleShowcase(
                level: 12,
                styleId: 'vehicle_dragon_royal',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.byType(VehicleShowcase), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('room entrance displays the selected vehicle name and level', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VehicleEntryEffect(
            displayName: 'DarkVibeX Member',
            level: 6,
            vehicleId: 'vehicle_neon_comet',
            vehicleLabel: 'NEON COMET GT',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 240));

    expect(find.text('LEVEL 6'), findsOneWidget);
    expect(find.text('NEON COMET GT'), findsOneWidget);
    expect(find.text('DarkVibeX Member'), findsOneWidget);
  });
}
