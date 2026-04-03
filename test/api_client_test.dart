import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:philiprehberger_api_client/api_client.dart';
import 'package:test/test.dart';

/// A fake HTTP client that returns canned responses.
class FakeHttpClient extends http.BaseClient {
  final List<http.BaseRequest> requests = [];
  int _callCount = 0;

  http.StreamedResponse Function(http.BaseRequest) _handler;

  FakeHttpClient({http.StreamedResponse Function(http.BaseRequest)? handler})
      : _handler = handler ??
            ((_) => http.StreamedResponse(
                  Stream.value(utf8.encode('{"ok":true}')),
                  200,
                ));

  set handler(http.StreamedResponse Function(http.BaseRequest) value) =>
      _handler = value;

  int get callCount => _callCount;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _callCount++;
    requests.add(request);
    return _handler(request);
  }
}

http.StreamedResponse _response(int statusCode, String body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
  );
}

void main() {
  group('ApiRequest', () {
    test('creates with required fields', () {
      final uri = Uri.parse('https://example.com/test');
      final request = ApiRequest(method: 'GET', uri: uri);

      expect(request.method, equals('GET'));
      expect(request.uri, equals(uri));
      expect(request.headers, isEmpty);
      expect(request.body, isNull);
    });

    test('creates with all fields', () {
      final uri = Uri.parse('https://example.com/test');
      final request = ApiRequest(
        method: 'POST',
        uri: uri,
        headers: {'Authorization': 'Bearer token'},
        body: '{"key":"value"}',
      );

      expect(request.method, equals('POST'));
      expect(request.headers, containsPair('Authorization', 'Bearer token'));
      expect(request.body, equals('{"key":"value"}'));
    });

    test('withHeaders merges headers', () {
      final request = ApiRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com'),
        headers: {'Accept': 'application/json'},
      );

      final updated = request.withHeaders({'Authorization': 'Bearer x'});

      expect(updated.headers, containsPair('Accept', 'application/json'));
      expect(updated.headers, containsPair('Authorization', 'Bearer x'));
      expect(updated.method, equals('GET'));
    });

    test('withHeaders overwrites existing keys', () {
      final request = ApiRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com'),
        headers: {'Accept': 'text/plain'},
      );

      final updated = request.withHeaders({'Accept': 'application/json'});

      expect(updated.headers['Accept'], equals('application/json'));
    });
  });

  group('ApiResponse', () {
    test('isSuccess for 2xx status codes', () {
      for (final code in [200, 201, 204, 299]) {
        final response = ApiResponse(
          statusCode: code,
          headers: {},
          body: '',
          duration: Duration.zero,
        );
        expect(response.isSuccess, isTrue, reason: 'status $code');
      }
    });

    test('isSuccess false for non-2xx', () {
      for (final code in [100, 301, 400, 500]) {
        final response = ApiResponse(
          statusCode: code,
          headers: {},
          body: '',
          duration: Duration.zero,
        );
        expect(response.isSuccess, isFalse, reason: 'status $code');
      }
    });

    test('isClientError for 4xx status codes', () {
      for (final code in [400, 401, 403, 404, 422, 499]) {
        final response = ApiResponse(
          statusCode: code,
          headers: {},
          body: '',
          duration: Duration.zero,
        );
        expect(response.isClientError, isTrue, reason: 'status $code');
      }
    });

    test('isServerError for 5xx status codes', () {
      for (final code in [500, 502, 503, 504]) {
        final response = ApiResponse(
          statusCode: code,
          headers: {},
          body: '',
          duration: Duration.zero,
        );
        expect(response.isServerError, isTrue, reason: 'status $code');
      }
    });

    test('json decodes body', () {
      final response = ApiResponse(
        statusCode: 200,
        headers: {},
        body: '{"name":"test","count":42}',
        duration: Duration.zero,
      );

      expect(response.json, isA<Map>());
    });

    test('jsonMap returns Map<String, dynamic>', () {
      final response = ApiResponse(
        statusCode: 200,
        headers: {},
        body: '{"name":"test","count":42}',
        duration: Duration.zero,
      );

      final map = response.jsonMap;
      expect(map['name'], equals('test'));
      expect(map['count'], equals(42));
    });

    test('jsonList returns List<dynamic>', () {
      final response = ApiResponse(
        statusCode: 200,
        headers: {},
        body: '[1,2,3]',
        duration: Duration.zero,
      );

      expect(response.jsonList, equals([1, 2, 3]));
    });

    test('toString includes status and size', () {
      final response = ApiResponse(
        statusCode: 200,
        headers: {},
        body: 'hello',
        duration: const Duration(milliseconds: 150),
      );

      expect(response.toString(), contains('200'));
      expect(response.toString(), contains('5 bytes'));
      expect(response.toString(), contains('150ms'));
    });
  });

  group('ApiError', () {
    test('creates with message', () {
      const error = ApiError('something went wrong');

      expect(error.message, equals('something went wrong'));
      expect(error.request, isNull);
      expect(error.response, isNull);
      expect(error.toString(), equals('ApiError: something went wrong'));
    });

    test('creates with request and response', () {
      final request =
          ApiRequest(method: 'GET', uri: Uri.parse('https://example.com'));
      const response = ApiResponse(
        statusCode: 500,
        headers: {},
        body: 'error',
        duration: Duration.zero,
      );
      final error =
          ApiError('fail', request: request, response: response);

      expect(error.request, equals(request));
      expect(error.response, equals(response));
    });
  });

  group('HttpError', () {
    test('has status code from response', () {
      final request =
          ApiRequest(method: 'GET', uri: Uri.parse('https://example.com'));
      const response = ApiResponse(
        statusCode: 404,
        headers: {},
        body: 'not found',
        duration: Duration.zero,
      );
      final error = HttpError(request, response);

      expect(error.statusCode, equals(404));
      expect(error.message, equals('HTTP 404'));
    });
  });

  group('TimeoutError', () {
    test('includes URL in message', () {
      const error = TimeoutError('https://example.com/slow');

      expect(error.message, contains('https://example.com/slow'));
      expect(error.toString(), contains('timed out'));
    });
  });

  group('RetryExhaustedError', () {
    test('includes attempt count', () {
      const inner = ApiError('connection refused');
      final error = RetryExhaustedError(3, inner);

      expect(error.attempts, equals(3));
      expect(error.lastError, equals(inner));
      expect(error.message, contains('3'));
    });
  });

  group('RetryConfig', () {
    test('has sensible defaults', () {
      const config = RetryConfig();

      expect(config.maxAttempts, equals(3));
      expect(config.initialDelay, equals(const Duration(milliseconds: 500)));
      expect(config.backoffMultiplier, equals(2.0));
      expect(config.retryableStatuses,
          containsAll([408, 429, 500, 502, 503, 504]));
    });

    test('delayForAttempt calculates exponential backoff', () {
      const config = RetryConfig(
        initialDelay: Duration(milliseconds: 100),
        backoffMultiplier: 2.0,
      );

      expect(config.delayForAttempt(0), equals(const Duration(milliseconds: 100)));
      expect(config.delayForAttempt(1), equals(const Duration(milliseconds: 200)));
      expect(config.delayForAttempt(2), equals(const Duration(milliseconds: 400)));
    });

    test('shouldRetry returns true for retryable statuses', () {
      const config = RetryConfig();

      expect(config.shouldRetry(500), isTrue);
      expect(config.shouldRetry(429), isTrue);
      expect(config.shouldRetry(200), isFalse);
      expect(config.shouldRetry(404), isFalse);
    });
  });

  group('HeaderInterceptor', () {
    test('adds headers to request', () {
      final interceptor = HeaderInterceptor({
        'Authorization': 'Bearer token123',
        'X-Custom': 'value',
      });

      final request = ApiRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com'),
      );

      final updated = interceptor.onRequest(request);

      expect(
          updated.headers, containsPair('Authorization', 'Bearer token123'));
      expect(updated.headers, containsPair('X-Custom', 'value'));
    });

    test('preserves existing headers', () {
      final interceptor = HeaderInterceptor({'X-New': 'new'});

      final request = ApiRequest(
        method: 'GET',
        uri: Uri.parse('https://example.com'),
        headers: {'X-Existing': 'existing'},
      );

      final updated = interceptor.onRequest(request);

      expect(updated.headers, containsPair('X-Existing', 'existing'));
      expect(updated.headers, containsPair('X-New', 'new'));
    });
  });

  group('LogInterceptor', () {
    test('logs request method and URI', () {
      final logs = <String>[];
      final interceptor = LogInterceptor(logs.add);

      final request = ApiRequest(
        method: 'POST',
        uri: Uri.parse('https://example.com/data'),
      );

      interceptor.onRequest(request);

      expect(logs, hasLength(1));
      expect(logs.first, contains('POST'));
      expect(logs.first, contains('https://example.com/data'));
    });

    test('logs response status and duration', () {
      final logs = <String>[];
      final interceptor = LogInterceptor(logs.add);

      const response = ApiResponse(
        statusCode: 201,
        headers: {},
        body: '',
        duration: Duration(milliseconds: 42),
      );

      interceptor.onResponse(response);

      expect(logs, hasLength(1));
      expect(logs.first, contains('201'));
      expect(logs.first, contains('42ms'));
    });
  });

  group('ApiClient', () {
    test('creates without errors', () {
      final client = ApiClient(baseUrl: 'https://api.example.com');
      expect(client.baseUrl, equals('https://api.example.com'));
      expect(client.timeout, equals(const Duration(seconds: 30)));
      client.close();
    });

    test('creates with custom timeout', () {
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        timeout: const Duration(seconds: 10),
      );
      expect(client.timeout, equals(const Duration(seconds: 10)));
      client.close();
    });

    test('sends GET request', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      final response = await client.get('/users');

      expect(fake.callCount, equals(1));
      expect(fake.requests.first.method, equals('GET'));
      expect(fake.requests.first.url.toString(),
          equals('https://api.example.com/users'));
      expect(response.isSuccess, isTrue);
      client.close();
    });

    test('sends POST request with JSON body', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.post('/users', body: {'name': 'Alice'});

      final request = fake.requests.first as http.Request;
      expect(request.method, equals('POST'));
      expect(request.headers['Content-Type'],
          equals('application/json'));
      expect(request.body, equals('{"name":"Alice"}'));
      client.close();
    });

    test('sends PUT request', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.put('/users/1', body: {'name': 'Bob'});

      expect(fake.requests.first.method, equals('PUT'));
      client.close();
    });

    test('sends PATCH request', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.patch('/users/1', body: {'name': 'Charlie'});

      expect(fake.requests.first.method, equals('PATCH'));
      client.close();
    });

    test('sends DELETE request', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.delete('/users/1');

      expect(fake.requests.first.method, equals('DELETE'));
      client.close();
    });

    test('appends query parameters', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.get('/search', query: {'q': 'dart', 'page': '1'});

      final url = fake.requests.first.url;
      expect(url.queryParameters['q'], equals('dart'));
      expect(url.queryParameters['page'], equals('1'));
      client.close();
    });

    test('applies request interceptors in order', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      client.addInterceptor(HeaderInterceptor({'X-First': '1'}));
      client.addInterceptor(HeaderInterceptor({'X-Second': '2'}));

      await client.get('/test');

      expect(fake.requests.first.headers['X-First'], equals('1'));
      expect(fake.requests.first.headers['X-Second'], equals('2'));
      client.close();
    });

    test('applies response interceptors in order', () async {
      final order = <int>[];

      final interceptor1 = _TrackingInterceptor(1, order);
      final interceptor2 = _TrackingInterceptor(2, order);

      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      client.addInterceptor(interceptor1);
      client.addInterceptor(interceptor2);

      await client.get('/test');

      expect(order, equals([1, 2]));
      client.close();
    });

    test('removes interceptor', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      final interceptor = HeaderInterceptor({'X-Remove': 'yes'});
      client.addInterceptor(interceptor);
      client.removeInterceptor(interceptor);

      await client.get('/test');

      expect(fake.requests.first.headers.containsKey('X-Remove'), isFalse);
      client.close();
    });

    test('sends string body as-is', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.post('/raw', body: 'raw text');

      final request = fake.requests.first as http.Request;
      expect(request.body, equals('raw text'));
      client.close();
    });

    test('retries on retryable status codes', () async {
      var callCount = 0;
      final fake = FakeHttpClient(handler: (_) {
        callCount++;
        if (callCount < 3) {
          return _response(503, 'Service Unavailable');
        }
        return _response(200, '{"ok":true}');
      });

      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
        retryConfig: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
      );

      final response = await client.get('/flaky');

      expect(response.statusCode, equals(200));
      expect(callCount, equals(3));
      client.close();
    });

    test('retries and returns last response when all attempts get retryable status', () async {
      var attempts = 0;
      final fake = FakeHttpClient(
        handler: (_) {
          attempts++;
          return _response(500, 'Internal Server Error');
        },
      );

      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
        retryConfig: const RetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 1),
        ),
      );

      final response = await client.get('/fail');
      expect(response.statusCode, equals(500));
      expect(attempts, equals(3));
      client.close();
    });

    test('passes custom headers to request', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.get('/test', headers: {'X-Custom': 'value'});

      expect(fake.requests.first.headers['X-Custom'], equals('value'));
      client.close();
    });
  });

  group('CacheInterceptor', () {
    test('caches GET response', () {
      final cache = CacheInterceptor(ttl: const Duration(minutes: 5));
      final request = ApiRequest(method: 'GET', uri: Uri.parse('https://api.example.com/data'));
      final response = ApiResponse(statusCode: 200, headers: {}, body: '{"ok":true}', duration: Duration.zero);

      cache.cacheResponse(request, response);
      final cached = cache.getCached(request);
      expect(cached, isNotNull);
      expect(cached!.body, equals('{"ok":true}'));
    });

    test('does not cache non-GET requests', () {
      final cache = CacheInterceptor();
      final request = ApiRequest(method: 'POST', uri: Uri.parse('https://api.example.com/data'));
      final response = ApiResponse(statusCode: 200, headers: {}, body: '{}', duration: Duration.zero);

      cache.cacheResponse(request, response);
      expect(cache.getCached(request), isNull);
    });

    test('does not cache error responses', () {
      final cache = CacheInterceptor();
      final request = ApiRequest(method: 'GET', uri: Uri.parse('https://api.example.com/data'));
      final response = ApiResponse(statusCode: 500, headers: {}, body: 'error', duration: Duration.zero);

      cache.cacheResponse(request, response);
      expect(cache.getCached(request), isNull);
    });

    test('invalidate removes cached entry', () {
      final cache = CacheInterceptor();
      final request = ApiRequest(method: 'GET', uri: Uri.parse('https://api.example.com/users'));
      final response = ApiResponse(statusCode: 200, headers: {}, body: '[]', duration: Duration.zero);

      cache.cacheResponse(request, response);
      cache.invalidate('/users');
      expect(cache.getCached(request), isNull);
    });

    test('clearAll empties cache', () {
      final cache = CacheInterceptor();
      final request = ApiRequest(method: 'GET', uri: Uri.parse('https://api.example.com/a'));
      final response = ApiResponse(statusCode: 200, headers: {}, body: '{}', duration: Duration.zero);

      cache.cacheResponse(request, response);
      cache.clearAll();
      expect(cache.size, equals(0));
    });

    test('respects maxEntries', () {
      final cache = CacheInterceptor(maxEntries: 2);
      for (var i = 0; i < 5; i++) {
        cache.cacheResponse(
          ApiRequest(method: 'GET', uri: Uri.parse('https://api.example.com/$i')),
          ApiResponse(statusCode: 200, headers: {}, body: '$i', duration: Duration.zero),
        );
      }
      expect(cache.size, equals(2));
    });
  });

  group('Typed deserialization', () {
    test('getTyped deserializes response', () async {
      final fake = FakeHttpClient(handler: (_) => _response(200, '{"name":"Alice","age":30}'));
      final client = ApiClient(baseUrl: 'https://api.example.com', httpClient: fake);

      final user = await client.getTyped('/user', decoder: (json) => json['name'] as String);
      expect(user, equals('Alice'));
      client.close();
    });

    test('getTyped throws on error response', () async {
      final fake = FakeHttpClient(handler: (_) => _response(404, '{"error":"not found"}'));
      final client = ApiClient(baseUrl: 'https://api.example.com', httpClient: fake);

      expect(
        () => client.getTyped('/user', decoder: (json) => json),
        throwsA(isA<HttpError>()),
      );
      client.close();
    });

    test('postTyped deserializes response', () async {
      final fake = FakeHttpClient(handler: (_) => _response(201, '{"id":1,"name":"Alice"}'));
      final client = ApiClient(baseUrl: 'https://api.example.com', httpClient: fake);

      final id = await client.postTyped(
        '/users',
        body: {'name': 'Alice'},
        decoder: (json) => json['id'] as int,
      );
      expect(id, equals(1));
      client.close();
    });
  });

  group('MultipartFile', () {
    test('creates with required fields', () {
      final file = MultipartFile(
        field: 'avatar',
        bytes: [1, 2, 3],
      );

      expect(file.field, equals('avatar'));
      expect(file.bytes, equals([1, 2, 3]));
      expect(file.filename, isNull);
      expect(file.contentType, isNull);
    });

    test('creates with all fields', () {
      final file = MultipartFile(
        field: 'document',
        bytes: [4, 5, 6],
        filename: 'report.pdf',
        contentType: 'application/pdf',
      );

      expect(file.field, equals('document'));
      expect(file.bytes, equals([4, 5, 6]));
      expect(file.filename, equals('report.pdf'));
      expect(file.contentType, equals('application/pdf'));
    });
  });

  group('AuthMiddleware', () {
    test('adds Authorization header', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      client.addMiddleware(
          AuthMiddleware(scheme: 'Bearer', token: 'my-token'));

      await client.get('/protected');

      expect(fake.requests.first.headers['Authorization'],
          equals('Bearer my-token'));
      client.close();
    });

    test('preserves existing headers', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      client.addMiddleware(
          AuthMiddleware(scheme: 'Basic', token: 'abc123'));

      await client.get('/test', headers: {'X-Custom': 'value'});

      expect(fake.requests.first.headers['Authorization'],
          equals('Basic abc123'));
      expect(
          fake.requests.first.headers['X-Custom'], equals('value'));
      client.close();
    });
  });

  group('LoggingMiddleware', () {
    test('logs request and response', () async {
      final logs = <String>[];
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      client.addMiddleware(LoggingMiddleware(logger: logs.add));

      await client.get('/data');

      expect(logs, hasLength(2));
      expect(logs[0], contains('GET'));
      expect(logs[0], contains('https://api.example.com/data'));
      expect(logs[1], contains('200'));
    });
  });

  group('Middleware chaining', () {
    test('runs middlewares in order', () async {
      final order = <String>[];
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      client.addMiddleware(_TrackingMiddleware('first', order));
      client.addMiddleware(_TrackingMiddleware('second', order));

      await client.get('/test');

      expect(order,
          equals(['first-before', 'second-before', 'second-after', 'first-after']));
      client.close();
    });

    test('removeMiddleware removes from pipeline', () async {
      final order = <String>[];
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      final middleware = _TrackingMiddleware('removed', order);
      client.addMiddleware(middleware);
      client.removeMiddleware(middleware);

      await client.get('/test');

      expect(order, isEmpty);
      client.close();
    });
  });

  group('Multipart requests', () {
    test('postMultipart sends multipart request', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.postMultipart(
        '/upload',
        fields: {'name': 'test'},
        files: [
          MultipartFile(
            field: 'file',
            bytes: [1, 2, 3],
            filename: 'test.txt',
          ),
        ],
      );

      final request = fake.requests.first as http.MultipartRequest;
      expect(request.method, equals('POST'));
      expect(request.url.toString(),
          equals('https://api.example.com/upload'));
      expect(request.fields['name'], equals('test'));
      expect(request.files, hasLength(1));
      expect(request.files.first.field, equals('file'));
      expect(request.files.first.filename, equals('test.txt'));
      client.close();
    });

    test('putMultipart sends multipart request', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      await client.putMultipart(
        '/upload/1',
        fields: {'name': 'updated'},
        files: [
          MultipartFile(
            field: 'file',
            bytes: [4, 5, 6],
            filename: 'updated.txt',
            contentType: 'text/plain',
          ),
        ],
      );

      final request = fake.requests.first as http.MultipartRequest;
      expect(request.method, equals('PUT'));
      expect(request.url.toString(),
          equals('https://api.example.com/upload/1'));
      expect(request.fields['name'], equals('updated'));
      expect(request.files, hasLength(1));
      client.close();
    });

    test('postMultipart applies interceptor headers', () async {
      final fake = FakeHttpClient();
      final client = ApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: fake,
      );

      client.addInterceptor(HeaderInterceptor({'X-Api-Key': 'abc'}));

      await client.postMultipart(
        '/upload',
        fields: {'name': 'test'},
      );

      expect(fake.requests.first.headers['X-Api-Key'], equals('abc'));
      client.close();
    });
  });
}

class _TrackingMiddleware extends Middleware {
  final String name;
  final List<String> order;

  _TrackingMiddleware(this.name, this.order);

  @override
  Future<ApiResponse> handle(ApiRequest request, Next next) async {
    order.add('$name-before');
    final response = await next(request);
    order.add('$name-after');
    return response;
  }
}

class _TrackingInterceptor extends Interceptor {
  final int id;
  final List<int> order;

  _TrackingInterceptor(this.id, this.order);

  @override
  ApiResponse onResponse(ApiResponse response) {
    order.add(id);
    return response;
  }
}
