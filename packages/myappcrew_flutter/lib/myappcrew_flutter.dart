import 'dart:async';

export 'src/connect_ui.dart';
export 'src/ui/connect_prompt.dart';
export 'src/models.dart'
    show DebugSnapshot, MyAppCrewConnectResult, MyAppCrewTester;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import 'src/client.dart';
import 'src/config.dart';
import 'src/connect_ui.dart';
import 'src/lifecycle.dart';
import 'src/logger.dart';
import 'src/models.dart';
import 'src/navigator_observer.dart';
import 'src/queue.dart';
import 'src/storage.dart';
import 'src/tester_identity_store.dart';
import 'src/utils.dart';

enum AuthState { disconnected, connected, connectedAuthStale, revoked }

/// MyAppCrew SDK entry point.
class MyAppCrewFlutter {
  static const String _sdkVersion = '0.1.11';
  static const int _maxBatchSize = 50;
  static const String _defaultBaseUrl = 'https://myappcrew-tw.pages.dev';
  static const String _defaultIngestPath = '/api/v1/mobile/events/batch';
  static const Duration _defaultTimeout = Duration(seconds: 8);
  static const int _defaultFlushAt = 10;
  static const Duration _defaultFlushInterval = Duration(seconds: 12);
  static const bool _defaultDebugLogging = bool.fromEnvironment(
    'MYAPPCREW_DEBUG_LOGS',
    defaultValue: false,
  );

  static final Uuid _uuid = const Uuid();

  static MyAppCrewConfig? _config;
  static MyAppCrewLogger? _logger;
  static MyAppCrewClient? _client;
  static MyAppCrewStorage? _storage;
  static TesterIdentityStore? _testerIdentityStore;
  static MyAppCrewQueue? _queue;
  static Timer? _flushTimer;
  static MyAppCrewLifecycleObserver? _lifecycleObserver;

  static String? _accessToken;
  static String? _testerId;
  static TesterIdentity? _testerIdentity;
  static String? _sessionId;
  static String? _currentScreen;
  static String? _ingestUrl;
  static String? _lastError;
  static String? _lastConnectInputKind;
  static int? _lastBootstrapAt;
  static int? _lastFlushAt;
  static bool _isInitialized = false;
  static bool _isEnabled = false;
  static bool _isFlushing = false;
  static bool _rebootstrapAttempted = false;
  static bool _disabledLogEmitted = false;
  static bool _debugLoggingEnabled = _defaultDebugLogging;
  static bool _clientInjectedForTesting = false;
  static AuthState _authState = AuthState.disconnected;
  static int _authRecoveryBackoffSeconds = 5;
  static int? _nextAuthRecoveryAtSeconds;
  static void Function(String reason)? _onTesterIdentityInvalid;

  static Map<String, dynamic> _appContext = <String, dynamic>{};

  /// Whether initialize has completed (even if disabled).
  static bool get isInitialized => _isInitialized;

  /// Whether the SDK is enabled (publicKey present + bootstrap success).
  static bool get isEnabled => _isEnabled;

  /// Whether a non-anonymous tester identity is connected.
  static bool isTesterConnected() {
    return _isConnectedTesterId(_testerIdentity?.testerId ?? _testerId);
  }

  /// Returns the currently connected tester identity (without token).
  static MyAppCrewTester? getConnectedTester() {
    final identity = _testerIdentity;
    if (_isTesterConnected(identity)) {
      return MyAppCrewTester(
        testerId: identity!.testerId,
        connectedAt: _toDateTime(identity.connectedAtSeconds),
      );
    }
    if (!_isConnectedTesterId(_testerId)) {
      return null;
    }
    return MyAppCrewTester(testerId: _testerId!);
  }

  /// Clears the connected tester identity and stored auth.
  static Future<void> disconnectTester() async {
    await _testerIdentityStore?.clearIdentity();
    await _storage?.clearAuth();
    _testerIdentity = null;
    _testerId = null;
    _accessToken = null;
    _ingestUrl = null;
    _authState = AuthState.disconnected;
    _isEnabled = false;
    if (_config != null && _hasPublicKey) {
      final ok = await _bootstrap();
      _isEnabled = ok;
    }
  }

  /// Connect using a 6-digit code.
  static Future<MyAppCrewConnectResult> connectTester(String code) =>
      connectFromText(code);

  /// Set a callback for invalid/revoked tester identities.
  static void setOnTesterIdentityInvalid(
    void Function(String reason)? handler,
  ) {
    _onTesterIdentityInvalid = handler;
  }

  /// Returns a safe snapshot of SDK state for debugging.
  static DebugSnapshot getDebugSnapshot() {
    final publicKey = _config?.publicKey ?? '';
    final last4 = publicKey.isEmpty
        ? ''
        : publicKey.length <= 4
            ? publicKey
            : publicKey.substring(publicKey.length - 4);
    final testerId = _testerId ?? '';
    final initialized = _isInitialized && _hasPublicKey;
    final isAnonymous = testerId.startsWith('tst_');
    final connected = initialized && testerId.isNotEmpty && !isAnonymous;
    return DebugSnapshot(
      initialized: initialized,
      baseUrl: _config?.baseUrl ?? _defaultBaseUrl,
      publicKeyLast4: last4,
      testerId: testerId,
      connected: connected,
      lastErrorCode: _lastError,
      lastConnectInputKind: _lastConnectInputKind,
      queuedEventsCount: _queue?.length ?? 0,
      lastFlushAt: _toDateTime(_lastFlushAt),
      lastBootstrapAt: _toDateTime(_lastBootstrapAt),
    );
  }

