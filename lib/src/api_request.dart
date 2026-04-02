/// An HTTP request configuration.
class ApiRequest {
  /// The HTTP method (GET, POST, PUT, PATCH, DELETE).
  final String method;

  /// The fully resolved URI for the request.
  final Uri uri;

  /// The request headers.
  final Map<String, String> headers;

  /// The request body, if any.
  final String? body;

  /// Create an API request.
  const ApiRequest({
    required this.method,
    required this.uri,
    this.headers = const {},
    this.body,
  });

  /// Create a copy with merged headers.
  ApiRequest withHeaders(Map<String, String> extra) => ApiRequest(
        method: method,
        uri: uri,
        headers: {...headers, ...extra},
        body: body,
      );
}
