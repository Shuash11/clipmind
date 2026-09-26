import 'package:clipmind/core/results/result.dart';

abstract interface class CredentialStore {
  Future<Result<String?>> read(String credentialId);
  Future<Result<void>> write(String credentialId, String secret);
  Future<Result<void>> delete(String credentialId);
}
