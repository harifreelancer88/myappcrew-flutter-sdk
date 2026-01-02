import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../myappcrew_flutter.dart';

typedef ConnectPromptSnapshotProvider = Future<DebugSnapshot> Function();
typedef ConnectPromptConnectHandler = Future<MyAppCrewConnectResult> Function(
  String input,
);

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
  @visibleForTesting
  static ConnectPromptConnectHandler? debugConnectHandlerForTesting;

  @override
  State<MyAppCrewConnectPrompt> createState() => _MyAppCrewConnectPromptState();
}

class _MyAppCrewConnectPromptState extends State<MyAppCrewConnectPrompt> {
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _connectedBannerDuration = Duration(seconds: 2);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  Timer? _pollTimer;
  Timer? _connectedBannerTimer;
  DebugSnapshot? _snapshot;
  bool _submitting = false;
  String? _errorText;
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
    _codeFocusNode.dispose();
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
    if (_submitting) {
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

  Future<MyAppCrewConnectResult> _connectFromText(String input) async {
    final handler = MyAppCrewConnectPrompt.debugConnectHandlerForTesting;
    if (handler != null) {
      return handler(input);
    }
    return MyAppCrewFlutter.connectFromText(input);
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
    if (_submitting) {
      return;
    }
    final rawInput = _controller.text.trim();
    final normalized = rawInput.replaceAll(RegExp(r'\D'), '');
    if (normalized.length != 6) {
      setState(() {
        _errorText = 'Enter your 6-digit Connect Code.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });
    _pollTimer?.cancel();
    _pollTimer = null;

    try {
      final result = await _connectFromText(normalized);
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        if (!result.connected) {
          _errorText = result.message ??
              result.errorCode ??
              'Connection failed. Try again.';
        }
      });
      if (result.connected) {
        FocusScope.of(context).unfocus();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorText = 'Connection failed. Try again.';
      });
    }

    if (mounted) {
      unawaited(_refreshSnapshot());
      _ensurePolling();
    }
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
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Material(
                    elevation: 6,
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      reverse: true,
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
    final errorMessage = _errorText;
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
          focusNode: _codeFocusNode,
          enabled: !_submitting,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            _ConnectCodeFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
          ),
          onTap: () {
            _codeFocusNode.requestFocus();
          },
          onChanged: (_) {
            if (_errorText != null) {
              setState(() {
                _errorText = null;
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

class _ConnectCodeFormatter extends TextInputFormatter {
  static final RegExp _digitMatcher = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(_digitMatcher, '');
    final clipped = digits.length > 6 ? digits.substring(0, 6) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i += 1) {
      if (i == 3) {
        buffer.write(' ');
      }
      buffer.write(clipped[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