  @Deprecated('Use getDebugSnapshot instead.')
  static Map<String, dynamic> debugSnapshot() {
    final snapshot = getDebugSnapshot();
    return <String, dynamic>{
      'initialized': snapshot.initialized,
      'baseUrl': snapshot.baseUrl,
      'publicKeyLast4': snapshot.publicKeyLast4,
      'testerId': snapshot.testerId,
      'connected': snapshot.connected,
      'lastErrorCode': snapshot.lastErrorCode,
      'lastConnectInputKind': snapshot.lastConnectInputKind,
      'queuedEventsCount': snapshot.queuedEventsCount,
      'lastFlushAt': snapshot.lastFlushAt?.toIso8601String(),
      'lastBootstrapAt': snapshot.lastBootstrapAt?.toIso8601String(),
    };
  }

  /// Initialize the SDK.
  static Future<void> init({
    String? publicKey,
    String? baseUrl,
    bool? enableLogs,
  }) async {
    final debugLogs = enableLogs ?? _debugLoggingEnabled;
    final normalizedBaseUrl = normalizeBaseUrl(baseUrl ?? _defaultBaseUrl);
    final trimmedKey = publicKey?.trim() ?? '';

    _applyDebugLogging(debugLogs);
    _config = MyAppCrewConfig(
      publicKey: trimmedKey,
      baseUrl: normalizedBaseUrl,
      debugLogs: debugLogs,
      timeout: _defaultTimeout,
      flushAt: _defaultFlushAt,
      flushInterval: _defaultFlushInterval,
      forceRebootstrap: false,
    );
    _logger ??= MyAppCrewLogger(debugLogs);
    _client ??= MyAppCrewClient(timeout: _defaultTimeout, logger: _logger!);
    _storage ??= MyAppCrewStorage();
    _testerIdentityStore ??= TesterIdentityStore();
    _queue ??= MyAppCrewQueue();
    _ensureSessionId();
    _appContext = await _loadAppContext();
    await _loadTesterIdentity(trimmedKey);

    _isInitialized = false;
    _isEnabled = false;
    _lastError = null;

    if (trimmedKey.isEmpty) {
      _accessToken = null;
      _testerIdentity = null;
      _testerId = null;
      _ingestUrl = null;
      _lastError = 'missing_public_key';
      _emitDisabledLogOnce();
      _isInitialized = true;
      _startObservers();
      return;
    }

    _logger?.log('init start');
    final persisted = await _storage?.loadAuth();
    if (!_config!.forceRebootstrap && _isAuthReusable(persisted)) {
      _accessToken = persisted?.accessToken;
      if (!_isTesterConnected(_testerIdentity)) {
        _testerId = persisted?.testerId;
      } else {
        _testerId = _testerIdentity?.testerId ?? _testerId;
      }
      _ingestUrl = persisted?.ingestUrl ?? _defaultIngestPath;
      _authState = _isConnectedTesterId(_testerId)
          ? AuthState.connected
          : AuthState.disconnected;
      _isInitialized = true;
      _isEnabled = true;
      _lastError = null;
      _syncQueuedEventsWithTester();
      _startObservers();
      logEvent('app_open');
      _logger?.log('init ok (cached)');
      return;
    }

    if (_isConnectedTesterId(_testerIdentity?.testerId ?? _testerId)) {
      _authState = AuthState.connectedAuthStale;
      final ok = await _recoverAuthForConnectedTester();
      _isInitialized = true;
      _isEnabled = true;
      _startObservers();
      logEvent('app_open');
      if (!ok) {
        _lastError ??= 'auth_stale';
        _logger?.log('init ok (auth stale)');
        return;
      }
      _logger?.log('init ok (recovered)');
      return;
    }

    final ok = await _bootstrap();
    _isInitialized = true;
    _isEnabled = ok;
    _startObservers();
    logEvent('app_open');
    if (!ok) {
      _lastError ??= 'bootstrap_failed';
      _logger?.log('init failed');
      return;
    }
    _logger?.log('init ok');
  }

  /// Enable or disable SDK debug logging.
  static void setDebugLogging(bool enabled) {
    _applyDebugLogging(enabled);
  }

  @visibleForTesting
  static bool get debugLoggingEnabled => _debugLoggingEnabled;

  /// Log an event. Safe to call before init.
  static void logEvent(String name, {Map<String, dynamic>? params}) {
    try {
      _queue ??= MyAppCrewQueue();
      _ensureSessionId();

      final event = <String, dynamic>{
        'name': name,
        'ts': unixSeconds(),
        'sessionId': _sessionId,
      };

      final testerId = _resolvedTesterIdForEvent();
      if (testerId != null) {
        event['testerId'] = testerId;
      }
      if (_currentScreen != null) {
        event['screen'] = _currentScreen;
      }
      if (_appContext.isNotEmpty) {
        event.addAll(_appContext);
      }
      if (params != null && params.isNotEmpty) {
        event['properties'] = params;
      }

      _queue?.add(event);
      if (_config != null && _queue!.length >= _config!.flushAt) {
        unawaited(flushNow());
      }
    } catch (_) {}
  }

  /// Flush queued events now.
  static Future<void> flushNow() async {
    await _flush('manual');
  }

  /// Navigator observer for auto screen tracking.
  static NavigatorObserver? navigatorObserver() {
    if (!_isInitialized || !_isEnabled) {
      return null;
    }
    return MyAppCrewNavigatorObserver(
      onScreenChange: (screen) {
        _currentScreen = screen;
        logEvent('screen_view');
      },
    );
  }

  /// Connect using a claim token.
  static Future<MyAppCrewConnectResult> connectWithClaimToken(
    String claimToken,
  ) async {
    return _connectWithClaim(
      claimToken: claimToken,
      inputKind: 'token',
    );
  }

