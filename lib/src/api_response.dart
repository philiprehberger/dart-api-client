import 'dart:convert';

/// An HTTP response with typed accessors.
class ApiResponse {
  /// The HTTP status code.
  final int statusCode;

  /// The response headers.
  final Map<String, String> headers;

  /// The response body as a string.
  final String body;

  /// The time taken to complete the request.
  final Duration duration;

  /// Create an API response.
  const ApiResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.duration,
  });

  /// Whether the status code indicates success (2xx).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Whether the status code indicates a client error (4xx).
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// Whether the status code indicates a server error (5xx).
  bool get isServerError => statusCode >= 500;

  /// Decode the body as JSON.
  dynamic get json => jsonDecode(body);

  /// Decode the body as a JSON map.
  Map<String, dynamic> get jsonMap => json as Map<String, dynamic>;

  /// Decode the body as a JSON list.
  List<dynamic> get jsonList => json as List<dynamic>;

  @override
  String toString() =>
      'ApiResponse($statusCode, ${body.length} bytes, ${duration.inMilliseconds}ms)';
}
