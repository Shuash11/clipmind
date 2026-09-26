import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/policy/provider_url_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('https is accepted and loopback or RFC1918 http warns', () {
    expect(
      ProviderUrlPolicy.validate(Uri.parse('https://api.example.com/v1')),
      isA<Success<Object>>(),
    );
    for (final host in <String>[
      '127.0.0.0',
      '127.255.255.255',
      '10.0.0.0',
      '10.255.255.255',
      '172.16.0.1',
      '172.31.255.255',
      '192.168.0.0',
      '192.168.255.255',
      'localhost',
      '[::1]',
    ]) {
      final result =
          ProviderUrlPolicy.validate(Uri.parse('http://$host:11434'))
              as Success<ProviderUrlValidation>;
      expect(
        result.value.warnings,
        contains(ProviderUrlWarning.insecureLocalHttp),
      );
    }
  });

  test('immediate private-range boundaries and lookalikes are rejected', () {
    for (final value in <String>[
      'http://8.8.8.8',
      'http://126.255.255.255',
      'http://128.0.0.0',
      'http://9.255.255.255',
      'http://11.0.0.0',
      'http://172.15.255.255',
      'http://172.32.0.1',
      'http://192.167.255.255',
      'http://192.169.0.0',
      'http://localhost.evil.test',
      'http://localhost.localdomain',
      'http://[::2]',
      'ftp://localhost',
      'https://user:secret@example.test',
      'https://example.test/#fragment',
    ]) {
      expect(ProviderUrlPolicy.parseAndValidate(value), isA<Failure<Object>>());
    }
  });
}
