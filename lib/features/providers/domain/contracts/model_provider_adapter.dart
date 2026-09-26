import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/domain/entities/model_descriptor.dart';
import 'package:clipmind/features/providers/domain/entities/provider_connection_result.dart';
import 'package:clipmind/features/providers/domain/entities/provider_profile.dart';
import 'package:clipmind/features/providers/domain/requests/model_request.dart';
import 'package:clipmind/features/providers/domain/responses/model_response.dart';

abstract interface class ModelProviderAdapter {
  Future<Result<List<ModelDescriptor>>> discoverModels(
    ProviderProfile profile,
    CancellationToken token,
  );

  Future<Result<ModelResponse>> complete(
    ModelRequest request,
    ProviderProfile profile,
    CancellationToken token,
  );

  Future<Result<ProviderConnectionResult>> testConnection(
    ProviderProfile profile,
    CancellationToken token,
  );
}
