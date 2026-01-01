import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myappcrew_flutter/myappcrew_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('wrapper renders child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MyAppCrewConnectWrapper(
          enabled: false,
          child: Text('child'),
        ),
      ),
    );

    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('wrapper does not show sheet when disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyAppCrewConnectWrapper(
          enabled: false,
          debugSnapshotProvider: _notConnectedSnapshot,
          child: const Text('home'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Connect tester'), findsNothing);
  });

  testWidgets('wrapper attempts to show sheet when not connected',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyAppCrewConnectWrapper(
            enabled: true,
            debugSnapshotProvider: _notConnectedSnapshot,
            child: const Text('home'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Connect tester'), findsOneWidget);
  });
}

Future<DebugSnapshot> _notConnectedSnapshot() async {
  return const DebugSnapshot(
    initialized: true,
    baseUrl: 'https://example.com',
    publicKeyLast4: 'test',
    testerId: '',
    connected: false,
    lastErrorCode: null,
    lastConnectInputKind: null,
    queuedEventsCount: 0,
    lastFlushAt: null,
    lastBootstrapAt: null,
  );
}
