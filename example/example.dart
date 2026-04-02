import 'package:philiprehberger_api_client/api_client.dart';

void main() async {
  // Create a client with base URL and retry configuration
  final client = ApiClient(
    baseUrl: 'https://jsonplaceholder.typicode.com',
    timeout: const Duration(seconds: 10),
    retryConfig: const RetryConfig(
      maxAttempts: 3,
      initialDelay: Duration(milliseconds: 500),
      backoffMultiplier: 2.0,
    ),
  );

  // Add interceptors
  client.addInterceptor(HeaderInterceptor({
    'Accept': 'application/json',
  }));

  client.addInterceptor(LogInterceptor(print));

  try {
    // GET request
    final users = await client.get('/users');
    print('Users: ${users.jsonList.length}');

    // GET with query parameters
    final filtered = await client.get('/posts', query: {'userId': '1'});
    print('Posts by user 1: ${filtered.jsonList.length}');

    // POST request with JSON body
    final created = await client.post('/posts', body: {
      'title': 'Hello',
      'body': 'World',
      'userId': 1,
    });
    print('Created post: ${created.jsonMap['id']}');

    // PUT request
    final updated = await client.put('/posts/1', body: {
      'id': 1,
      'title': 'Updated',
      'body': 'Content',
      'userId': 1,
    });
    print('Updated: ${updated.isSuccess}');

    // DELETE request
    final deleted = await client.delete('/posts/1');
    print('Deleted: ${deleted.isSuccess}');

    // Response inspection
    final response = await client.get('/posts/1');
    print('Status: ${response.statusCode}');
    print('Success: ${response.isSuccess}');
    print('Duration: ${response.duration.inMilliseconds}ms');
    print('Title: ${response.jsonMap['title']}');
  } on HttpError catch (e) {
    print('HTTP error: ${e.statusCode}');
  } on TimeoutError catch (e) {
    print('Timeout: ${e.message}');
  } on RetryExhaustedError catch (e) {
    print('Retries exhausted after ${e.attempts} attempts');
  } finally {
    client.close();
  }
}
