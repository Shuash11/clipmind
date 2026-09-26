import 'dart:async';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/policy/provider_url_policy.dart';
import 'package:clipmind/features/providers/data/security/provider_redactor.dart';
import 'package:clipmind/features/providers/domain/entities/immutable_value.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:dio/dio.dart';

enum ProviderHttpMethod { get, post, put, patch, delete }

final class ProviderHttpRequest {
  ProviderHttpRequest({
    required this.method,
    required this.uri,
    Map<String, String> headers = const <String, String>{},
    Object? body,
    this.timeout,
    this.isDiscovery = false,
    this.idempotencyKey,
    this.permitRetry = false,
  }) : headers = Map.unmodifiable(Map<String, String>.from(headers)),
       body = immutableValue(body);

  final ProviderHttpMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final Object? body;
  final Duration? timeout;
  final bool isDiscovery;
  final String? idempotencyKey;
  final bool permitRetry;

  bool get permitsRetry =>
      isDiscovery ||
      method == ProviderHttpMethod.get ||
      permitRetry ||
      (idempotencyKey != null && idempotencyKey!.isNotEmpty);
}

final class ProviderHttpResponse {
  ProviderHttpResponse({
    required this.statusCode,
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) : headers = Map.unmodifiable(Map<String, String>.from(headers)),
       body = immutableValue(body);

  final int statusCode;
  final Map<String, String> headers;
  final Object? body;
}

enum ProviderHttpExceptionKind {
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  connectionReset,
  other,
}

final class ProviderHttpException implements Exception {
  const ProviderHttpException(this.kind);

  final ProviderHttpExceptionKind kind;
}

/// The test seam around the HTTP client. It deliberately contains no Dio types.
abstract interface class ProviderHttpClient {
  Future<ProviderHttpResponse> send(ProviderHttpRequest request);
}

/// The provider-facing transport used by protocol adapters.
abstract interface class ProviderHttpTransport {
  Future<Result<ProviderHttpResponse>> send(
    ProviderHttpRequest request, {
    CancellationToken? token,
  });
}

typedef ProviderRetryDelay = Future<void> Function(Duration duration);

/// Retrying transport with cancellation and redacted, stable failure values.
final class RetryingProviderHttpTransport implements ProviderHttpTransport {
  RetryingProviderHttpTransport({
    required this._client,
    ProviderRetryDelay? retryDelay,
    ProviderRedactor? redactor,
    this.maxRetries = 2,
    this.initialRetryDelay = const Duration(milliseconds: 200),
  }) : _retryDelay = retryDelay ?? _wait,
       _redactor = redactor ?? ProviderRedactor();

  final ProviderHttpClient _client;
  final ProviderRetryDelay _retryDelay;
  final ProviderRedactor _redactor;
  final int maxRetries;
  final Duration initialRetryDelay;

  static Future<void> _wait(Duration duration) =>
      Future<void>.delayed(duration);

  @override
  Future<Result<ProviderHttpResponse>> send(
    ProviderHttpRequest request, {
    CancellationToken? token,
  }) async {
    final allowed = ProviderUrlPolicy.validate(request.uri);
    if (allowed is Failure<ProviderUrlValidation>) {
      return Failure<ProviderHttpResponse>(allowed.error);
    }

    var attempt = 0;
    while (true) {
      try {
        token?.throwIfCancelled();
        final response = await _raceCancellation(_client.send(request), token);
        if (_isSuccess(response.statusCode)) {
          return Success<ProviderHttpResponse>(response);
        }
        if (!_isTransientStatus(response.statusCode) ||
            !request.permitsRetry ||
            attempt >= maxRetries) {
          return Failure<ProviderHttpResponse>(
            _failureFor(request, statusCode: response.statusCode),
          );
        }
      } on CancelledException {
        return const Failure<ProviderHttpResponse>(
          ProviderCancellationFailure(),
        );
      } on ProviderHttpException catch (error) {
        if (token?.isCancelled ?? false) {
          return const Failure<ProviderHttpResponse>(
            ProviderCancellationFailure(),
          );
        }
        if (!_isTransientException(error.kind) ||
            !request.permitsRetry ||
            attempt >= maxRetries) {
          return Failure<ProviderHttpResponse>(_failureFor(request));
        }
      } on DioException catch (error) {
        if (token?.isCancelled ??
            false || error.type == DioExceptionType.cancel) {
          return const Failure<ProviderHttpResponse>(
            ProviderCancellationFailure(),
          );
        }
        final kind = _dioExceptionKind(error);
        if (!_isTransientException(kind) ||
            !request.permitsRetry ||
            attempt >= maxRetries) {
          return Failure<ProviderHttpResponse>(_failureFor(request));
        }
      } catch (_) {
        if (token?.isCancelled ?? false) {
          return const Failure<ProviderHttpResponse>(
            ProviderCancellationFailure(),
          );
        }
        return Failure<ProviderHttpResponse>(_failureFor(request));
      }

      attempt += 1;
      try {
        token?.throwIfCancelled();
        await _raceCancellation(_retryDelay(_delayFor(attempt)), token);
      } on CancelledException {
        return const Failure<ProviderHttpResponse>(
          ProviderCancellationFailure(),
        );
      } catch (_) {
        return Failure<ProviderHttpResponse>(_failureFor(request));
      }
    }
  }

