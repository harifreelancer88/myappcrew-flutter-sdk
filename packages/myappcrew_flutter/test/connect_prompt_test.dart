import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myappcrew_flutter/myappcrew_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    MyAppCrewConnectPrompt.debugSnapshotProviderForTesting = null;
    MyAppCrewConnectPrompt.debugConnectHandlerForTesting = null;
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

  testWidgets('submitting code does not throw', (tester) async {
    MyAppCrewConnectPrompt.debugSnapshotProviderForTesting =
        _disconnectedSnapshot;
    MyAppCrewConnectPrompt.debugConnectHandlerForTesting =
        (_) => Future<MyAppCrewConnectResult>.error(Exception('boom'));

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
    await tester.enterText(find.byType(TextField), '123456');
    await tester.ensureVisible(find.text('Connect'));
    await tester.tap(find.text('Connect'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 10));

    expect(tester.takeException(), isNull);
  });

  testWidgets('prompt stays above keyboard', (tester) async {
    MyAppCrewConnectPrompt.debugSnapshotProviderForTesting =
        _disconnectedSnapshot;

    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MyAppCrewConnectPrompt(
            child: Text('home'),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    final buttonFinder = find.widgetWithText(ElevatedButton, 'Connect');
    final buttonRect = tester.getRect(buttonFinder);
    final logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final bottomInset = tester.view.viewInsets.bottom;

    expect(buttonRect.bottom, lessThanOrEqualTo(logicalHeight - bottomInset));
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
