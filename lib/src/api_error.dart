import 'api_request.dart';
import 'api_response.dart';

/// Base error for API operations.
class ApiError implements Exception {
  /// The error message.
  final String message;

  /// The request that caused the error, if available.
  final ApiRequest? request;

  /// The response associated with the error, if available.
  final ApiResponse? response;

  /// Create an API error.
  const ApiError(this.message, {this.request, this.response});

  @override
  String toString() => 'ApiError: $message';
}

/// Thrown when the server returns a non-2xx status.
class HttpError extends ApiError {
  /// Create an HTTP error from a request and response.
  HttpError(ApiRequest request, ApiResponse response)
      : super('HTTP ${response.statusCode}',
            request: request, response: response);

  /// The HTTP status code.
  int get statusCode => response!.statusCode;
}

/// Thrown when a request times out.
class TimeoutError extends ApiError {
  /// Create a timeout error.
  const TimeoutError(String url) : super('Request timed out: $url');
}

/// Thrown when all retry attempts are exhausted.
class RetryExhaustedError extends ApiError {
  /// The number of attempts that were made.
  final int attempts;

  /// The last error encountered.
  final ApiError lastError;

  /// Create a retry exhausted error.
  RetryExhaustedError(this.attempts, this.lastError)
      : super('All $attempts retry attempts exhausted');
}
