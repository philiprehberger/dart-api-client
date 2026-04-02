import 'api_request.dart';
import 'api_response.dart';
import 'interceptor.dart';

/// Entry in the response cache.
class _CacheEntry {
  final ApiResponse response;
  final DateTime expiresAt;

  _CacheEntry(this.response, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Interceptor that caches GET responses in memory.
///
/// Only GET requests are cached. Other methods bypass the cache.
class CacheInterceptor extends Interceptor {
  final Duration ttl;
  final int maxEntries;
  final Map<String, _CacheEntry> _cache = {};

  /// Create a cache interceptor.
  ///
  /// [ttl] is the time-to-live for cached entries.
  /// [maxEntries] limits the cache size (oldest entries evicted first).
  CacheInterceptor({
    this.ttl = const Duration(minutes: 5),
    this.maxEntries = 100,
  });

  /// Get a cached response for a request, or null if not cached/expired.
  ApiResponse? getCached(ApiRequest request) {
    if (request.method != 'GET') return null;
    final key = request.uri.toString();
    final entry = _cache[key];
    if (entry == null || entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    return entry.response;
  }

  @override
  ApiResponse onResponse(ApiResponse response) {
    return response;
  }

  /// Cache a response for a GET request.
  void cacheResponse(ApiRequest request, ApiResponse response) {
    if (request.method != 'GET' || !response.isSuccess) return;
    final key = request.uri.toString();
    _cache[key] = _CacheEntry(response, DateTime.now().add(ttl));
    _evictIfNeeded();
  }

  /// Invalidate cached response for a specific path.
  void invalidate(String path) {
    _cache.removeWhere((key, _) => key.contains(path));
  }

  /// Clear all cached responses.
  void clearAll() {
    _cache.clear();
  }

  /// Number of cached entries.
  int get size => _cache.length;

  void _evictIfNeeded() {
    if (_cache.length <= maxEntries) return;
    // Remove oldest entries
    final sorted = _cache.entries.toList()
      ..sort((a, b) => a.value.expiresAt.compareTo(b.value.expiresAt));
    while (_cache.length > maxEntries && sorted.isNotEmpty) {
      _cache.remove(sorted.removeAt(0).key);
    }
  }
}
