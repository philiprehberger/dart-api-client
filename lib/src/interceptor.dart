import 'api_request.dart';
import 'api_response.dart';

/// Intercepts requests and responses for cross-cutting concerns.
abstract class Interceptor {
  /// Called before a request is sent. Return a modified request or the same one.
  ApiRequest onRequest(ApiRequest request) => request;

  /// Called after a response is received. Return a modified response or the same one.
  ApiResponse onResponse(ApiResponse response) => response;

  /// Called when an error occurs. Can throw or return a recovery response.
  void onError(Object error) => throw error;
}

/// Interceptor that adds headers to every request.
class HeaderInterceptor extends Interceptor {
  /// The headers to add to every request.
  final Map<String, String> headers;

  /// Create a header interceptor.
  HeaderInterceptor(this.headers);

  @override
  ApiRequest onRequest(ApiRequest request) => request.withHeaders(headers);
}

/// Interceptor that logs requests and responses to a callback.
class LogInterceptor extends Interceptor {
  /// The logging callback.
  final void Function(String) log;

  /// Create a log interceptor.
  LogInterceptor(this.log);

  @override
  ApiRequest onRequest(ApiRequest request) {
    log('\u2192 ${request.method} ${request.uri}');
    return request;
  }

  @override
  ApiResponse onResponse(ApiResponse response) {
    log('\u2190 ${response.statusCode} (${response.duration.inMilliseconds}ms)');
    return response;
  }
}
