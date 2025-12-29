class MyAppCrewConfig {
  MyAppCrewConfig({
    required this.publicKey,
    required this.baseUrl,
    required this.debugLogs,
    required this.timeout,
    required this.flushAt,
    required this.flushInterval,
    required this.forceRebootstrap,
    this.appVersion,
    this.buildNumber,
    this.inviteCode,
  });

  final String publicKey;
  final String baseUrl;
  final String? appVersion;
  final String? buildNumber;
  final String? inviteCode;
  final bool debugLogs;
  final Duration timeout;
  final int flushAt;
  final Duration flushInterval;
  final bool forceRebootstrap;
}
