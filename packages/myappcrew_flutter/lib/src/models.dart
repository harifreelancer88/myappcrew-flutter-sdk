class MyAppCrewInitResult {
  const MyAppCrewInitResult({required this.ok, this.reason});

  final bool ok;
  final String? reason;

  factory MyAppCrewInitResult.ok() => const MyAppCrewInitResult(ok: true);
  factory MyAppCrewInitResult.fail(String reason) =>
      MyAppCrewInitResult(ok: false, reason: reason);
}

class MyAppCrewAuth {
  const MyAppCrewAuth({
    required this.baseUrl,
    required this.publicKey,
    required this.accessToken,
    required this.testerId,
    this.ingestUrl,
    required this.savedAtSeconds,
  });

  final String baseUrl;
  final String publicKey;
  final String accessToken;
  final String testerId;
  final String? ingestUrl;
  final int savedAtSeconds;
}

class MyAppCrewHttpResult {
  const MyAppCrewHttpResult({
    required this.statusCode,
    this.json,
    this.rawBody,
  });

  final int statusCode;
  final Map<String, dynamic>? json;
  final String? rawBody;
}

class MyAppCrewConnectResult {
  const MyAppCrewConnectResult({
    required this.connected,
    this.testerId,
    this.inputKind,
    this.errorCode,
    this.message,
  });

  final bool connected;
  final String? testerId;
  final String? inputKind;
  final String? errorCode;
  final String? message;
}

class MyAppCrewTester {
  const MyAppCrewTester({
    required this.testerId,
    this.connectedAt,
    this.nickname,
  });

  final String testerId;
  final DateTime? connectedAt;
  final String? nickname;
}

class DebugSnapshot {
  const DebugSnapshot({
    required this.initialized,
    required this.baseUrl,
    required this.publicKeyLast4,
    required this.testerId,
    required this.connected,
    required this.lastErrorCode,
    required this.lastConnectInputKind,
    required this.queuedEventsCount,
    required this.lastFlushAt,
    required this.lastBootstrapAt,
  });

  final bool initialized;
  final String baseUrl;
  final String publicKeyLast4;
  final String testerId;
  final bool connected;
  final String? lastErrorCode;
  final String? lastConnectInputKind;
  final int queuedEventsCount;
  final DateTime? lastFlushAt;
  final DateTime? lastBootstrapAt;
}
