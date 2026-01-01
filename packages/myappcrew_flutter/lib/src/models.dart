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
  });

  final bool connected;
  final String? testerId;
}