  /// Connect using text that may include a claim token or URL.
  static Future<MyAppCrewConnectResult> connectFromText(
    String input, {
    String? publicKeyOverride,
  }) async {
    final parsed = parseConnectInput(input);
    _lastConnectInputKind = parsed.inputKind;

    final overrideKey = publicKeyOverride?.trim();
    final parsedKey = parsed.parsedPublicKey?.trim();
    final targetKey =
        (overrideKey != null && overrideKey.isNotEmpty) ? overrideKey : parsedKey;
    if (targetKey != null &&
        targetKey.isNotEmpty &&
        _config != null &&
        _config!.publicKey != targetKey) {
      await init(
        publicKey: targetKey,
        baseUrl: _config!.baseUrl,
        enableLogs: _debugLoggingEnabled,
      );
    }

    if (parsed.inputKind == 'code' && parsed.connectCode != null) {
      return _connectWithClaim(
        connectCode: parsed.connectCode,
        inputKind: parsed.inputKind,
      );
    }

    if (parsed.claimToken != null && parsed.claimToken!.isNotEmpty) {
      return _connectWithClaim(
        claimToken: parsed.claimToken,
        inputKind: parsed.inputKind,
      );
    }

    _lastError = 'claim_token_missing';
    return MyAppCrewConnectResult(
      connected: false,
      inputKind: parsed.inputKind,
      errorCode: 'claim_token_missing',
      message: 'Claim token missing',
    );
  }

  static Future<MyAppCrewConnectResult> _connectWithClaim({
    String? claimToken,
    String? connectCode,
    required String inputKind,
  }) async {
    _lastConnectInputKind = inputKind;
    final token = claimToken?.trim() ?? '';
    final code = connectCode?.trim() ?? '';

    if (token.isEmpty && code.isEmpty) {
      _lastError = 'claim_token_missing';
      return MyAppCrewConnectResult(
        connected: false,
        inputKind: inputKind,
        errorCode: 'claim_token_missing',
        message: 'Claim token missing',
      );
    }
    if (token.isNotEmpty && code.isNotEmpty) {
      _lastError = 'claim_payload_conflict';
      return MyAppCrewConnectResult(
        connected: false,
        inputKind: inputKind,
        errorCode: 'claim_payload_conflict',
        message: 'Claim payload conflict',
      );
    }
    if (_config == null) {
      _lastError = 'not_initialized';
      return MyAppCrewConnectResult(
        connected: false,
        inputKind: inputKind,
        errorCode: 'not_initialized',
        message: 'SDK not initialized',
      );
    }
    if (!_hasPublicKey) {
      _lastError = 'missing_public_key';
      _emitDisabledLogOnce();
      return MyAppCrewConnectResult(
        connected: false,
        inputKind: inputKind,
        errorCode: 'missing_public_key',
        message: 'Missing public key',
      );
    }

    if (_accessToken == null || _accessToken!.isEmpty) {
      if (_isConnectedTesterId(_testerIdentity?.testerId ?? _testerId)) {
        final ok = await _recoverAuthForConnectedTester();
        if (!ok) {
          return MyAppCrewConnectResult(
            connected: false,
            inputKind: inputKind,
            errorCode: 'auth_stale',
            message: 'Auth recovery failed',
          );
        }
      } else {
        final ok = await _bootstrap();
        if (!ok) {
          _isEnabled = false;
          return MyAppCrewConnectResult(
            connected: false,
            inputKind: inputKind,
            errorCode: _lastError ?? 'bootstrap_failed',
            message: 'Bootstrap failed',
          );
        }
      }
    }

    _rebootstrapAttempted = false;
    var result = await _postClaim(
      claimToken: token.isNotEmpty ? token : null,
      connectCode: code.isNotEmpty ? code : null,
    );
    if ((result.statusCode == 401 || result.statusCode == 403) &&
        !_rebootstrapAttempted) {
      _rebootstrapAttempted = true;
      final ok =
          _isConnectedTesterId(_testerIdentity?.testerId ?? _testerId)
              ? await _recoverAuthForConnectedTester()
              : await _bootstrap();
      if (ok) {
        result = await _postClaim(
          claimToken: token.isNotEmpty ? token : null,
          connectCode: code.isNotEmpty ? code : null,
        );
      }
    }

    return _applyClaimResult(result, inputKind);
  }

  static Future<void> showConnectSheet(
    BuildContext context, {
    bool showAsBottomSheet = true,
    String title = 'Connect tester',
    String subtitle = 'Enter the 6-digit Connect Code from your invite.',
    bool allowDismiss = true,
  }) async {
    await showMyAppCrewConnectSheet(
      context,
      showAsBottomSheet: showAsBottomSheet,
      title: title,
      subtitle: subtitle,
      allowDismiss: allowDismiss,
    );
  }

  static void _ensureSessionId() {
    _sessionId ??= _uuid.v4();
  }

  static bool _isConnectedTesterId(String? testerId) {
    return testerId != null &&
        testerId.isNotEmpty &&
        !testerId.startsWith('tst_');
  }

  static String? _connectedTesterId() {
    final identity = _testerIdentity;
    if (_isTesterConnected(identity)) {
      return identity!.testerId;
    }
    if (_isConnectedTesterId(_testerId)) {
      return _testerId;
    }
    return null;
  }

  static String? _resolvedTesterIdForEvent() {
    final connectedTesterId = _connectedTesterId();
    return connectedTesterId ?? _testerId;
  }

  static bool _isTesterConnected(TesterIdentity? identity) {
    return identity != null && identity.isConnected;
  }

