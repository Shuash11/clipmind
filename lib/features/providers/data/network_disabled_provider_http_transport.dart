import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/data/http/provider_http_transport.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';

/// A composition-time guard that prevents any provider HTTP client invocation.
final class NetworkDisabledProviderHttpTransport
    implements ProviderHttpTransport {
  const NetworkDisabledProviderHttpTransport();

  @override
  Future<Result<ProviderHttpResponse>> send(
    ProviderHttpRequest request, {
    CancellationToken? token,
  }) async {
    if (token?.isCancelled ?? false) {
      return const Failure<ProviderHttpResponse>(ProviderCancellationFailure());
    }
    return const Failure<ProviderHttpResponse>(
      ProviderNetworkDisabledFailure(),
    );
  }
}
