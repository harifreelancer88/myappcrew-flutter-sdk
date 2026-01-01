import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../myappcrew_flutter.dart';

typedef ConnectPromptSnapshotProvider = Future<DebugSnapshot> Function();

class MyAppCrewConnectPrompt extends StatefulWidget {
  const MyAppCrewConnectPrompt({
    required this.child,
    super.key,
    this.debugOnly = true,
    this.showUntilConnected = true,
  });

  final Widget child;
  final bool debugOnly;
  final bool showUntilConnected;

  @visibleForTesting
  static ConnectPromptSnapshotProvider? debugSnapshotProviderForTesting;

  @override
  State<MyAppCrewConnectPrompt> createState() => _MyAppCrewConnectPromptState();
}

class _MyAppCrewConnectPromptState extends State<MyAppCrewConnectPrompt> {
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _connectedBannerDuration = Duration(seconds: 2);

  final TextEditingController _controller = TextEditingController();
  Timer? _pollTimer;
  Timer? _connectedBannerTimer;
  DebugSnapshot? _snapshot;
  bool _submitting = false;
  String? _errorMessage;
  bool _showConnectedBanner = false;
  bool _connectedBannerDismissed = false;
  bool _promptDismissed = false;
  bool _sawDisconnected = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshSnapshot());
    _ensurePolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connectedBannerTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  bool get _debugEnabled => !widget.debugOnly || kDebugMode;

  bool get _shouldShowPrompt {
    if (!_debugEnabled || _promptDismissed) {
      return false;
    }
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.initialized) {
      return false;
    }
    if (snapshot.connected) {
      return false;
    }
    return true;
  }

  bool get _shouldShowConnectedBanner {
    if (!_debugEnabled || _connectedBannerDismissed) {
      return false;
    }
    return _showConnectedBanner;
  }

  bool get _shouldPoll {
    if (!_debugEnabled) {
      return false;
    }
    if (_promptDismissed && !widget.showUntilConnected) {
      return false;
    }
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.initialized) {
      return true;
    }
    if (!snapshot.connected) {
      return true;
    }
    return _shouldShowConnectedBanner;
  }

  void _ensurePolling() {
    if (!_shouldPoll) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(_pollInterval, (_) {
      unawaited(_refreshSnapshot());
    });
  }

  Future<DebugSnapshot> _loadSnapshot() async {
    final provider = MyAppCrewConnectPrompt.debugSnapshotProviderForTesting;
    if (provider != null) {
      return provider();
    }
    return Future<DebugSnapshot>.value(MyAppCrewFlutter.getDebugSnapshot());
  }

  Future<void> _refreshSnapshot() async {
    final snapshot = await _loadSnapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      final wasConnected = _snapshot?.connected ?? false;
      _snapshot = snapshot;
      if (snapshot.initialized && !snapshot.connected) {
        _sawDisconnected = true;
      }
      if (snapshot.connected && !wasConnected && _sawDisconnected) {
        _showConnectedBanner = true;
        _connectedBannerDismissed = false;
        _scheduleConnectedBannerHide();
      }
      if (!snapshot.connected) {
        _connectedBannerDismissed = false;
      }
    });
    _ensurePolling();
  }

  void _scheduleConnectedBannerHide() {
    _connectedBannerTimer?.cancel();
    _connectedBannerTimer = Timer(_connectedBannerDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showConnectedBanner = false;
        _connectedBannerDismissed = true;
      });
      _ensurePolling();
    });
  }

  Future<void> _handleConnect() async {
    final rawInput = _controller.text.trim();
    if (rawInput.isEmpty || _submitting) {
      setState(() {
        _errorMessage = 'Enter your 6-digit Connect Code.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final result = await MyAppCrewFlutter.connectFromText(rawInput);
    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
      if (!result.connected) {
        _errorMessage = result.message ??
            result.errorCode ??
            'Connection failed. Try again.';
      }
    });

    unawaited(_refreshSnapshot());
  }

  void _dismissConnectedBanner() {
    _connectedBannerTimer?.cancel();
    setState(() {
      _showConnectedBanner = false;
      _connectedBannerDismissed = true;
    });
    _ensurePolling();
  }

  void _dismissPrompt() {
    if (widget.showUntilConnected) {
      return;
    }
    setState(() {
      _promptDismissed = true;
    });
    _ensurePolling();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowPrompt = _shouldShowPrompt;
    final shouldShowConnected = _shouldShowConnectedBanner;
    if (!shouldShowPrompt && !shouldShowConnected) {
      return widget.child;
    }

    final theme = Theme.of(context);

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            minimum: const EdgeInsets.all(12),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Material(
                  elevation: 6,
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: shouldShowConnected
                        ? _buildConnectedBanner(theme)
                        : _buildPrompt(theme),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedBanner(ThemeData theme) {
    return Row(
      children: <Widget>[
        const Icon(Icons.check_circle, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Connected', style: theme.textTheme.bodyMedium),
        ),
        IconButton(
          onPressed: _dismissConnectedBanner,
          icon: const Icon(Icons.close),
          tooltip: 'Dismiss',
        ),
      ],
    );
  }

  Widget _buildPrompt(ThemeData theme) {
    final errorMessage = _errorMessage;
    final labelStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Connect tester', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit Connect Code from your invite.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          enabled: !_submitting,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
          ],
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_errorMessage != null) {
              setState(() {
                _errorMessage = null;
              });
            }
          },
          onSubmitted: (_) => _handleConnect(),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : _handleConnect,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect'),
              ),
            ),
            if (!widget.showUntilConnected) ...<Widget>[
              const SizedBox(width: 8),
              TextButton(
                onPressed: _submitting ? null : _dismissPrompt,
                child: const Text('Not now'),
              ),
            ],
          ],
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(errorMessage, style: labelStyle),
        ],
      ],
    );
  }
}
