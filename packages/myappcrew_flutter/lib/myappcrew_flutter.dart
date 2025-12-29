import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import 'src/client.dart';
import 'src/config.dart';
import 'src/lifecycle.dart';
import 'src/logger.dart';
import 'src/models.dart';
import 'src/navigator_observer.dart';
import 'src/queue.dart';
import 'src/storage.dart';
import 'src/utils.dart';

/// MyAppCrew SDK entry point.
class MyAppCrew {
  static const String _sdkVersion = '0.1.0';
  static const int _maxBatchSize = 50;
  static const bool _enableInviteClaim = false;
  static const String _defaultIngestPath = '/api/v1/mobile/events/batch';

  static final Uuid _uuid = const Uuid();

  static MyAppCrewConfig? _config;
  static MyAppCrewLogger? _logger;
  static MyAppCrewClient? _client;
  static MyAppCrewStorage? _storage;
  static MyAppCrewQueue? _queue;
  static Timer? _flushTimer;
  static MyAppCrewLifecycleObserver? _lifecycleObserver;

  static String? _accessToken;
  static String? _testerId;
  static String? _sessionId;
  static String? _currentScreen;
  static String? _ingestUrl;
  static bool _isInitialized = false;
  static bool _isFlushing = false;
  static bool _rebootstrapAttempted = false;

  static Map<String, dynamic> _appContext = <String, dynamic>{};

  /// Returns the current testerId, if available.
  static String? get testerId => _testerId;

  /// Returns the current sessionId, if available.
  static String? get sessionId => _sessionId;

  /// Whether initialize has completed successfully.
  static bool get isInitialized => _isInitialized;

  /// Initialize the SDK.
  static Future<MyAppCrewInitResult> initialize({
    required String publicKey,
    required String baseUrl,
    String? appVersion,
    String? buildNumber,
    String? inviteCode,
    bool debugLogs = true,
    Duration timeout = const Duration(seconds: 8),
    int flushAt = 10,
    Duration flushInterval = const Duration(seconds: 12),
    bool forceRebootstrap = false,
  }) async {
    try {
      final normalizedBaseUrl = normalizeBaseUrl(baseUrl);
      _config = MyAppCrewConfig(
        publicKey: publicKey,
        baseUrl: normalizedBaseUrl,
        appVersion: appVersion,
        buildNumber: buildNumber,
        inviteCode: inviteCode,
        debugLogs: debugLogs,
        timeout: timeout,
        flushAt: flushAt,
        flushInterval: flushInterval,
        forceRebootstrap: forceRebootstrap,
      );
      _logger = MyAppCrewLogger(debugLogs);
      _client = MyAppCrewClient(timeout: timeout, logger: _logger!);
      _storage ??= MyAppCrewStorage();
      _queue ??= MyAppCrewQueue();
      _ensureSessionId();
      _appContext = await _loadAppContext();

      _logger?.log('initialize start');
      final persisted = await _storage?.loadAuth();
      if (!forceRebootstrap && _isAuthReusable(persisted)) {
        _accessToken = persisted?.accessToken;
        _testerId = persisted?.testerId;
        _ingestUrl = persisted?.ingestUrl ?? _defaultIngestPath;
        _isInitialized = true;
        _startObservers();
        _logger?.log('initialize ok (cached)');
        return MyAppCrewInitResult.ok();
      }

      final bootstrapOk = await _bootstrap();
      if (!bootstrapOk) {
        _isInitialized = false;
        _startObservers();
        _logger?.log('initialize failed');
        return MyAppCrewInitResult.fail('bootstrap_failed');
      }

      _isInitialized = true;
      _startObservers();
      _logger?.log('initialize ok');
      return MyAppCrewInitResult.ok();
    } catch (_) {
      _logger?.log('initialize exception');
      return MyAppCrewInitResult.fail('initialize_exception');
    }
  }

