import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myappcrew_flutter/myappcrew_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    MyAppCrewConnectPrompt.debugSnapshotProviderForTesting = null;
  });

  testWidgets('prompt renders when disconnected', (tester) async {
    MyAppCrewConnectPrompt.debugSnapshotProviderForTesting =
        _disconnectedSnapshot;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyAppCrewConnectPrompt(
            child: Text('home'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Connect tester'), findsOneWidget);
  });

  testWidgets('prompt does not render when already connected',
      (tester) async {
    MyAppCrewConnectPrompt.debugSnapshotProviderForTesting = _connectedSnapshot;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyAppCrewConnectPrompt(
            child: Text('home'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Connect tester'), findsNothing);
  });
}

Future<DebugSnapshot> _disconnectedSnapshot() async {
  return const DebugSnapshot(
    initialized: true,
    baseUrl: 'https://example.com',
    publicKeyLast4: 'abcd',
    testerId: '',
    connected: false,
    lastErrorCode: null,
    lastConnectInputKind: null,
    queuedEventsCount: 0,
    lastFlushAt: null,
    lastBootstrapAt: null,
  );
}

Future<DebugSnapshot> _connectedSnapshot() async {
  return const DebugSnapshot(
    initialized: true,
    baseUrl: 'https://example.com',
    publicKeyLast4: 'abcd',
    testerId: 'tst_1234',
    connected: true,
    lastErrorCode: null,
    lastConnectInputKind: null,
    queuedEventsCount: 0,
    lastFlushAt: null,
    lastBootstrapAt: null,
  );
}
