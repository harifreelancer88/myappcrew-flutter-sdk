import 'package:flutter_test/flutter_test.dart';
import 'package:myappcrew_flutter/myappcrew_flutter.dart';

void main() {
  test('initialize can be called', () async {
    await MyAppCrew.initialize(
      publicKey: 'test-key',
      baseUrl: 'https://example.com',
      debugLogs: false,
    );
  }, skip: 'Network calls are disabled in tests.');
}
