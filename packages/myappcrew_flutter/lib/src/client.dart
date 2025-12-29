import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logger.dart';
import 'models.dart';
import 'utils.dart';

class MyAppCrewClient {
  MyAppCrewClient({required this.timeout, required this.logger});

  final Duration timeout;
  final MyAppCrewLogger logger;
  final http.Client _client = http.Client();

  Future<MyAppCrewHttpResult> postJson(
    String url,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
  }) async {
    try {
      final mergedHeaders = <String, String>{
        'Content-Type': 'application/json',
      };
      if (headers != null) {
        mergedHeaders.addAll(headers);
      }
      final response = await _client
          .post(
            Uri.parse(url),
            headers: mergedHeaders,
            body: jsonEncode(body),
          )
          .timeout(timeout);
      final rawBody = response.body;
      final json = safeJsonDecode(rawBody);
      return MyAppCrewHttpResult(
        statusCode: response.statusCode,
        json: json,
        rawBody: rawBody,
      );
    } on TimeoutException {
      logger.log('request timeout');
      return const MyAppCrewHttpResult(statusCode: 0);
    } catch (_) {
      return const MyAppCrewHttpResult(statusCode: 0);
    }
  }
}
