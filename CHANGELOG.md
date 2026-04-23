# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-02

### Added
- `Middleware` abstract class for composable request/response pipeline
- `AuthMiddleware` for automatic `Authorization` header injection
- `LoggingMiddleware` for request/response logging
- `ApiClient.addMiddleware()` and `removeMiddleware()`
- `ApiClient.postMultipart()` and `putMultipart()` for file uploads
- `MultipartFile` value class for multipart form data

## [0.2.0] - 2026-04-01

### Added
- `CacheInterceptor` for in-memory GET response caching with TTL and max entries
- `getTyped<T>()` method for typed deserialization of GET responses
- `postTyped<T>()` method for typed deserialization of POST responses

## [0.1.0] - 2026-04-01

### Added
- Initial release
- Declarative API client with `get`, `post`, `put`, `patch`, `delete` methods
- Typed `ApiResponse` with JSON accessors (`json`, `jsonMap`, `jsonList`)
- Status helpers (`isSuccess`, `isClientError`, `isServerError`)
- Interceptor system for cross-cutting concerns
- `HeaderInterceptor` for automatic header injection
- `LogInterceptor` for request/response logging
- `RetryConfig` with exponential backoff and configurable retryable statuses
- `ApiError`, `HttpError`, `TimeoutError`, and `RetryExhaustedError` types
