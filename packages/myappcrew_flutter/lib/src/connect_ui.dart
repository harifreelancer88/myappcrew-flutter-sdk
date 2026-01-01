import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../myappcrew_flutter.dart';

typedef DebugSnapshotProvider = Future<DebugSnapshot> Function();

const String _defaultTitle = 'Connect tester';
const String _defaultSubtitle =
    'Enter the 6-digit Connect Code from your invite.';

const String _dismissedKeyPrefix = 'myappcrew_connect_prompt_last_dismissed_';
const String _publicKeyPrefsKey = 'myappcrew_public_key';
const Duration _initRetryDelay = Duration(seconds: 1);

class MyAppCrewConnectWrapper extends StatefulWidget {
  const MyAppCrewConnectWrapper({
    required this.child,
    super.key,
    this.enabled,
    this.autoShow = true,
    this.rePromptDelay = Duration.zero,
    this.showAsBottomSheet = true,
    this.title = _defaultTitle,
    this.subtitle = _defaultSubtitle,
    this.allowDismiss = true,
    this.showIfAnonymousTester = true,
    this.showIfNotInitialized = false,
    this.showIfAlreadyConnected = false,
    this.debugSnapshotProvider,
  });

  final Widget child;
  final bool? enabled;
  final bool autoShow;
  final Duration rePromptDelay;
  final bool showAsBottomSheet;
  final String title;
  final String subtitle;
  final bool allowDismiss;
  final bool showIfAnonymousTester;
  final bool showIfNotInitialized;
  final bool showIfAlreadyConnected;

  @visibleForTesting
  final DebugSnapshotProvider? debugSnapshotProvider;

  @override
  State<MyAppCrewConnectWrapper> createState() =>
      _MyAppCrewConnectWrapperState();
}

class _MyAppCrewConnectWrapperState extends State<MyAppCrewConnectWrapper> {
  bool _presentedThisSession = false;
  bool _isShowing = false;
  Timer? _autoShowTimer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoShow();
  }

  @override
  void didUpdateWidget(MyAppCrewConnectWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoShow && !_presentedThisSession) {
      _scheduleAutoShow();
    }
  }

  @override
  void dispose() {
    _autoShowTimer?.cancel();
    super.dispose();
  }

  bool get _effectiveEnabled {
    if (kIsWeb && widget.enabled != true) {
      return false;
    }
    return widget.enabled ?? kDebugMode;
  }

  void _scheduleAutoShow() {
    if (!widget.autoShow) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _autoShowTimer?.cancel();
      _autoShowTimer = Timer(widget.rePromptDelay, () {
        unawaited(_maybeShow());
      });
    });
  }

  Future<DebugSnapshot> _loadSnapshot() async {
    final provider = widget.debugSnapshotProvider;
    if (provider != null) {
      return provider();
    }
    return Future<DebugSnapshot>.value(MyAppCrewFlutter.getDebugSnapshot());
  }

  Future<void> _maybeShow() async {
    if (!mounted || !_effectiveEnabled) {
      return;
    }
    if (_presentedThisSession || _isShowing) {
      return;
    }

    final snapshot = await _loadSnapshot();
    if (!snapshot.initialized && !widget.showIfNotInitialized) {
      if (!MyAppCrewFlutter.isInitialized) {
        _autoShowTimer?.cancel();
        _autoShowTimer = Timer(
          _initRetryDelay,
          () => unawaited(_maybeShow()),
        );
      }
      return;
    }

    final testerId = snapshot.testerId;
    final isAnonymous = testerId.startsWith('tst_');
    if (isAnonymous && !widget.showIfAnonymousTester) {
      return;
    }

    final isConnected =
        snapshot.initialized && testerId.isNotEmpty && !isAnonymous;
    if (isConnected && !widget.showIfAlreadyConnected) {
      return;
    }

    final dismissKey = await _buildDismissKey(snapshot);
    if (dismissKey.isNotEmpty && widget.rePromptDelay > Duration.zero) {
      final lastDismissed = await _loadLastDismissedAt(dismissKey);
      if (lastDismissed != null) {
        final elapsed = DateTime.now().difference(lastDismissed);
        if (elapsed < widget.rePromptDelay) {
          _autoShowTimer?.cancel();
          _autoShowTimer = Timer(
            widget.rePromptDelay - elapsed,
            () => unawaited(_maybeShow()),
          );
          return;
        }
      }
    }

    _presentedThisSession = true;
    _isShowing = true;
    if (!mounted) {
      return;
    }
    final didConnect = await showMyAppCrewConnectSheet(
      context,
      showAsBottomSheet: widget.showAsBottomSheet,
      title: widget.title,
      subtitle: widget.subtitle,
      allowDismiss: widget.allowDismiss,
    );
    if (!didConnect && dismissKey.isNotEmpty) {
      await _storeLastDismissedAt(dismissKey);
    }
    _isShowing = false;
  }

  Future<String> _buildDismissKey(DebugSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final publicKey = prefs.getString(_publicKeyPrefsKey) ?? '';
      if (publicKey.isNotEmpty) {
        return '$_dismissedKeyPrefix$publicKey';
      }
    } catch (_) {}

    if (snapshot.publicKeyLast4.isNotEmpty) {
      return '$_dismissedKeyPrefix${snapshot.publicKeyLast4}';
    }
    return '';
  }

  Future<DateTime?> _loadLastDismissedAt(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getInt(key);
      if (stored == null) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(stored);
    } catch (_) {
      return null;
    }
  }

  Future<void> _storeLastDismissedAt(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<bool> showMyAppCrewConnectSheet(
  BuildContext context, {
  required bool showAsBottomSheet,
  required String title,
  required String subtitle,
  required bool allowDismiss,
}) async {
  if (showAsBottomSheet) {
    try {
      final result = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: allowDismiss,
        enableDrag: allowDismiss,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          return _MyAppCrewConnectSheetContent(
            title: title,
            subtitle: subtitle,
            allowDismiss: allowDismiss,
          );
        },
      );
      return result ?? false;
    } catch (_) {}
  }

  if (!context.mounted) {
    return false;
  }

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: allowDismiss,
    builder: (dialogContext) {
      return AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: _MyAppCrewConnectSheetContent(
          title: title,
          subtitle: subtitle,
          allowDismiss: allowDismiss,
          isDialog: true,
        ),
      );
    },
  );
  return result ?? false;
}

