import 'package:flutter_test/flutter_test.dart';
import 'package:myappcrew_flutter/src/tester_identity_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('tester identity store saves and clears identity', () async {
    final store = TesterIdentityStore();
    const identity = TesterIdentity(
      testerId: 'tester_123',
      appPublicKey: 'pk_test',
      sessionToken: 'token_abc',
      connectedAtSeconds: 123,
    );

    await store.saveIdentity(identity);
    final loaded = await store.getIdentity();

    expect(loaded?.testerId, identity.testerId);
    expect(loaded?.appPublicKey, identity.appPublicKey);
    expect(loaded?.sessionToken, identity.sessionToken);
    expect(loaded?.connectedAtSeconds, identity.connectedAtSeconds);

    await store.clearIdentity();
    final cleared = await store.getIdentity();
    expect(cleared, isNull);
  });

  test('tester identity store checks app key and connectivity', () async {
    final store = TesterIdentityStore();
    const identity = TesterIdentity(
      testerId: 'tester_456',
      appPublicKey: 'pk_live',
    );

    await store.saveIdentity(identity);
    expect(await store.isConnectedForApp('pk_live'), isTrue);
    expect(await store.isConnectedForApp('pk_other'), isFalse);

    await store.saveIdentity(
      const TesterIdentity(
        testerId: 'tst_anonymous',
        appPublicKey: 'pk_live',
      ),
    );
    expect(await store.isConnectedForApp('pk_live'), isFalse);
  });
}
