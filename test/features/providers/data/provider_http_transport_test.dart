import 'dart:async';

import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/data/security/provider_redactor.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderHttpRequest request({
    ProviderHttpMethod method = ProviderHttpMethod.get,
  }) => ProviderHttpRequest(
    method: method,
    uri: Uri.parse('https://example.test/v1/models'),
  );

  test(
    'discovery GET retries transient statuses up to a maximum of three attempts',
    () async {
      final client = _FakeClient(<Object>[
        ProviderHttpResponse(statusCode: 503),
        ProviderHttpResponse(statusCode: 429),
        ProviderHttpResponse(
          statusCode: 200,
          body: <String, Object?>{'data': <Object>[]},
        ),
      ]);
      final transport = RetryingProviderHttpTransport(
        client: client,
        retryDelay: (_) async {},
      );

      final result = await transport.send(request());

      expect(result, isA<Success<ProviderHttpResponse>>());
      expect(client.attempts, 3);
    },
  );

  test('nontransient and non-idempotent failures do not retry', () async {
    final forbiddenClient = _FakeClient(<Object>[
      ProviderHttpResponse(statusCode: 401),
    ]);
    final postClient = _FakeClient(<Object>[
      ProviderHttpResponse(statusCode: 503),
    ]);
    final transport = RetryingProviderHttpTransport(
      client: forbiddenClient,
      retryDelay: (_) async {},
    );

    final forbidden = await transport.send(request());
    final post = await RetryingProviderHttpTransport(
      client: postClient,
      retryDelay: (_) async {},
    ).send(request(method: ProviderHttpMethod.post));

    expect(forbidden, isA<Failure<ProviderHttpResponse>>());
    expect(post, isA<Failure<ProviderHttpResponse>>());
    expect(forbiddenClient.attempts, 1);
    expect(postClient.attempts, 1);
  });

  test('an idempotency key explicitly permits retrying a POST', () async {
    final client = _FakeClient(<Object>[
      ProviderHttpResponse(statusCode: 503),
      ProviderHttpResponse(statusCode: 200),
    ]);
    final result =
        await RetryingProviderHttpTransport(
          client: client,
          retryDelay: (_) async {},
        ).send(
          ProviderHttpRequest(
            method: ProviderHttpMethod.post,
            uri: Uri.parse('https://example.test/v1/completions'),
            idempotencyKey: 'request-1',
          ),
        );

    expect(result, isA<Success<ProviderHttpResponse>>());
    expect(client.attempts, 2);
  });

  test(
    'transient connection exceptions retry but stop after three attempts',
    () async {
      final client = _FakeClient(<Object>[
        const ProviderHttpException(
          ProviderHttpExceptionKind.connectionTimeout,
        ),
        const ProviderHttpException(ProviderHttpExceptionKind.connectionReset),
        const ProviderHttpException(ProviderHttpExceptionKind.receiveTimeout),
      ]);
      final result = await RetryingProviderHttpTransport(
        client: client,
        retryDelay: (_) async {},
      ).send(request());

      expect(result, isA<Failure<ProviderHttpResponse>>());
      expect(client.attempts, 3);
    },
  );

  test('a pre-cancelled request never starts a transport attempt', () async {
    final controller = CancellationController()..cancel();
    final client = _FakeClient(<Object>[]);

    final result = await RetryingProviderHttpTransport(
      client: client,
      retryDelay: (_) async {},
    ).send(request(), token: controller.token);

    expect(result, isA<Failure<ProviderHttpResponse>>());
    expect(
      (result as Failure<ProviderHttpResponse>).error,
      isA<ProviderCancellationFailure>(),
    );
    expect(client.attempts, 0);
  });

  test('transport failures never expose request credentials', () async {
    final client = _FakeClient(<Object>[ProviderHttpResponse(statusCode: 401)]);
    final result =
        await RetryingProviderHttpTransport(
          client: client,
          retryDelay: (_) async {},
          redactor: ProviderRedactor(
            secretValues: const <String>['raw-api-key'],
          ),
        ).send(
          ProviderHttpRequest(
            method: ProviderHttpMethod.get,
            uri: Uri.parse('https://example.test/v1/models?apiKey=raw-api-key'),
            headers: const <String, String>{
              'Authorization': 'Bearer raw-api-key',
            },
          ),
        );

    final error = (result as Failure<ProviderHttpResponse>).error.toString();
    expect(error, isNot(contains('raw-api-key')));
    expect(error, isNot(contains('Bearer')));
  });

  test('structured request and response bodies are defensively copied', () {
    final requestBody = <String, Object?>{
      'messages': <Object?>[
        <String, Object?>{'content': 'before'},
      ],
    };
    final responseBody = <String, Object?>{
      'choices': <Object?>[
        <String, Object?>{'text': 'before'},
      ],
    };
    final requestWithBody = ProviderHttpRequest(
      method: ProviderHttpMethod.post,
      uri: Uri.parse('https://example.test/v1/completions'),
      body: requestBody,
    );
    final responseWithBody = ProviderHttpResponse(
      statusCode: 200,
      body: responseBody,
    );

    requestBody.clear();
    responseBody.clear();
    final requestMap = requestWithBody.body! as Map<Object?, Object?>;
    final responseMap = responseWithBody.body! as Map<Object?, Object?>;

    expect(requestMap, contains('messages'));
    expect(responseMap, contains('choices'));
    final requestMessages = requestMap['messages']! as List<Object?>;
    final responseChoices = responseMap['choices']! as List<Object?>;
    final requestMessage = requestMessages.single as Map<Object?, Object?>;
    final responseChoice = responseChoices.single as Map<Object?, Object?>;
    expect(() => requestMap['new'] = true, throwsUnsupportedError);
    expect(() => responseMap['new'] = true, throwsUnsupportedError);
    expect(() => requestMessages.add('after'), throwsUnsupportedError);
    expect(() => responseChoices.add('after'), throwsUnsupportedError);
    expect(() => requestMessage['content'] = 'after', throwsUnsupportedError);
    expect(() => responseChoice['text'] = 'after', throwsUnsupportedError);
  });

  test(
    'cancellation races in-flight work and returns a typed safe failure',
    () async {
      final pending = Completer<ProviderHttpResponse>();
      final client = _FakeClient(<Object>[pending.future]);
      final controller = CancellationController();
      final operation = RetryingProviderHttpTransport(
        client: client,
        retryDelay: (_) async {},
      ).send(request(), token: controller.token);

      controller.cancel();
      final result = await operation;

      expect(result, isA<Failure<ProviderHttpResponse>>());
      expect(
        (result as Failure<ProviderHttpResponse>).error,
        isA<ProviderCancellationFailure>(),
      );
    },
  );

  test(
    'redactor removes credentials from strings, query values, and headers',
    () {
      final redactor = ProviderRedactor(
        secretValues: const <String>['raw-api-key', 'Bearer hidden-token'],
        sensitiveHeaderNames: const <String>['x-custom-secret'],
      );
      final text = redactor.redact(
        'Authorization: Bearer hidden-token '
        'https://alice:raw-api-key@example.test?apiKey=raw-api-key',
      );
      final headers = redactor.redactHeaders(<String, String>{
        'X-Custom-Secret': 'raw-api-key',
      });

      expect(text, isNot(contains('raw-api-key')));
      expect(text, isNot(contains('hidden-token')));
      expect(text, isNot(contains('alice:')));
      expect(headers['X-Custom-Secret'], '[REDACTED]');
    },
  );
}

final class _FakeClient implements ProviderHttpClient {
  _FakeClient(this._results);

  final List<Object> _results;
  int attempts = 0;

  @override
  Future<ProviderHttpResponse> send(ProviderHttpRequest request) {
    attempts += 1;
    final next = _results.removeAt(0);
    if (next is Future<ProviderHttpResponse>) return next;
    if (next is ProviderHttpResponse) {
      return Future<ProviderHttpResponse>.value(next);
    }
    throw next;
  }
}
