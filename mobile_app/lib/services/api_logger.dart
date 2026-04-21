// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Custom HTTP Client that logs precise send/receive times and durations
class ApiLogger extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startTime = DateTime.now();
    
    String requestBody = 'No Body';
    if (request is http.Request) {
      requestBody = request.body;
    }

    print('\n════════════════════════════════════════════════');
    print('[API SENT] ${request.method} ${request.url}');
    print(' Time Sent: $startTime');
    print(' Headers: ${request.headers}');
    print(' Request Body: $requestBody');
    print('────────────────────────────────────────────────');

    try {
      final response = await _inner.send(request);
      final receiveTime = DateTime.now();
      final duration = receiveTime.difference(startTime).inMilliseconds;
      
      // Read response stream to print body
      final responseBytes = await response.stream.toBytes();
      final responseBodyString = utf8.decode(responseBytes, allowMalformed: true);
      
      print('[API RECEIVED] ${request.method} ${request.url}');
      print(' Status: ${response.statusCode}');
      print(' Time Received: $receiveTime');
      print(' Duration: ${duration}ms');
      print(' Response Body: $responseBodyString');
      print('════════════════════════════════════════════════\n');
      
      // Recreate and return the StreamedResponse since the original stream was consumed
      return http.StreamedResponse(
        Stream.value(responseBytes),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      final failTime = DateTime.now();
      final duration = failTime.difference(startTime).inMilliseconds;
      
      print('[API FAILED] ${request.method} ${request.url}');
      print(' Error: $e');
      print(' Time Failed: $failTime');
      print(' Duration until failure: ${duration}ms');
      print('════════════════════════════════════════════════\n');
      
      rethrow;
    }
  }
}

// Global instance to be used across the app
final httpLogger = ApiLogger();

// Top-level proxy functions to serve as a drop-in replacement for package:http
Future<http.Response> get(Uri url, {Map<String, String>? headers}) => 
    httpLogger.get(url, headers: headers);

Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => 
    httpLogger.post(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) => 
    httpLogger.put(url, headers: headers, body: body, encoding: encoding);

