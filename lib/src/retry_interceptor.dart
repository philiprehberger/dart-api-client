/// Configuration for automatic request retries.
class RetryConfig {
  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Initial delay before the first retry.
  final Duration initialDelay;

  /// Multiplier applied to the delay for each subsequent retry.
  final double backoffMultiplier;

  /// HTTP status codes that trigger a retry.
  final Set<int> retryableStatuses;

  /// Create a retry configuration.
  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.retryableStatuses = const {408, 429, 500, 502, 503, 504},
  });

  /// Calculate delay for a given attempt number (0-based).
  Duration delayForAttempt(int attempt) {
    final multiplier = backoffMultiplier > 0
        ? List.generate(attempt, (_) => backoffMultiplier)
            .fold(1.0, (a, b) => a * b)
        : 1.0;
    return Duration(
      milliseconds: (initialDelay.inMilliseconds * multiplier).round(),
    );
  }

  /// Whether a status code should trigger a retry.
  bool shouldRetry(int statusCode) => retryableStatuses.contains(statusCode);
}