  static Future<void> _loadTesterIdentity(String currentPublicKey) async {
    if (currentPublicKey.isEmpty) {
      _testerIdentity = null;
      _testerId = null;
      _authState = AuthState.disconnected;
      return;
    }
    final identity = await _testerIdentityStore?.getIdentity();
    if (identity == null) {
      _authState = AuthState.disconnected;
      return;
    }
    if (identity.appPublicKey != currentPublicKey) {
      await _testerIdentityStore?.clearIdentity();
      _testerIdentity = null;
      _testerId = null;
      _authState = AuthState.disconnected;
      return;
    }
    _testerIdentity = identity;
    _testerId = identity.testerId;
    _authState =
        identity.isConnected ? AuthState.connected : AuthState.disconnected;
    _logger?.log('identity loaded (${identity.testerId})');
    if ((_accessToken == null || _accessToken!.isEmpty) &&
        identity.sessionToken != null &&
        identity.sessionToken!.isNotEmpty) {
      _accessToken = identity.sessionToken;
    }
    _syncQueuedEventsWithTester();
  }

  static void _syncQueuedEventsWithTester() {
    final testerId = _resolvedTesterIdForEvent();
    if (testerId == null || testerId.isEmpty) {
      return;
    }
    if (_isConnectedTesterId(testerId)) {
      _queue?.forceTesterId(testerId);
    } else {
      _queue?.attachTesterId(testerId);
    }
  }

  static void _applyDebugLogging(bool enabled) {
    _debugLoggingEnabled = enabled;
    _logger = MyAppCrewLogger(enabled);
    if (_client != null && !_clientInjectedForTesting) {
      final timeout = _config?.timeout ?? _defaultTimeout;
      _client = MyAppCrewClient(timeout: timeout, logger: _logger!);
    }
    if (_config != null) {
      _config = _cloneConfig(_config!, debugLogs: enabled);
    }
  }

  static bool get _hasPublicKey {
    final publicKey = _config?.publicKey;
    return publicKey != null && publicKey.trim().isNotEmpty;
  }

  static MyAppCrewConfig _cloneConfig(
    MyAppCrewConfig config, {
    required bool debugLogs,
  }) {
    return MyAppCrewConfig(
      publicKey: config.publicKey,
      baseUrl: config.baseUrl,
      debugLogs: debugLogs,
      timeout: config.timeout,
      flushAt: config.flushAt,
      flushInterval: config.flushInterval,
      forceRebootstrap: config.forceRebootstrap,
      appVersion: config.appVersion,
      buildNumber: config.buildNumber,
    );
  }

  static void _emitDisabledLogOnce() {
    if (_disabledLogEmitted) {
      return;
    }
    _disabledLogEmitted = true;
    if (_debugLoggingEnabled) {
      _logger?.log(
        'MyAppCrew disabled: missing publicKey. '
        'Paste your key into MyAppCrewFlutter.init(publicKey: ...)',
      );
    }
  }

  static bool _isAuthReusable(MyAppCrewAuth? auth) {
    if (auth == null || _config == null) {
      return false;
    }
    final connectedTesterId = _connectedTesterId();
    if (connectedTesterId != null && auth.testerId != connectedTesterId) {
      return false;
    }
    return auth.baseUrl == _config!.baseUrl &&
        auth.publicKey == _config!.publicKey &&
        auth.accessToken.isNotEmpty;
  }

  static bool _shouldInvalidateIdentity(MyAppCrewHttpResult result) {
    final testerId = _testerIdentity?.testerId ?? _testerId;
    if (testerId == null ||
        testerId.isEmpty ||
        testerId.startsWith('tst_')) {
      return false;
    }
    final errorText = _collectErrorText(result);
    if (errorText.isEmpty) {
      return false;
    }
    return _containsAny(errorText, <String>[
      'revoked tester',
      'tester revoked',
      'tester removed',
      'tester not found',
      'unknown tester',
      'invite revoked',
      'revoked_tester',
      'tester_removed',
      'invite_revoked',
    ]);
  }

