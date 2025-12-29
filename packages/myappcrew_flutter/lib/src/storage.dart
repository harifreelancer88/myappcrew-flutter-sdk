import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class MyAppCrewStorage {
  static const _keyBaseUrl = 'myappcrew_base_url';
  static const _keyPublicKey = 'myappcrew_public_key';
  static const _keyAccessToken = 'myappcrew_access_token';
  static const _keyTesterId = 'myappcrew_tester_id';
  static const _keyIngestUrl = 'myappcrew_ingest_url';
  static const _keySavedAt = 'myappcrew_saved_at';

  Future<MyAppCrewAuth?> loadAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString(_keyBaseUrl);
      final publicKey = prefs.getString(_keyPublicKey);
      final accessToken = prefs.getString(_keyAccessToken);
      final testerId = prefs.getString(_keyTesterId);
      final ingestUrl = prefs.getString(_keyIngestUrl);
      final savedAt = prefs.getInt(_keySavedAt);
      if (baseUrl == null ||
          publicKey == null ||
          accessToken == null ||
          testerId == null ||
          savedAt == null) {
        return null;
      }
      return MyAppCrewAuth(
        baseUrl: baseUrl,
        publicKey: publicKey,
        accessToken: accessToken,
        testerId: testerId,
        ingestUrl: ingestUrl,
        savedAtSeconds: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAuth(MyAppCrewAuth auth) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBaseUrl, auth.baseUrl);
      await prefs.setString(_keyPublicKey, auth.publicKey);
      await prefs.setString(_keyAccessToken, auth.accessToken);
      await prefs.setString(_keyTesterId, auth.testerId);
      if (auth.ingestUrl != null && auth.ingestUrl!.isNotEmpty) {
        await prefs.setString(_keyIngestUrl, auth.ingestUrl!);
      } else {
        await prefs.remove(_keyIngestUrl);
      }
      await prefs.setInt(_keySavedAt, auth.savedAtSeconds);
    } catch (_) {}
  }

  Future<void> clearAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyBaseUrl);
      await prefs.remove(_keyPublicKey);
      await prefs.remove(_keyAccessToken);
      await prefs.remove(_keyTesterId);
      await prefs.remove(_keyIngestUrl);
      await prefs.remove(_keySavedAt);
    } catch (_) {}
  }
}
