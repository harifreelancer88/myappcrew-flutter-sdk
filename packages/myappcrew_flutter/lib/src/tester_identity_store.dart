import 'package:shared_preferences/shared_preferences.dart';

class TesterIdentity {
  const TesterIdentity({
    required this.testerId,
    required this.appPublicKey,
    this.sessionToken,
    this.connectedAtSeconds,
  });

  final String testerId;
  final String appPublicKey;
  final String? sessionToken;
  final int? connectedAtSeconds;

  bool get isConnected =>
      testerId.isNotEmpty && !testerId.startsWith('tst_');
}

class TesterIdentityStore {
  static const _keyTesterId = 'myappcrew_connected_tester_id';
  static const _keyPublicKey = 'myappcrew_connected_public_key';
  static const _keySessionToken = 'myappcrew_connected_session_token';
  static const _keyConnectedAt = 'myappcrew_connected_at';

  Future<TesterIdentity?> getIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final testerId = prefs.getString(_keyTesterId);
      final publicKey = prefs.getString(_keyPublicKey);
      final sessionToken = prefs.getString(_keySessionToken);
      final connectedAt = prefs.getInt(_keyConnectedAt);
      if (testerId == null || publicKey == null) {
        return null;
      }
      return TesterIdentity(
        testerId: testerId,
        appPublicKey: publicKey,
        sessionToken: sessionToken,
        connectedAtSeconds: connectedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveIdentity(TesterIdentity identity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTesterId, identity.testerId);
      await prefs.setString(_keyPublicKey, identity.appPublicKey);
      if (identity.sessionToken != null &&
          identity.sessionToken!.isNotEmpty) {
        await prefs.setString(_keySessionToken, identity.sessionToken!);
      } else {
        await prefs.remove(_keySessionToken);
      }
      if (identity.connectedAtSeconds != null) {
        await prefs.setInt(_keyConnectedAt, identity.connectedAtSeconds!);
      } else {
        await prefs.remove(_keyConnectedAt);
      }
    } catch (_) {}
  }

  Future<void> clearIdentity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyTesterId);
      await prefs.remove(_keyPublicKey);
      await prefs.remove(_keySessionToken);
      await prefs.remove(_keyConnectedAt);
    } catch (_) {}
  }

  Future<bool> isConnectedForApp(String appPublicKey) async {
    final identity = await getIdentity();
    if (identity == null) {
      return false;
    }
    return identity.appPublicKey == appPublicKey && identity.isConnected;
  }
}