  static String _collectErrorText(MyAppCrewHttpResult result) {
    final parts = <String>[];
    final json = result.json;
    if (json != null) {
      for (final key in <String>[
        'error',
        'errorCode',
        'code',
        'message',
        'detail',
        'reason',
      ]) {
        final value = json[key];
        if (value is String && value.isNotEmpty) {
          parts.add(value);
        }
      }
    }
    if (result.rawBody != null && result.rawBody!.isNotEmpty) {
      parts.add(result.rawBody!);
    }
    return parts.join(' ').toLowerCase();
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  static Future<void> _invalidateTesterIdentity(String reason) async {
    final testerId = _testerIdentity?.testerId ?? _testerId;
    if (testerId == null ||
        testerId.isEmpty ||
        testerId.startsWith('tst_')) {
      return;
    }
    _logger?.log('identity revoked ($reason)');
    _testerIdentity = null;
    _testerId = null;
    _accessToken = null;
    _ingestUrl = null;
    _isEnabled = false;
    _authState = AuthState.revoked;
    await _testerIdentityStore?.clearIdentity();
    await _storage?.clearAuth();
    _onTesterIdentityInvalid?.call(reason);
  }

  static Future<Map<String, dynamic>> _loadAppContext() async {
    final context = <String, dynamic>{};
    try {
      final info = await PackageInfo.fromPlatform();
      context['packageName'] = info.packageName;
      context['appVersion'] = info.version;
      context['buildNumber'] = info.buildNumber;
    } catch (_) {}

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        context['platform'] = 'web';
        context['deviceModel'] = webInfo.browserName.name;
        context['osVersion'] = webInfo.appVersion;
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await deviceInfo.androidInfo;
            context['platform'] = 'android';
            context['deviceModel'] = info.model;
            context['osVersion'] = info.version.release;
            break;
          case TargetPlatform.iOS:
            final info = await deviceInfo.iosInfo;
            context['platform'] = 'ios';
            context['deviceModel'] = info.utsname.machine;
            context['osVersion'] = info.systemVersion;
            break;
          case TargetPlatform.macOS:
            final info = await deviceInfo.macOsInfo;
            context['platform'] = 'macos';
            context['deviceModel'] = info.model;
            context['osVersion'] = info.osRelease;
            break;
          case TargetPlatform.windows:
            final info = await deviceInfo.windowsInfo;
            context['platform'] = 'windows';
            context['deviceModel'] = info.computerName;
            context['osVersion'] = info.displayVersion;
            break;
          case TargetPlatform.linux:
            final info = await deviceInfo.linuxInfo;
            context['platform'] = 'linux';
            context['deviceModel'] = info.name;
            context['osVersion'] = info.version;
            break;
          case TargetPlatform.fuchsia:
            context['platform'] = 'fuchsia';
            break;
        }
      }
    } catch (_) {}

    return context;
  }

  static void _startObservers() {
    try {
      _flushTimer?.cancel();
      if (_config != null) {
        _flushTimer = Timer.periodic(
          _config!.flushInterval,
          (_) => unawaited(_flush('timer')),
        );
      }
    } catch (_) {}

    try {
      final binding = WidgetsBinding.instance;
      if (_lifecycleObserver != null) {
        binding.removeObserver(_lifecycleObserver!);
      }
      _lifecycleObserver = MyAppCrewLifecycleObserver(
        onBackground: () {
          logEvent('app_background');
          unawaited(_flush('lifecycle'));
        },
        onForeground: () {
          logEvent('app_foreground');
        },
      );
      binding.addObserver(_lifecycleObserver!);
    } catch (_) {}
  }

  static Future<bool> _bootstrap({
    String? testerId,
    String? sessionToken,
  }) async {
    if (_config == null || _client == null || _storage == null) {
      return false;
    }
    try {
      final hasProof = testerId != null && testerId.isNotEmpty;
      _logger?.log(hasProof ? 'bootstrap (connected) start' : 'bootstrap start');
      final payload = <String, dynamic>{
        'publicKey': _config!.publicKey,
        'ts': unixSeconds(),
        'sdkVersion': _sdkVersion,
      };
      if (hasProof) {
        payload['testerId'] = testerId;
        if (sessionToken != null && sessionToken.isNotEmpty) {
          payload['sessionToken'] = sessionToken;
        }
      }
      if (_appContext.isNotEmpty) {
        payload.addAll(_appContext);
      }

      final url = joinBaseUrlAndPath(
        _config!.baseUrl,
        '/api/v1/mobile/bootstrap',
      );
      final result = await _client!.postJson(url, payload);
      final token = firstStringKey(result.json, <String>[
        'accessToken',
        'access_token',
        'token',
        'jwt',
      ]);
      final responseTesterId = firstStringKey(result.json, <String>[
        'testerId',
        'tester_id',
        'id',
      ]);
      final refreshToken = firstStringKey(result.json, <String>[
        'refreshToken',
        'refresh_token',
      ]);
      final ingestUrl = firstStringKey(result.json, <String>[
        'ingestUrl',
        'ingest_url',
      ]);
      if (result.statusCode < 200 || result.statusCode >= 300) {
        _lastError = 'bootstrap_failed_${result.statusCode}';
        _logger?.log('bootstrap failed (${result.statusCode})');
        _isEnabled = false;
        return false;
      }
      if (token == null || responseTesterId == null) {
        _lastError = 'bootstrap_missing_fields';
        _logger?.log('bootstrap missing fields');
        _isEnabled = false;
        return false;
      }
      if (hasProof) {
        final expectedId = payload['testerId'] as String;
        if (responseTesterId != expectedId ||
            responseTesterId.startsWith('tst_')) {
          _lastError = 'bootstrap_identity_mismatch';
          _logger?.log('bootstrap identity mismatch');
          return false;
        }
      }

      _accessToken = token;
      if (hasProof) {
        _testerId = payload['testerId'] as String;
      } else if (!_isTesterConnected(_testerIdentity)) {
        _testerId = responseTesterId;
      }
      _ingestUrl = ingestUrl ?? _defaultIngestPath;
      _lastBootstrapAt = unixSeconds();
      await _updateConnectedIdentityTokens(
        accessToken: token,
        testerId: _testerId,
        refreshToken: refreshToken,
      );
      await _storage!.saveAuth(
        MyAppCrewAuth(
          baseUrl: _config!.baseUrl,
          publicKey: _config!.publicKey,
          accessToken: token,
          testerId: _testerId ?? responseTesterId,
          ingestUrl: _ingestUrl,
          savedAtSeconds: unixSeconds(),
        ),
      );
      _syncQueuedEventsWithTester();

      _logger?.log('bootstrap ok');
      _lastError = null;
      _isEnabled = true;
      _authState = _isConnectedTesterId(_testerId)
          ? AuthState.connected
          : AuthState.disconnected;
      return true;
    } catch (_) {
      _lastError = 'bootstrap_exception';
      _logger?.log('bootstrap exception');
      _isEnabled = false;
      return false;
    }
  }

  static Future<void> _updateConnectedIdentityTokens({
    required String? testerId,
    required String accessToken,
    String? refreshToken,
  }) async {
    if (!_isConnectedTesterId(testerId) || _config == null) {
      return;
    }
    final connectedAt = _testerIdentity?.connectedAtSeconds ?? unixSeconds();
    _testerIdentity = TesterIdentity(
      testerId: testerId!,
      appPublicKey: _config!.publicKey,
      sessionToken: accessToken,
      refreshToken: refreshToken ?? _testerIdentity?.refreshToken,
      connectedAtSeconds: connectedAt,
    );
    await _testerIdentityStore?.saveIdentity(_testerIdentity!);
  }

  static Future<bool> _recoverAuthForConnectedTester() async {
    if (_client == null || _config == null || _storage == null) {
      return false;
    }
    final testerId = _connectedTesterId();
    if (!_isConnectedTesterId(testerId)) {
      return false;
    }
    final now = unixSeconds();
    if (_nextAuthRecoveryAtSeconds != null &&
        now < _nextAuthRecoveryAtSeconds!) {
      _logger?.log('auth recovery backoff');
      return false;
    }
    _logger?.log('auth recovery attempt');
    final identity = _testerIdentity;
    final sessionToken = identity?.sessionToken ?? _accessToken;
    final refreshToken = identity?.refreshToken;

    if ((refreshToken != null && refreshToken.isNotEmpty) ||
        (sessionToken != null && sessionToken.isNotEmpty)) {
      final ok = await _refreshAuth(
        testerId: testerId!,
        sessionToken: sessionToken,
        refreshToken: refreshToken,
      );
      if (ok) {
        _authState = AuthState.connected;
        _authRecoveryBackoffSeconds = 5;
        _nextAuthRecoveryAtSeconds = null;
        _logger?.log('auth recovery ok');
        return true;
      }
    }

    final ok = await _bootstrap(
      testerId: testerId,
      sessionToken: sessionToken,
    );
    if (ok) {
      _authState = AuthState.connected;
      _authRecoveryBackoffSeconds = 5;
      _nextAuthRecoveryAtSeconds = null;
      _logger?.log('auth recovery ok');
      return true;
    }

    _authState = AuthState.connectedAuthStale;
    _nextAuthRecoveryAtSeconds = now + _authRecoveryBackoffSeconds;
    if (_authRecoveryBackoffSeconds < 300) {
      final nextBackoff =
          (_authRecoveryBackoffSeconds * 2).clamp(5, 300);
      _authRecoveryBackoffSeconds = nextBackoff.toInt();
    }
    _logger?.log('auth recovery failed');
    return false;
  }

  static Future<bool> _refreshAuth({
    required String testerId,
    String? sessionToken,
    String? refreshToken,
  }) async {
    if (_client == null || _config == null || _storage == null) {
      return false;
    }
    try {
      final payload = <String, dynamic>{
        'testerId': testerId,
        'ts': unixSeconds(),
        'sdkVersion': _sdkVersion,
      };
      if (sessionToken != null && sessionToken.isNotEmpty) {
        payload['sessionToken'] = sessionToken;
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        payload['refreshToken'] = refreshToken;
      }
      if (_appContext.isNotEmpty) {
        payload.addAll(_appContext);
      }
      final url = joinBaseUrlAndPath(
        _config!.baseUrl,
        '/api/v1/mobile/refresh',
      );
      final result = await _client!.postJson(url, payload);
      if (result.statusCode < 200 || result.statusCode >= 300) {
        return false;
      }
      final token = firstStringKey(result.json, <String>[
        'accessToken',
        'access_token',
        'token',
        'jwt',
      ]);
      if (token == null || token.isEmpty) {
        return false;
      }
      final responseTesterId = firstStringKey(result.json, <String>[
        'testerId',
        'tester_id',
        'id',
      ]);
      if (responseTesterId != null && responseTesterId != testerId) {
        return false;
      }
      final newRefreshToken = firstStringKey(result.json, <String>[
        'refreshToken',
        'refresh_token',
      ]);
      final ingestUrl = firstStringKey(result.json, <String>[
        'ingestUrl',
        'ingest_url',
      ]);
      _accessToken = token;
      _testerId = testerId;
      if (ingestUrl != null && ingestUrl.isNotEmpty) {
        _ingestUrl = ingestUrl;
      }
      await _updateConnectedIdentityTokens(
        testerId: testerId,
        accessToken: token,
        refreshToken: newRefreshToken,
      );
      await _storage!.saveAuth(
        MyAppCrewAuth(
          baseUrl: _config!.baseUrl,
          publicKey: _config!.publicKey,
          accessToken: token,
          testerId: testerId,
          ingestUrl: _ingestUrl ?? _defaultIngestPath,
          savedAtSeconds: unixSeconds(),
        ),
      );
      _syncQueuedEventsWithTester();
      _logger?.log('auth refresh ok');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<MyAppCrewHttpResult> _postClaim({
    String? claimToken,
    String? connectCode,
  }) async {
    if (_client == null || _config == null || _accessToken == null) {
      return const MyAppCrewHttpResult(statusCode: 0);
    }
    try {
      final payload = <String, dynamic>{
        'ts': unixSeconds(),
        'sdkVersion': _sdkVersion,
      };
      if (claimToken != null && claimToken.isNotEmpty) {
        payload['claimToken'] = claimToken;
      }
      if (connectCode != null && connectCode.isNotEmpty) {
        payload['connectCode'] = connectCode;
      }
      if (_appContext.isNotEmpty) {
        payload.addAll(_appContext);
      }
      final url = joinBaseUrlAndPath(_config!.baseUrl, '/api/v1/mobile/claim');
      return _client!.postJson(
        url,
        payload,
        headers: <String, String>{'Authorization': 'Bearer $_accessToken'},
      );
    } catch (_) {
      return const MyAppCrewHttpResult(statusCode: 0);
    }
  }

  static Future<MyAppCrewConnectResult> _applyClaimResult(
    MyAppCrewHttpResult result,
    String inputKind,
  ) async {
    if (_shouldInvalidateIdentity(result)) {
      await _invalidateTesterIdentity('claim_unauthorized');
      return MyAppCrewConnectResult(
        connected: false,
        inputKind: inputKind,
        errorCode: 'claim_unauthorized',
        message: 'Claim unauthorized',
      );
    }
    if (result.statusCode < 200 || result.statusCode >= 300) {
      _lastError = 'claim_failed_${result.statusCode}';
      _logger?.log('claim failed (${result.statusCode})');
      return MyAppCrewConnectResult(
        connected: false,
        inputKind: inputKind,
        errorCode: _lastError,
        message: 'Claim failed',
      );
    }

    final token = firstStringKey(result.json, <String>[
      'accessToken',
      'access_token',
      'token',
      'jwt',
    ]);
    final testerId = firstStringKey(result.json, <String>[
      'testerId',
      'tester_id',
      'id',
    ]);
    final refreshToken = firstStringKey(result.json, <String>[
      'refreshToken',
      'refresh_token',
    ]);
    final ingestUrl = firstStringKey(result.json, <String>[
      'ingestUrl',
      'ingest_url',
    ]);
    if (token == null || testerId == null) {
      _lastError = 'claim_missing_fields';
      _logger?.log('claim missing fields');
      return MyAppCrewConnectResult(
        connected: false,
        inputKind: inputKind,
        errorCode: 'claim_missing_fields',
        message: 'Claim response missing fields',
      );
    }

    _accessToken = token;
    _testerId = testerId;
    _ingestUrl = ingestUrl ?? _defaultIngestPath;
    final connectedAt = unixSeconds();
    if (_config != null) {
      _testerIdentity = TesterIdentity(
        testerId: testerId,
        appPublicKey: _config!.publicKey,
        sessionToken: token,
        refreshToken: refreshToken,
        connectedAtSeconds: connectedAt,
      );
      await _testerIdentityStore?.saveIdentity(_testerIdentity!);
    }
    if (_storage != null && _config != null) {
      await _storage!.saveAuth(
        MyAppCrewAuth(
          baseUrl: _config!.baseUrl,
          publicKey: _config!.publicKey,
          accessToken: token,
          testerId: testerId,
          ingestUrl: _ingestUrl,
          savedAtSeconds: connectedAt,
        ),
      );
    }
    _isEnabled = true;
    _authState = AuthState.connected;
    _lastError = null;
    _syncQueuedEventsWithTester();

    if (_queue != null && _queue!.length > 0) {
      unawaited(flushNow());
    }

    return MyAppCrewConnectResult(
      connected: true,
      testerId: testerId,
      inputKind: inputKind,
    );
  }

  static Future<void> _flush(String reason) async {
    if (_isFlushing) {
      return;
    }
    if (_queue == null || _queue!.isEmpty) {
      return;
    }
    if (_authState == AuthState.revoked) {
      return;
    }
    if (_client == null || _config == null) {
      return;
    }
    _isFlushing = true;
    try {
      if (_authState == AuthState.connectedAuthStale) {
        final recovered = await _recoverAuthForConnectedTester();
        if (!recovered) {
          return;
        }
      }
      if (_accessToken == null) {
        return;
      }
      final batch = _queue!.snapshot(_maxBatchSize);
      if (batch.isEmpty) {
        return;
      }
      final success = await _sendWithRetry(batch);
      if (success) {
        _queue!.removeFirst(batch.length);
        _lastFlushAt = unixSeconds();
        _logger?.log('flush ok (${batch.length})');
      } else {
        _logger?.log('flush failed (${batch.length})');
      }
    } catch (_) {
      _logger?.log('flush exception');
    } finally {
      _isFlushing = false;
    }
  }

  static Future<bool> _sendWithRetry(List<Map<String, dynamic>> batch) async {
    _rebootstrapAttempted = false;
    var result = await _postBatch(batch);
    if (result == _SendResult.success) {
      return true;
    }
    if (result == _SendResult.invalidIdentity) {
      return _handleInvalidIdentity(batch);
    }
    if (result == _SendResult.unauthorized) {
      return _handleUnauthorized(batch);
    }

    for (final delayMs in <int>[500, 1000]) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      result = await _postBatch(batch);
      if (result == _SendResult.success) {
        return true;
      }
      if (result == _SendResult.invalidIdentity) {
        return _handleInvalidIdentity(batch);
      }
      if (result == _SendResult.unauthorized) {
        return _handleUnauthorized(batch);
      }
    }

    return false;
  }

  static Future<bool> _handleInvalidIdentity(
    List<Map<String, dynamic>> batch,
  ) async {
    await _invalidateTesterIdentity('tester_revoked');
    return false;
  }

  static Future<bool> _handleUnauthorized(
    List<Map<String, dynamic>> batch,
  ) async {
    if (_isConnectedTesterId(_testerIdentity?.testerId ?? _testerId)) {
      _authState = AuthState.connectedAuthStale;
      _logger?.log('unauthorized for connected tester');
      final ok = await _recoverAuthForConnectedTester();
      if (!ok) {
        return false;
      }
      final retry = await _postBatch(batch);
      return retry == _SendResult.success;
    }
    if (_rebootstrapAttempted) {
      return false;
    }
    _rebootstrapAttempted = true;
    final ok = await _bootstrap();
    if (!ok) {
      return false;
    }
    final retry = await _postBatch(batch);
    return retry == _SendResult.success;
  }

  static Future<_SendResult> _postBatch(
    List<Map<String, dynamic>> batch,
  ) async {
    if (_client == null || _config == null || _accessToken == null) {
      return _SendResult.failed;
    }
    final connectedTesterId = _connectedTesterId();
    final resolvedTesterId = _resolvedTesterIdForEvent();
    if (_isTesterConnected(_testerIdentity) &&
        (resolvedTesterId == null || resolvedTesterId.startsWith('tst_'))) {
      _logger?.log('blocked anonymous send for connected tester');
      return _SendResult.failed;
    }
    try {
      if (_isConnectedTesterId(connectedTesterId)) {
        for (final event in batch) {
          event['testerId'] = connectedTesterId;
        }
      }
      final ingestPath = _ingestUrl ?? _defaultIngestPath;
      final url = joinBaseUrlAndPath(_config!.baseUrl, ingestPath);
      final result = await _client!.postJson(
        url,
        <String, dynamic>{'events': batch},
        headers: <String, String>{'Authorization': 'Bearer $_accessToken'},
      );
      if (_shouldInvalidateIdentity(result)) {
        return _SendResult.invalidIdentity;
      }
      if (result.statusCode == 401 || result.statusCode == 403) {
        return _SendResult.unauthorized;
      }
      if (result.statusCode >= 200 && result.statusCode < 300) {
        return _SendResult.success;
      }
      return _SendResult.failed;
    } catch (_) {
      return _SendResult.failed;
    }
  }

  static DateTime? _toDateTime(int? seconds) {
    if (seconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  @visibleForTesting
  static void setClientForTesting(MyAppCrewClient client) {
    _client = client;
    _clientInjectedForTesting = true;
  }

  @visibleForTesting
  static void resetForTesting() {
    _config = null;
    _logger = null;
    _client = null;
    _storage = null;
    _testerIdentityStore = null;
    _queue = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _lifecycleObserver = null;
    _accessToken = null;
    _testerId = null;
    _testerIdentity = null;
    _sessionId = null;
    _currentScreen = null;
    _ingestUrl = null;
    _lastError = null;
    _lastConnectInputKind = null;
    _lastBootstrapAt = null;
    _lastFlushAt = null;
    _isInitialized = false;
    _isEnabled = false;
    _isFlushing = false;
    _rebootstrapAttempted = false;
    _disabledLogEmitted = false;
    _debugLoggingEnabled = _defaultDebugLogging;
    _clientInjectedForTesting = false;
    _authState = AuthState.disconnected;
    _authRecoveryBackoffSeconds = 5;
    _nextAuthRecoveryAtSeconds = null;
    _onTesterIdentityInvalid = null;
    _appContext = <String, dynamic>{};
  }
}

@Deprecated('Use MyAppCrewFlutter instead.')
class MyAppCrew {
  static Future<void> init({
    String? publicKey,
    String? baseUrl,
    bool? enableLogs,
  }) =>
      MyAppCrewFlutter.init(
        publicKey: publicKey,
        baseUrl: baseUrl,
        enableLogs: enableLogs,
      );

  static Future<void> initialize({
    required String publicKey,
    required String baseUrl,
    bool debugLogs = false,
  }) =>
      MyAppCrewFlutter.init(
        publicKey: publicKey,
        baseUrl: baseUrl,
        enableLogs: debugLogs,
      );

  static bool get isInitialized => MyAppCrewFlutter.isInitialized;
  static bool get isEnabled => MyAppCrewFlutter.isEnabled;
  static bool isTesterConnected() => MyAppCrewFlutter.isTesterConnected();
  static MyAppCrewTester? getConnectedTester() =>
      MyAppCrewFlutter.getConnectedTester();
  static DebugSnapshot getDebugSnapshot() =>
      MyAppCrewFlutter.getDebugSnapshot();

  @Deprecated('Use getDebugSnapshot instead.')
  static Map<String, dynamic> debugSnapshot() =>
      MyAppCrewFlutter.debugSnapshot();
  static NavigatorObserver? navigatorObserver() =>
      MyAppCrewFlutter.navigatorObserver();
  static void logEvent(String name, {Map<String, dynamic>? params}) =>
      MyAppCrewFlutter.logEvent(name, params: params);
  static Future<void> flushNow() => MyAppCrewFlutter.flushNow();
  static Future<MyAppCrewConnectResult> connectWithClaimToken(
    String claimToken,
  ) =>
      MyAppCrewFlutter.connectWithClaimToken(claimToken);
  static Future<MyAppCrewConnectResult> connectFromText(
    String input, {
    String? publicKeyOverride,
  }) =>
      MyAppCrewFlutter.connectFromText(
        input,
        publicKeyOverride: publicKeyOverride,
      );
  static Future<MyAppCrewConnectResult> connectTester(String code) =>
      MyAppCrewFlutter.connectTester(code);
  static Future<void> disconnectTester() =>
      MyAppCrewFlutter.disconnectTester();
  static void setOnTesterIdentityInvalid(
    void Function(String reason)? handler,
  ) =>
      MyAppCrewFlutter.setOnTesterIdentityInvalid(handler);
  static Future<void> showConnectSheet(
    BuildContext context, {
    bool showAsBottomSheet = true,
    String title = 'Connect tester',
    String subtitle = 'Enter the 6-digit Connect Code from your invite.',
    bool allowDismiss = true,
  }) =>
      MyAppCrewFlutter.showConnectSheet(
        context,
        showAsBottomSheet: showAsBottomSheet,
        title: title,
        subtitle: subtitle,
        allowDismiss: allowDismiss,
      );
  static void setDebugLogging(bool enabled) =>
      MyAppCrewFlutter.setDebugLogging(enabled);
}

enum _SendResult { success, failed, unauthorized, invalidIdentity }
