# philiprehberger_api_client

[![Tests](https://github.com/philiprehberger/dart-api-client/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/dart-api-client/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/philiprehberger_api_client.svg)](https://pub.dev/packages/philiprehberger_api_client)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/dart-api-client)](https://github.com/philiprehberger/dart-api-client/commits/main)

Declarative API client with typed responses, retries, and interceptors

## Requirements

- Dart >= 3.6

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  philiprehberger_api_client: ^0.3.0
```

Then run:

```bash
dart pub get
```

## Usage

```dart
import 'package:philiprehberger_api_client/api_client.dart';

final client = ApiClient(baseUrl: 'https://api.example.com');
final response = await client.get('/users');
print(response.jsonList);
client.close();
```

### GET Requests

```dart
// Simple GET
final response = await client.get('/users');

// GET with query parameters
final filtered = await client.get('/users', query: {'role': 'admin'});

// Access typed response data
final users = response.jsonList;
final user = response.jsonMap;
```

### POST, PUT, PATCH Requests

```dart
// POST with JSON body (automatically serialized)
final created = await client.post('/users', body: {
  'name': 'Alice',
  'email': 'alice@example.com',
});

// PUT request
await client.put('/users/1', body: {'name': 'Updated'});

// PATCH request
await client.patch('/users/1', body: {'email': 'new@example.com'});

// DELETE request
await client.delete('/users/1');
```

### Typed Deserialization

```dart
// GET with typed response
final user = await client.getTyped<User>(
  '/users/1',
  decoder: (json) => User.fromJson(json),
);

// POST with typed response
final created = await client.postTyped<User>(
  '/users',
  body: {'name': 'Alice'},
  decoder: (json) => User.fromJson(json),
);
```

### Caching

```dart
// Cache GET responses in memory
final cache = CacheInterceptor(
  ttl: const Duration(minutes: 5),
  maxEntries: 100,
);
client.addInterceptor(cache);

// Invalidate specific paths
cache.invalidate('/users');

// Clear entire cache
cache.clearAll();
```

### Middleware

```dart
// Add authentication to every request
client.addMiddleware(AuthMiddleware(scheme: 'Bearer', token: 'my-token'));

// Log requests and responses
client.addMiddleware(LoggingMiddleware(logger: print));

// Custom middleware
class RateLimitMiddleware extends Middleware {
  @override
  Future<ApiResponse> handle(ApiRequest request, Next next) async {
    await _waitForRateLimit();
    return next(request);
  }
}

// Remove middleware
client.removeMiddleware(authMiddleware);
```

### Multipart Uploads

```dart
// POST multipart with fields and files
final response = await client.postMultipart(
  '/upload',
  fields: {'description': 'Profile photo'},
  files: [
    MultipartFile(
      field: 'avatar',
      bytes: imageBytes,
      filename: 'photo.jpg',
      contentType: 'image/jpeg',
    ),
  ],
);

// PUT multipart
await client.putMultipart(
  '/upload/1',
  fields: {'description': 'Updated photo'},
  files: [
    MultipartFile(
      field: 'avatar',
      bytes: newImageBytes,
      filename: 'photo.jpg',
    ),
  ],
);
```

### Interceptors

```dart
// Add headers to every request
client.addInterceptor(HeaderInterceptor({
  'Authorization': 'Bearer token',
  'Accept': 'application/json',
}));

// Log requests and responses
client.addInterceptor(LogInterceptor(print));

// Custom interceptor
class AuthRefreshInterceptor extends Interceptor {
  @override
  ApiRequest onRequest(ApiRequest request) {
    return request.withHeaders({'Authorization': 'Bearer $token'});
  }

  @override
  void onError(Object error) {
    if (error is HttpError && error.statusCode == 401) {
      // Handle token refresh
    }
    throw error;
  }
}
```

### Retry Configuration

```dart
final client = ApiClient(
  baseUrl: 'https://api.example.com',
  retryConfig: const RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 2.0,
    retryableStatuses: {408, 429, 500, 502, 503, 504},
  ),
);
```

### Error Handling

```dart
try {
  final response = await client.get('/users');
} on HttpError catch (e) {
  print('HTTP ${e.statusCode}');
} on TimeoutError catch (e) {
  print('Request timed out: ${e.message}');
} on RetryExhaustedError catch (e) {
  print('Failed after ${e.attempts} attempts');
} on ApiError catch (e) {
  print('API error: ${e.message}');
}
```

### Response Inspection

```dart
final response = await client.get('/users/1');

// Status helpers
response.isSuccess;     // true for 2xx
response.isClientError; // true for 4xx
response.isServerError; // true for 5xx

// Typed JSON access
response.json;     // dynamic
response.jsonMap;  // Map<String, dynamic>
response.jsonList; // List<dynamic>

// Metadata
response.statusCode; // 200
response.headers;    // Map<String, String>
response.duration;   // Duration
```

## API

### ApiClient

| Method / Property | Description |
|---|---|
| `ApiClient({required String baseUrl, Duration timeout, RetryConfig? retryConfig, http.Client? httpClient})` | Create an API client |
| `get(String path, {Map<String, String>? query, Map<String, String>? headers})` | Send a GET request |
| `post(String path, {Object? body, Map<String, String>? headers})` | Send a POST request |
| `put(String path, {Object? body, Map<String, String>? headers})` | Send a PUT request |
| `patch(String path, {Object? body, Map<String, String>? headers})` | Send a PATCH request |
| `delete(String path, {Map<String, String>? headers})` | Send a DELETE request |
| `getTyped<T>(String path, {required T Function(Map<String, dynamic>) decoder, Map<String, String>? query, Map<String, String>? headers})` | Send a GET request and deserialize the response |
| `postTyped<T>(String path, {required T Function(Map<String, dynamic>) decoder, Object? body, Map<String, String>? headers})` | Send a POST request and deserialize the response |
| `postMultipart(String path, {Map<String, String>? fields, List<MultipartFile>? files, Map<String, String>? headers})` | Send a POST multipart request |
| `putMultipart(String path, {Map<String, String>? fields, List<MultipartFile>? files, Map<String, String>? headers})` | Send a PUT multipart request |
| `addInterceptor(Interceptor interceptor)` | Add a request/response interceptor |
| `removeInterceptor(Interceptor interceptor)` | Remove an interceptor |
| `addMiddleware(Middleware middleware)` | Add a middleware to the pipeline |
| `removeMiddleware(Middleware middleware)` | Remove a middleware from the pipeline |
| `close()` | Close the underlying HTTP client |

### ApiRequest

| Method / Property | Description |
|---|---|
| `ApiRequest({required String method, required Uri uri, Map<String, String> headers, String? body})` | Create an API request |
| `method` | The HTTP method |
| `uri` | The fully resolved URI |
| `headers` | The request headers |
| `body` | The request body |
| `withHeaders(Map<String, String> extra)` | Create a copy with merged headers |

### ApiResponse

| Method / Property | Description |
|---|---|
| `statusCode` | The HTTP status code |
| `headers` | The response headers |
| `body` | The response body as a string |
| `duration` | The time taken to complete the request |
| `isSuccess` | Whether the status code is 2xx |
| `isClientError` | Whether the status code is 4xx |
| `isServerError` | Whether the status code is 5xx |
| `json` | Decode the body as JSON (dynamic) |
| `jsonMap` | Decode the body as a JSON map |
| `jsonList` | Decode the body as a JSON list |

### Error Types

| Class | Description |
|---|---|
| `ApiError` | Base error for API operations |
| `HttpError` | Thrown for non-2xx status codes; exposes `statusCode` |
| `TimeoutError` | Thrown when a request exceeds the timeout |
| `RetryExhaustedError` | Thrown when all retry attempts fail; exposes `attempts` and `lastError` |

### Interceptor

| Method | Description |
|---|---|
| `onRequest(ApiRequest request)` | Called before a request is sent; return a modified or same request |
| `onResponse(ApiResponse response)` | Called after a response is received; return a modified or same response |
| `onError(Object error)` | Called on error; can throw or handle |

### Built-in Interceptors

| Class | Description |
|---|---|
| `HeaderInterceptor(Map<String, String> headers)` | Adds headers to every request |
| `LogInterceptor(void Function(String) log)` | Logs requests and responses to a callback |
| `CacheInterceptor({Duration ttl, int maxEntries})` | Caches GET responses in memory with TTL and size limit |

### Middleware

| Method | Description |
|---|---|
| `handle(ApiRequest request, Next next)` | Process a request and return a response; call `next` to continue the pipeline |

### Built-in Middlewares

| Class | Description |
|---|---|
| `AuthMiddleware({required String scheme, required String token})` | Adds `Authorization` header to every request |
| `LoggingMiddleware({void Function(String)? logger})` | Logs request method/URI and response status/duration |

### MultipartFile

| Method / Property | Description |
|---|---|
| `MultipartFile({required String field, required List<int> bytes, String? filename, String? contentType})` | Create a multipart file |
| `field` | The form field name |
| `bytes` | The file content as bytes |
| `filename` | The filename, if any |
| `contentType` | The MIME content type, if any |

### RetryConfig

| Method / Property | Description |
|---|---|
| `RetryConfig({int maxAttempts, Duration initialDelay, double backoffMultiplier, Set<int> retryableStatuses})` | Create retry configuration |
| `maxAttempts` | Maximum number of retry attempts (default: 3) |
| `initialDelay` | Initial delay before the first retry (default: 500ms) |
| `backoffMultiplier` | Multiplier for each subsequent retry (default: 2.0) |
| `retryableStatuses` | Status codes that trigger a retry (default: 408, 429, 500, 502, 503, 504) |
| `delayForAttempt(int attempt)` | Calculate delay for a given attempt number |
| `shouldRetry(int statusCode)` | Whether a status code should trigger a retry |

## Development

```bash
dart pub get
dart analyze --fatal-infos
dart test
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/dart-api-client)

🐛 [Report issues](https://github.com/philiprehberger/dart-api-client/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/dart-api-client/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