  Duration _delayFor(int retry) => initialRetryDelay * retry;

  Future<T> _raceCancellation<T>(Future<T> work, CancellationToken? token) {
    if (token == null) return work;
    return Future.any<T>(<Future<T>>[
      work,
      token.whenCancelled.then<T>((_) => throw const CancelledException()),
    ]);
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  bool _isTransientStatus(int statusCode) =>
      statusCode == 429 || statusCode >= 500;

  bool _isTransientException(ProviderHttpExceptionKind kind) =>
      kind == ProviderHttpExceptionKind.connectionTimeout ||
      kind == ProviderHttpExceptionKind.sendTimeout ||
      kind == ProviderHttpExceptionKind.receiveTimeout ||
      kind == ProviderHttpExceptionKind.connectionReset;

  ProviderHttpExceptionKind _dioExceptionKind(DioException error) {
    if ('${error.error}'.toLowerCase().contains('connection reset')) {
      return ProviderHttpExceptionKind.connectionReset;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return ProviderHttpExceptionKind.connectionTimeout;
      case DioExceptionType.sendTimeout:
        return ProviderHttpExceptionKind.sendTimeout;
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ProviderHttpExceptionKind.receiveTimeout;
      case DioExceptionType.connectionError:
        return ProviderHttpExceptionKind.other;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return ProviderHttpExceptionKind.other;
    }
  }

  ProviderTransportFailure _failureFor(
    ProviderHttpRequest request, {
    int? statusCode,
  }) {
    // Failures intentionally never include these values, but consume the redactor
    // here so callers can supply their full credential set as a single boundary.
    _redactor.redactUri(request.uri);
    _redactor.redactHeaders(request.headers);
    return ProviderTransportFailure(statusCode: statusCode);
  }
}

/// Minimal Dio binding. All adapter code depends on [ProviderHttpTransport], not Dio.
final class DioProviderHttpClient implements ProviderHttpClient {
  DioProviderHttpClient(this._dio);

  final Dio _dio;

  @override
  Future<ProviderHttpResponse> send(ProviderHttpRequest request) async {
    final response = await _dio.fetch<dynamic>(
      RequestOptions(
        path: request.uri.toString(),
        method: request.method.name.toUpperCase(),
        headers: request.headers,
        data: request.body,
        connectTimeout: request.timeout,
        sendTimeout: request.timeout,
        receiveTimeout: request.timeout,
        validateStatus: (_) => true,
      ),
    );
    return ProviderHttpResponse(
      statusCode: response.statusCode ?? 0,
      headers: response.headers.map.map(
        (name, values) => MapEntry(name, values.join(',')),
      ),
      body: response.data,
    );
  }
}

/// Convenience composition for production while retaining an injectable client seam.
final class DioProviderHttpTransport implements ProviderHttpTransport {
  DioProviderHttpTransport({
    required Dio dio,
    ProviderRetryDelay? retryDelay,
    ProviderRedactor? redactor,
    int maxRetries = 2,
    Duration initialRetryDelay = const Duration(milliseconds: 200),
  }) : _delegate = RetryingProviderHttpTransport(
         client: DioProviderHttpClient(dio),
         retryDelay: retryDelay,
         redactor: redactor,
         maxRetries: maxRetries,
         initialRetryDelay: initialRetryDelay,
       );

  final RetryingProviderHttpTransport _delegate;

  @override
  Future<Result<ProviderHttpResponse>> send(
    ProviderHttpRequest request, {
    CancellationToken? token,
  }) => _delegate.send(request, token: token);
}