class _MyAppCrewConnectSheetContent extends StatefulWidget {
  const _MyAppCrewConnectSheetContent({
    required this.title,
    required this.subtitle,
    required this.allowDismiss,
    this.isDialog = false,
  });

  final String title;
  final String subtitle;
  final bool allowDismiss;
  final bool isDialog;

  @override
  State<_MyAppCrewConnectSheetContent> createState() =>
      _MyAppCrewConnectSheetContentState();
}

class _MyAppCrewConnectSheetContentState
    extends State<_MyAppCrewConnectSheetContent> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String? _statusMessage;
  bool _statusSuccess = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        return;
      }
      _controller.text = text;
      setState(() {});
    } catch (_) {}
  }

  Future<void> _handleConnect() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _submitting) {
      setState(() {
        _statusSuccess = false;
        _statusMessage = 'Enter your 6-digit Connect Code.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _statusMessage = null;
    });

    final result = await MyAppCrewFlutter.connectFromText(input);
    if (!mounted) {
      return;
    }

    if (result.connected) {
      setState(() {
        _statusSuccess = true;
        _statusMessage = 'Connected!';
        _submitting = false;
      });
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
      return;
    }

    setState(() {
      _submitting = false;
      _statusSuccess = false;
      _statusMessage =
          result.message ?? result.errorCode ?? 'Connection failed. Try again.';
    });
  }

  void _dismiss() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = EdgeInsets.only(
      left: 20,
      right: 20,
      top: 20,
      bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
    );

    final statusMessage = _statusMessage;
    final statusColor = _statusSuccess
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(widget.subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[\d\s-]')),
          ],
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_statusMessage != null) {
              setState(() {
                _statusMessage = null;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            OutlinedButton(
              onPressed: _submitting ? null : _pasteFromClipboard,
              child: const Text('Paste'),
            ),
            const SizedBox(width: 12),
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
          ],
        ),
        if (statusMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            statusMessage,
            style: theme.textTheme.bodyMedium?.copyWith(color: statusColor),
          ),
        ],
        if (widget.allowDismiss) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _submitting ? null : _dismiss,
              child: const Text('Not now'),
            ),
          ),
        ],
      ],
    );

    if (widget.isDialog) {
      return Padding(
        padding: padding,
        child: SingleChildScrollView(child: content),
      );
    }

    return Padding(
      padding: padding,
      child: SingleChildScrollView(child: content),
    );
  }
}
