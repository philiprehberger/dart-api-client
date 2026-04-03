import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_request.dart';
import 'api_response.dart';
import 'api_error.dart';
import 'interceptor.dart';
import 'middleware.dart';
import 'multipart_file.dart';
import 'retry_interceptor.dart';

/// Declarative API client with interceptors, middleware, and retry support.
class ApiClient {
  /// The base URL prepended to all request paths.
  final String baseUrl;

  /// The request timeout duration.
  final Duration timeout;

  /// The retry configuration, if retries are enabled.
  final RetryConfig? retryConfig;

  final List<Interceptor> _interceptors = [];
  final List<Middleware> _middlewares = [];
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

  /// Add a middleware to the pipeline.
  void addMiddleware(Middleware middleware) => _middlewares.add(middleware);

  /// Remove a middleware from the pipeline.
  void removeMiddleware(Middleware middleware) =>
      _middlewares.remove(middleware);

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

  /// Send a POST multipart request.
  Future<ApiResponse> postMultipart(
    String path, {
    Map<String, String>? fields,
    List<MultipartFile>? files,
    Map<String, String>? headers,
  }) =>
      _sendMultipart('POST', path,
          fields: fields, files: files, headers: headers);

  /// Send a PUT multipart request.
  Future<ApiResponse> putMultipart(
    String path, {
    Map<String, String>? fields,
    List<MultipartFile>? files,
    Map<String, String>? headers,
  }) =>
      _sendMultipart('PUT', path,
          fields: fields, files: files, headers: headers);

  /// Send a GET request and deserialize the response.
  ///
  /// [decoder] converts the JSON response to type [T].
  Future<T> getTyped<T>(
    String path, {
    required T Function(Map<String, dynamic>) decoder,
    Map<String, String>? query,
    Map<String, String>? headers,
  }) async {
    final response = await get(path, query: query, headers: headers);
    if (!response.isSuccess) {
      throw HttpError(
        ApiRequest(method: 'GET', uri: Uri.parse('$baseUrl$path'), headers: headers ?? {}),
        response,
      );
    }
    return decoder(response.jsonMap);
  }

  /// Send a POST request and deserialize the response.
  Future<T> postTyped<T>(
    String path, {
    required T Function(Map<String, dynamic>) decoder,
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await post(path, body: body, headers: headers);
    if (!response.isSuccess) {
      throw HttpError(
        ApiRequest(method: 'POST', uri: Uri.parse('$baseUrl$path'), headers: headers ?? {}),
        response,
      );
    }
    return decoder(response.jsonMap);
  }

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

    return _executeWithMiddleware(request);
  }

  Future<ApiResponse> _sendMultipart(
    String method,
    String path, {
    Map<String, String>? fields,
    List<MultipartFile>? files,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    final multipartRequest = http.MultipartRequest(method, uri);
    if (fields != null) {
      multipartRequest.fields.addAll(fields);
    }
    if (files != null) {
      for (final file in files) {
        multipartRequest.files.add(http.MultipartFile.fromBytes(
          file.field,
          file.bytes,
          filename: file.filename,
          contentType: file.contentType != null
              ? _parseMediaType(file.contentType!)
              : null,
        ));
      }
    }
    if (headers != null) {
      multipartRequest.headers.addAll(headers);
    }

    // Apply interceptor headers
    var request = ApiRequest(
      method: method,
      uri: uri,
      headers: {...?headers},
    );
    for (final interceptor in _interceptors) {
      request = interceptor.onRequest(request);
    }
    multipartRequest.headers.addAll(request.headers);

    // Apply middleware headers
    if (_middlewares.isNotEmpty) {
      var middlewareRequest = request;
      for (final middleware in _middlewares) {
        middlewareRequest = await _extractMiddlewareHeaders(
            middleware, middlewareRequest);
      }
      multipartRequest.headers.addAll(middlewareRequest.headers);
    }

    final stopwatch = Stopwatch()..start();
    try {
      final streamedResponse =
          await _httpClient.send(multipartRequest).timeout(timeout);
      final responseBody = await streamedResponse.stream.bytesToString();
      stopwatch.stop();

      var response = ApiResponse(
        statusCode: streamedResponse.statusCode,
        headers: streamedResponse.headers,
        body: responseBody,
        duration: stopwatch.elapsed,
      );

      // Run response interceptors
      for (final interceptor in _interceptors) {
        response = interceptor.onResponse(response);
      }

      return response;
    } on Exception catch (e) {
      stopwatch.stop();
      if (e.toString().contains('TimeoutException')) {
        throw TimeoutError(uri.toString());
      }
      rethrow;
    }
  }

  /// Parse a content type string into a MediaType.
  MediaType _parseMediaType(String contentType) {
    final parts = contentType.split('/');
    if (parts.length == 2) {
      return MediaType(parts[0], parts[1]);
    }
    return MediaType('application', 'octet-stream');
  }

  /// Extract headers that a middleware would add, without executing the pipeline.
  Future<ApiRequest> _extractMiddlewareHeaders(
      Middleware middleware, ApiRequest request) async {
    // Run the middleware with a no-op next that just returns the request as-is
    ApiRequest? captured;
    await middleware.handle(request, (req) async {
      captured = req;
      return const ApiResponse(
        statusCode: 200,
        headers: {},
        body: '',
        duration: Duration.zero,
      );
    });
    return captured ?? request;
  }

  Future<ApiResponse> _executeWithMiddleware(ApiRequest request) {
    if (_middlewares.isEmpty) {
      return _executeWithRetry(request);
    }

    // Build middleware chain from inside out
    Next chain = (req) => _executeWithRetry(req);
    for (var i = _middlewares.length - 1; i >= 0; i--) {
      final middleware = _middlewares[i];
      final next = chain;
      chain = (req) => middleware.handle(req, next);
    }

    return chain(request);
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