  /// Log an event. Safe to call before initialize.
  static void logEvent(String name, {Map<String, dynamic>? properties}) {
    try {
      _queue ??= MyAppCrewQueue();
      _ensureSessionId();

      final event = <String, dynamic>{
        'name': name,
        'ts': unixSeconds(),
        'sessionId': _sessionId,
      };

      if (_testerId != null) {
        event['testerId'] = _testerId;
      }
      if (_currentScreen != null) {
        event['screen'] = _currentScreen;
      }

      if (_appContext.isNotEmpty) {
        event.addAll(_appContext);
      }

      if (properties != null && properties.isNotEmpty) {
        event['properties'] = properties;
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
  static NavigatorObserver navigatorObserver({
    String? unknownRouteNameFallback,
  }) {
    final fallback = unknownRouteNameFallback ?? 'unknown';
    return MyAppCrewNavigatorObserver(
      unknownRouteNameFallback: fallback,
      onScreenChange: (screen) {
        _currentScreen = screen;
        logEvent('screen_view');
      },
    );
  }

  static void _ensureSessionId() {
    _sessionId ??= _uuid.v4();
  }

  static bool _isAuthReusable(MyAppCrewAuth? auth) {
    if (auth == null || _config == null) {
      return false;
    }
    return auth.baseUrl == _config!.baseUrl &&
        auth.publicKey == _config!.publicKey &&
        auth.accessToken.isNotEmpty;
  }

  static Future<Map<String, dynamic>> _loadAppContext() async {
    final context = <String, dynamic>{};
    try {
      final info = await PackageInfo.fromPlatform();
      context['packageName'] = info.packageName;
      if (_config?.appVersion != null) {
        context['appVersion'] = _config!.appVersion;
      } else {
        context['appVersion'] = info.version;
      }
      if (_config?.buildNumber != null) {
        context['buildNumber'] = _config!.buildNumber;
      } else {
        context['buildNumber'] = info.buildNumber;
      }
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
      _lifecycleObserver = MyAppCrewLifecycleObserver(onBackground: () {
        unawaited(_flush('lifecycle'));
      });
      binding.addObserver(_lifecycleObserver!);
    } catch (_) {}
  }

  static Future<bool> _bootstrap() async {
    if (_config == null || _client == null || _storage == null) {
      return false;
    }
    try {
      _logger?.log('bootstrap start');
      final payload = <String, dynamic>{
        'publicKey': _config!.publicKey,
        'ts': unixSeconds(),
        'sdkVersion': _sdkVersion,
      };
      if (_appContext.isNotEmpty) {
        payload.addAll(_appContext);
      }

      final url = '${_config!.baseUrl}/api/v1/mobile/bootstrap';
      final result = await _client!.postJson(url, payload);
      final token = firstStringKey(
        result.json,
        <String>['accessToken', 'access_token', 'token', 'jwt'],
      );
      final testerId = firstStringKey(
        result.json,
        <String>['testerId', 'tester_id', 'id'],
      );
      final ingestUrl = firstStringKey(
        result.json,
        <String>['ingestUrl', 'ingest_url'],
      );
      if (result.statusCode < 200 || result.statusCode >= 300) {
        _logger?.log('bootstrap failed (${result.statusCode})');
        return false;
      }
      if (token == null || testerId == null) {
        _logger?.log('bootstrap missing fields');
        return false;
      }

      _accessToken = token;
      _testerId = testerId;
      _ingestUrl = ingestUrl ?? _defaultIngestPath;
      await _storage!.saveAuth(MyAppCrewAuth(
        baseUrl: _config!.baseUrl,
        publicKey: _config!.publicKey,
        accessToken: token,
        testerId: testerId,
        ingestUrl: _ingestUrl,
        savedAtSeconds: unixSeconds(),
      ));

      if (_enableInviteClaim && _config!.inviteCode != null) {
        await _claimInvite(_config!.inviteCode!);
      }

      _logger?.log('using ingestUrl: $_ingestUrl');
      _logger?.log('bootstrap ok');
      return true;
    } catch (_) {
      _logger?.log('bootstrap exception');
      return false;
    }
  }

  static Future<void> _claimInvite(String inviteCode) async {
    if (_client == null || _config == null || _accessToken == null) {
      return;
    }
    try {
      final url = '${_config!.baseUrl}/api/v1/mobile/claim';
      await _client!.postJson(
        url,
        <String, dynamic>{'inviteCode': inviteCode, 'ts': unixSeconds()},
        headers: <String, String>{
          'Authorization': 'Bearer $_accessToken',
        },
      );
    } catch (_) {}
  }

  static Future<void> _flush(String reason) async {
    if (_isFlushing) {
      return;
    }
    if (_queue == null || _queue!.isEmpty) {
      return;
    }
    if (_accessToken == null || _client == null || _config == null) {
      return;
    }
    _isFlushing = true;
    try {
      final batch = _queue!.snapshot(_maxBatchSize);
      if (batch.isEmpty) {
        return;
      }
      final success = await _sendWithRetry(batch);
      if (success) {
        _queue!.removeFirst(batch.length);
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
    if (result == _SendResult.unauthorized) {
      return _handleUnauthorized(batch);
    }

    for (final delayMs in <int>[500, 1000]) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      result = await _postBatch(batch);
      if (result == _SendResult.success) {
        return true;
      }
      if (result == _SendResult.unauthorized) {
        return _handleUnauthorized(batch);
      }
    }

    return false;
  }

  static Future<bool> _handleUnauthorized(
    List<Map<String, dynamic>> batch,
  ) async {
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
    try {
      final ingestPath = _ingestUrl ?? _defaultIngestPath;
      final url = joinBaseUrlAndPath(_config!.baseUrl, ingestPath);
      final result = await _client!.postJson(
        url,
        <String, dynamic>{'events': batch},
        headers: <String, String>{
          'Authorization': 'Bearer $_accessToken',
        },
      );
      if (result.statusCode == 401) {
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
}

enum _SendResult {
  success,
  failed,
  unauthorized,
}
