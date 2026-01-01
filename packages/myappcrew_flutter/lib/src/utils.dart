import 'dart:convert';

int unixSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

class MyAppCrewParsedConnectInput {
  const MyAppCrewParsedConnectInput({
    required this.inputKind,
    this.parsedPublicKey,
    this.claimToken,
    this.connectCode,
  });

  final String inputKind;
  final String? parsedPublicKey;
  final String? claimToken;
  final String? connectCode;
}

String normalizeBaseUrl(String baseUrl) {
  var normalized = baseUrl.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

String joinBaseUrlAndPath(String baseUrl, String path) {
  final trimmed = path.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasScheme) {
    return trimmed;
  }
  final normalizedBase = normalizeBaseUrl(baseUrl);
  var normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  if (normalizedBase.endsWith('/api') && normalizedPath.startsWith('/api/')) {
    normalizedPath = normalizedPath.substring('/api'.length);
  }
  return '$normalizedBase$normalizedPath';
}

Map<String, dynamic>? safeJsonDecode(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {}
  return null;
}

String? firstStringKey(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) {
    return null;
  }
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

MyAppCrewParsedConnectInput parseConnectInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const MyAppCrewParsedConnectInput(inputKind: 'unknown');
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && (uri.hasScheme || trimmed.contains('?'))) {
    final parsedPublicKey = uri.queryParameters['pk'] ??
        uri.queryParameters['publicKey'] ??
        uri.queryParameters['public_key'];
    final queryToken = uri.queryParameters['claimToken'] ??
        uri.queryParameters['claim_token'];
    if (queryToken != null && queryToken.isNotEmpty) {
      return MyAppCrewParsedConnectInput(
        inputKind: 'link',
        parsedPublicKey: parsedPublicKey,
        claimToken: queryToken,
      );
    }
    if (uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) {
        return MyAppCrewParsedConnectInput(
          inputKind: 'link',
          parsedPublicKey: parsedPublicKey,
          claimToken: last,
        );
      }
    }
  }

  final connectCode = _normalizeConnectCode(trimmed);
  if (connectCode != null) {
    return MyAppCrewParsedConnectInput(
      inputKind: 'code',
      connectCode: connectCode,
    );
  }

  if (_isUuid(trimmed)) {
    return MyAppCrewParsedConnectInput(
      inputKind: 'token',
      claimToken: trimmed,
    );
  }

  return const MyAppCrewParsedConnectInput(inputKind: 'unknown');
}

String? _normalizeConnectCode(String input) {
  final normalized = input.replaceAll(RegExp(r'[\s-]'), '');
  if (RegExp(r'^\d{6}$').hasMatch(normalized)) {
    return normalized;
  }
  return null;
}

bool _isUuid(String input) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  ).hasMatch(input);
}
