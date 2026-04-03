import 'api_request.dart';
import 'api_response.dart';

/// Function type for the next step in the middleware pipeline.
typedef Next = Future<ApiResponse> Function(ApiRequest request);

/// Abstract middleware for composable request/response processing.
///
/// Middlewares wrap the HTTP execution pipeline. Each middleware receives the
/// request and a [Next] function to call the next middleware (or the actual
/// HTTP execution at the end of the chain).
abstract class Middleware {
  /// Process a request and return a response.
  ///
  /// Call [next] to continue the pipeline. Middlewares may modify the request
  /// before calling [next] and/or modify the response after.
  Future<ApiResponse> handle(ApiRequest request, Next next);
}

/// Middleware that adds an Authorization header to every request.
class AuthMiddleware extends Middleware {
  /// The authorization scheme (e.g. "Bearer", "Basic").
  final String scheme;

  /// The authorization token.
  final String token;

  /// Create an auth middleware.
  AuthMiddleware({required this.scheme, required this.token});

  @override
  Future<ApiResponse> handle(ApiRequest request, Next next) {
    final updated = request.withHeaders({'Authorization': '$scheme $token'});
    return next(updated);
  }
}

/// Middleware that logs request method/URI and response status/duration.
class LoggingMiddleware extends Middleware {
  /// The logging callback.
  final void Function(String) _logger;

  /// Create a logging middleware.
  ///
  /// [logger] defaults to [print] if not provided.
  LoggingMiddleware({void Function(String)? logger})
      : _logger = logger ?? print;

  @override
  Future<ApiResponse> handle(ApiRequest request, Next next) async {
    _logger('\u2192 ${request.method} ${request.uri}');
    final stopwatch = Stopwatch()..start();
    final response = await next(request);
    stopwatch.stop();
    _logger(
        '\u2190 ${response.statusCode} (${stopwatch.elapsed.inMilliseconds}ms)');
    return response;
  }
}
