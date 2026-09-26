import 'package:clipmind/features/providers/data/policy/provider_endpoint_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'resolver preserves provider prefixes and cleans base query and fragment',
    () {
      for (final base in <String>[
        'https://example.test/v1?token=secret#part',
        'https://example.test/api/v1',
        'https://example.test/openai/v1',
        'https://example.test/inference/v1',
      ]) {
        final result = ProviderEndpointResolver.resolve(
          Uri.parse(base),
          '/models',
        );
        expect(result.path.endsWith('/models'), isTrue);
        expect(result.hasQuery, isFalse);
        expect(result.hasFragment, isFalse);
      }
      expect(
        ProviderEndpointResolver.resolve(
          Uri.parse('https://example.test/api/v1'),
          '/models',
        ).toString(),
        'https://example.test/api/v1/models',
      );
    },
  );
}
