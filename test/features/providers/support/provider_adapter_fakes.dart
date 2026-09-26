import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/contracts/credential_store.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';

final class RecordingTransport implements ProviderHttpTransport {
  RecordingTransport(this.responses);
  final List<Result<ProviderHttpResponse>> responses;
  final List<ProviderHttpRequest> requests = <ProviderHttpRequest>[];

  @override
  Future<Result<ProviderHttpResponse>> send(
    ProviderHttpRequest request, {
    CancellationToken? token,
  }) async {
    requests.add(request);
    return responses.removeAt(0);
  }
}

final class MemoryCredentials implements CredentialStore {
  MemoryCredentials([Map<String, String> values = const <String, String>{}])
    : values = Map<String, String>.from(values);
  final Map<String, String> values;

  @override
  Future<Result<void>> delete(String credentialId) async {
    values.remove(credentialId);
    return const Success<void>(null);
  }

  @override
  Future<Result<String?>> read(String credentialId) async =>
      Success<String?>(values[credentialId]);

  @override
  Future<Result<void>> write(String credentialId, String secret) async {
    values[credentialId] = secret;
    return const Success<void>(null);
  }
}

ProviderProfile testProfile(
  String providerId, {
  List<String> manual = const <String>[],
}) => ProviderProfile(
  id: 'profile',
  providerId: providerId,
  displayName: providerId,
  endpoint: Uri.parse('https://example.test/prefix/v1'),
  manualModelIds: manual,
);
