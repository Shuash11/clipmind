import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/adapters/anthropic_adapter.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/model_tool_definition.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/provider_adapter_fakes.dart';

const String _apiKeyCredential = 'clipmind_provider_profile_api_key';

AnthropicAdapter _adapter(
  RecordingTransport transport, {
  Map<String, String> credentials = const <String, String>{
    _apiKeyCredential: 'secret',
  },
}) => AnthropicAdapter(
  transport: transport,
  credentials: MemoryCredentials(credentials),
);

Success<ProviderHttpResponse> _page(Object? body) =>
    Success<ProviderHttpResponse>(
      ProviderHttpResponse(statusCode: 200, body: body),
    );

Map<String, Object?> _modelPage({
  required String id,
  bool hasMore = false,
  String? lastId,
}) => <String, Object?>{
  'data': <Object?>[
    <String, Object?>{'id': id, 'type': 'model'},
  ],
  'has_more': hasMore,
  'last_id': ?lastId,
};

void main() {
  test('discovers models from the documented endpoint with headers', () async {
    final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
      _page(<String, Object?>{
        'data': <Object?>[
          <String, Object?>{
            'id': 'claude-sonnet-4',
            'display_name': 'Claude Sonnet 4',
            'type': 'model',
          },
          <String, Object?>{'id': 'claude-haiku-3-5', 'type': 'model'},
        ],
        'has_more': false,
      }),
    ]);
    final adapter = _adapter(transport);
    final profile = testProfile('anthropic');

    final discovered = await adapter.discoverModels(
      profile,
      CancellationController().token,
    );

    final models = (discovered as Success<List<ModelDescriptor>>).value;
    expect(models.map((model) => model.id), <String>[
      'claude-sonnet-4',
      'claude-haiku-3-5',
    ]);
    expect(models.first.displayName, 'Claude Sonnet 4');
    expect(models.last.displayName, 'claude-haiku-3-5');
    expect(models.every((model) => model.providerId == 'anthropic'), isTrue);
    final request = transport.requests.single;
    expect(request.method, ProviderHttpMethod.get);
    expect(request.uri.path, '/prefix/v1/models');
    expect(request.uri.queryParameters, <String, String>{'limit': '1000'});
    expect(request.headers['x-api-key'], 'secret');
    expect(request.headers['anthropic-version'], '2023-06-01');
    expect(request.timeout, profile.timeout);
    expect(request.isDiscovery, isTrue);
  });

  test('paginates on has_more with the last id as the cursor', () async {
    final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
      _page(_modelPage(id: 'claude-a', hasMore: true, lastId: 'claude-a')),
      _page(_modelPage(id: 'claude-b')),
    ]);
    final adapter = _adapter(transport);

    final discovered = await adapter.discoverModels(
      testProfile('anthropic'),
      CancellationController().token,
    );

    expect(
      (discovered as Success<List<ModelDescriptor>>).value.map(
        (model) => model.id,
      ),
      <String>['claude-a', 'claude-b'],
    );
    expect(transport.requests, hasLength(2));
    expect(transport.requests.first.uri.queryParameters, <String, String>{
      'limit': '1000',
    });
    expect(transport.requests.last.uri.queryParameters, <String, String>{
      'limit': '1000',
      'after_id': 'claude-a',
    });
    expect(transport.requests.last.headers['x-api-key'], 'secret');
    expect(transport.requests.last.headers['anthropic-version'], '2023-06-01');
  });

  test('stops paginating after the bounded page limit', () async {
    final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
      for (var page = 0; page < 6; page++)
        _page(
          _modelPage(id: 'claude-$page', hasMore: true, lastId: 'claude-$page'),
        ),
    ]);
    final adapter = _adapter(transport);

    final discovered = await adapter.discoverModels(
      testProfile('anthropic'),
      CancellationController().token,
    );

    expect((discovered as Success<List<ModelDescriptor>>).value, hasLength(5));
    expect(transport.requests, hasLength(5));
  });

  test('surfaces transport failures without a manual fallback', () async {
    final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
      const Failure<ProviderHttpResponse>(
        ProviderTransportFailure(statusCode: 503),
      ),
    ]);
    final adapter = _adapter(transport);

    final discovered = await adapter.discoverModels(
      testProfile('anthropic'),
      CancellationController().token,
    );

    expect(discovered, isA<Failure<List<ModelDescriptor>>>());
    expect(
      (discovered as Failure<List<ModelDescriptor>>).error,
      isA<ProviderTransportFailure>(),
    );
  });

  test(
    'rejects malformed discovery bodies with a validation failure',
    () async {
      final bodies = <Object?>[
        <String, Object?>{'data': 'not-a-list'},
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{'display_name': 'missing id'},
          ],
        },
        <String, Object?>{'data': <Object?>[], 'has_more': true},
      ];
      for (final body in bodies) {
        final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
          _page(body),
        ]);
        final adapter = _adapter(transport);

        final discovered = await adapter.discoverModels(
          testProfile('anthropic'),
          CancellationController().token,
        );

        expect(discovered, isA<Failure<List<ModelDescriptor>>>());
        expect(
          (discovered as Failure<List<ModelDescriptor>>).error,
          isA<ProviderValidationFailure>(),
        );
      }
    },
  );

  test(
    'discovery requires credentials and issues no request without a key',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[]);
      final adapter = _adapter(
        transport,
        credentials: const <String, String>{},
      );

      final discovered = await adapter.discoverModels(
        testProfile('anthropic'),
        CancellationController().token,
      );

      expect(discovered, isA<Failure<List<ModelDescriptor>>>());
      expect(
        (discovered as Failure<List<ModelDescriptor>>).error,
        isA<ProviderCredentialFailure>(),
      );
      expect(transport.requests, isEmpty);
    },
  );

  test('completes with content blocks and tool definitions', () async {
    final transport = RecordingTransport(<Result<ProviderHttpResponse>>[
      Success<ProviderHttpResponse>(
        ProviderHttpResponse(
          statusCode: 200,
          body: <String, Object?>{
            'content': <Object?>[
              <String, Object?>{'type': 'text', 'text': 'hello'},
              <String, Object?>{
                'type': 'tool_use',
                'id': 'use-1',
                'name': 'edit',
                'input': <String, Object?>{'amount': 0},
              },
            ],
          },
        ),
      ),
    ]);
    final adapter = _adapter(transport);
    final profile = testProfile('anthropic', manual: <String>['claude']);

    final completed = await adapter.complete(
      ModelRequest(
        providerId: 'anthropic',
        modelId: 'claude',
        messages: <Map<String, Object?>>[
          <String, Object?>{'role': 'user', 'content': 'hi'},
        ],
        tools: <ModelToolDefinition>[
          ModelToolDefinition(
            name: 'edit',
            description: 'edit',
            inputSchema: <String, Object?>{'type': 'object'},
          ),
        ],
      ),
      profile,
      CancellationController().token,
    );

    expect(transport.requests.single.uri.path, '/prefix/v1/messages');
    expect(transport.requests.single.method, ProviderHttpMethod.post);
    expect(transport.requests.single.headers['x-api-key'], 'secret');
    expect(
      transport.requests.single.headers['anthropic-version'],
      '2023-06-01',
    );
    expect(transport.requests.single.timeout, profile.timeout);
    final body = transport.requests.single.body! as Map<Object?, Object?>;
    final tool =
        (body['tools']! as List<Object?>).single as Map<Object?, Object?>;
    expect(tool['input_schema'], <String, Object?>{'type': 'object'});
    final response = (completed as Success<ModelResponse>).value;
    expect(response.content, 'hello');
    expect(response.toolCalls.single.arguments['amount'], 0);
  });

  test(
    'connection testing requires a manual model and cancellation does no work',
    () async {
      final transport = RecordingTransport(<Result<ProviderHttpResponse>>[]);
      final adapter = _adapter(
        transport,
        credentials: const <String, String>{},
      );
      final cancelled = CancellationController()..cancel();
      final discovered = await adapter.discoverModels(
        testProfile('anthropic'),
        cancelled.token,
      );
      expect(discovered, isA<Failure<List<ModelDescriptor>>>());
      expect(
        (discovered as Failure<List<ModelDescriptor>>).error,
        isA<ProviderCancellationFailure>(),
      );
      final connection = await adapter.testConnection(
        testProfile('anthropic'),
        CancellationController().token,
      );
      expect((connection as Failure).error, isA<ProviderValidationFailure>());
      expect(transport.requests, isEmpty);
    },
  );
}
