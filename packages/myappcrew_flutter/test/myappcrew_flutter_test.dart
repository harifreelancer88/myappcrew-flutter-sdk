import 'package:flutter_test/flutter_test.dart';
import 'package:myappcrew_flutter/myappcrew_flutter.dart';
import 'package:myappcrew_flutter/src/client.dart';
import 'package:myappcrew_flutter/src/logger.dart';
import 'package:myappcrew_flutter/src/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeResponse {
  const _FakeResponse(this.statusCode, this.json);

  final int statusCode;
  final Map<String, dynamic>? json;
}

class _FakeClient extends MyAppCrewClient {
  _FakeClient({required this.responses})
      : super(
          timeout: const Duration(seconds: 1),
          logger: MyAppCrewLogger(false),
        );

  final List<_FakeResponse> responses;
  final List<Map<String, dynamic>> payloads = <Map<String, dynamic>>[];
  final List<String> urls = <String>[];
  int _index = 0;

  @override
  Future<MyAppCrewHttpResult> postJson(
    String url,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    urls.add(url);
    payloads.add(body);
    if (_index >= responses.length) {
      return const MyAppCrewHttpResult(statusCode: 500);
    }
    final response = responses[_index];
    _index += 1;
    return MyAppCrewHttpResult(
      statusCode: response.statusCode,
      json: response.json,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    MyAppCrewFlutter.resetForTesting();
  });

  test('disabled mode when publicKey missing', () async {
    await MyAppCrewFlutter.init();
    expect(MyAppCrewFlutter.isInitialized, isTrue);
    expect(MyAppCrewFlutter.isEnabled, isFalse);
  });

  test('disabled mode snapshot reports not initialized', () async {
    await MyAppCrewFlutter.init();
    final snapshot = MyAppCrewFlutter.getDebugSnapshot();
    expect(snapshot.initialized, isFalse);
    expect(snapshot.lastErrorCode, 'missing_public_key');
  });

  test('setDebugLogging toggles flag', () {
    MyAppCrewFlutter.setDebugLogging(true);
    expect(MyAppCrewFlutter.debugLoggingEnabled, isTrue);
    MyAppCrewFlutter.setDebugLogging(false);
    expect(MyAppCrewFlutter.debugLoggingEnabled, isFalse);
  });

  test('debug snapshot never includes tokens', () async {
    final fake = _FakeClient(
      responses: <_FakeResponse>[
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'eyJ_token_bootstrap',
          'testerId': 'tester_bootstrap',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
      ],
    );
    MyAppCrewFlutter.setClientForTesting(fake);

    await MyAppCrewFlutter.init(
      publicKey: 'pk_test',
      baseUrl: 'https://example.com',
      enableLogs: false,
    );

    final snapshot = MyAppCrewFlutter.getDebugSnapshot();
    final combined = <String>[
      snapshot.baseUrl,
      snapshot.publicKeyLast4,
      snapshot.testerId,
      snapshot.lastErrorCode ?? '',
    ].join('|');
    expect(combined.contains('eyJ'), isFalse);
  });

  test('connectFromText parses claim tokens from inputs', () async {
    final fake = _FakeClient(
      responses: <_FakeResponse>[
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'token_bootstrap',
          'testerId': 'tester_bootstrap',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'token_claim_1',
          'testerId': 'tester_1',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'token_claim_2',
          'testerId': 'tester_2',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'token_claim_3',
          'testerId': 'tester_3',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
      ],
    );
    MyAppCrewFlutter.setClientForTesting(fake);

    await MyAppCrewFlutter.init(
      publicKey: 'pk_test',
      baseUrl: 'https://example.com',
      enableLogs: false,
    );

    await MyAppCrewFlutter.connectFromText('claim_123');
    await MyAppCrewFlutter.connectFromText(
      'https://myappcrew-tw.pages.dev/claim/claim_456',
    );
    await MyAppCrewFlutter.connectFromText(
      'https://myappcrew-tw.pages.dev?publicKey=pk&claimToken=claim_789',
    );

    final claimTokens = fake.payloads
        .where((payload) => payload.containsKey('claimToken'))
        .map((payload) => payload['claimToken'])
        .toList();

    expect(
      claimTokens,
      <Object?>['claim_123', 'claim_456', 'claim_789'],
    );
  });

  test('connectFromText returns error for garbage input', () async {
    final fake = _FakeClient(
      responses: <_FakeResponse>[
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'token_bootstrap',
          'testerId': 'tester_bootstrap',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
        const _FakeResponse(400, <String, dynamic>{}),
      ],
    );
    MyAppCrewFlutter.setClientForTesting(fake);

    await MyAppCrewFlutter.init(
      publicKey: 'pk_test',
      baseUrl: 'https://example.com',
      enableLogs: false,
    );

    final result = await MyAppCrewFlutter.connectFromText('garbage_input');
    expect(result.connected, isFalse);
    expect(result.errorCode, 'claim_failed_400');
  });

  test('connectWithClaimToken retries once on 401', () async {
    final fake = _FakeClient(
      responses: <_FakeResponse>[
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'token_bootstrap_1',
          'testerId': 'tester_bootstrap_1',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
        const _FakeResponse(401, <String, dynamic>{}),
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'token_bootstrap_2',
          'testerId': 'tester_bootstrap_2',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
        const _FakeResponse(200, <String, dynamic>{
          'accessToken': 'token_claim_ok',
          'testerId': 'tester_claim_ok',
          'ingestUrl': '/api/v1/mobile/events/batch',
        }),
      ],
    );
    MyAppCrewFlutter.setClientForTesting(fake);

    await MyAppCrewFlutter.init(
      publicKey: 'pk_test',
      baseUrl: 'https://example.com',
      enableLogs: false,
    );

    final result = await MyAppCrewFlutter.connectWithClaimToken('claim_ok');

    final bootstrapCalls = fake.payloads
        .where((payload) => payload.containsKey('publicKey'))
        .length;
    final claimCalls = fake.payloads
        .where((payload) => payload.containsKey('claimToken'))
        .length;

    expect(result.connected, isTrue);
    expect(bootstrapCalls, 2);
    expect(claimCalls, 2);
  });
}
