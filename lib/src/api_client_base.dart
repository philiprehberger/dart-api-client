import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_request.dart';
import 'api_response.dart';
import 'api_error.dart';
import 'interceptor.dart';
import 'retry_interceptor.dart';

/// Declarative API client with interceptors and retry support.
class ApiClient {
  /// The base URL prepended to all request paths.
  final String baseUrl;

  /// The request timeout duration.
  final Duration timeout;

  /// The retry configuration, if retries are enabled.
  final RetryConfig? retryConfig;

  final List<Interceptor> _interceptors = [];
  final http.Client _httpClient;

  /// Create an API client.
  ApiClient({
    required this.baseUrl,
    this.timeout = const Duration(seconds: 30),
    this.retryConfig,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Add an interceptor.
  void addInterceptor(Interceptor interceptor) =>
      _interceptors.add(interceptor);

  /// Remove an interceptor.
  void removeInterceptor(Interceptor interceptor) =>
      _interceptors.remove(interceptor);

  /// Send a GET request.
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
  }) =>
      _send('GET', path, query: query, headers: headers);

  /// Send a POST request.
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send('POST', path, body: body, headers: headers);

  /// Send a PUT request.
  Future<ApiResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send('PUT', path, body: body, headers: headers);

  /// Send a PATCH request.
  Future<ApiResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _send('PATCH', path, body: body, headers: headers);

  /// Send a DELETE request.
  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) =>
      _send('DELETE', path, headers: headers);

  /// Close the underlying HTTP client.
  void close() => _httpClient.close();

  Future<ApiResponse> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final bodyString =
        body != null ? (body is String ? body : jsonEncode(body)) : null;
    final defaultHeaders = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
    };

    var request = ApiRequest(
      method: method,
      uri: uri,
      headers: {...defaultHeaders, ...?headers},
      body: bodyString,
    );

    // Run request interceptors
    for (final interceptor in _interceptors) {
      request = interceptor.onRequest(request);
    }

    return _executeWithRetry(request);
  }

  Future<ApiResponse> _executeWithRetry(ApiRequest request) async {
    final config = retryConfig;
    final maxAttempts = config?.maxAttempts ?? 1;
    ApiError? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0 && config != null) {
        await Future.delayed(config.delayForAttempt(attempt));
      }

      try {
        final response = await _execute(request);

        if (config != null &&
            config.shouldRetry(response.statusCode) &&
            attempt < maxAttempts - 1) {
          lastError = HttpError(request, response);
          continue;
        }

        // Run response interceptors
        var result = response;
        for (final interceptor in _interceptors) {
          result = interceptor.onResponse(result);
        }
        return result;
      } on ApiError catch (e) {
        lastError = e;
        if (attempt >= maxAttempts - 1) break;
      } catch (e) {
        lastError = ApiError(e.toString(), request: request);
        if (attempt >= maxAttempts - 1) break;
      }
    }

    if (config != null && maxAttempts > 1) {
      throw RetryExhaustedError(maxAttempts, lastError!);
    }
    throw lastError!;
  }

  Future<ApiResponse> _execute(ApiRequest request) async {
    final stopwatch = Stopwatch()..start();
    try {
      final httpRequest = http.Request(request.method, request.uri);
      httpRequest.headers.addAll(request.headers);
      if (request.body != null) {
        httpRequest.body = request.body!;
      }

      final streamedResponse =
          await _httpClient.send(httpRequest).timeout(timeout);
      final responseBody = await streamedResponse.stream.bytesToString();
      stopwatch.stop();

      return ApiResponse(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        body: responseBody,
        duration: stopwatch.elapsed,
      );
    } on Exception catch (e) {
      stopwatch.stop();
      if (e.toString().contains('TimeoutException')) {
        throw TimeoutError(request.uri.toString());
      }
      rethrow;
    }
  }
}
