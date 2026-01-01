import 'dart:convert';

int unixSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

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

String? parseClaimToken(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri != null && (uri.hasScheme || trimmed.contains('?'))) {
    final queryToken = uri.queryParameters['claimToken'] ??
        uri.queryParameters['claim_token'];
    if (queryToken != null && queryToken.isNotEmpty) {
      return queryToken;
    }
    if (uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) {
        return last;
      }
    }
  }

  return trimmed;
}
