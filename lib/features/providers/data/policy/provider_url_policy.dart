import 'package:clipmind/core/results/result.dart';
import 'package:clipmind/features/providers/domain/provider_failures.dart';

enum ProviderUrlWarning { insecureLocalHttp }

final class ProviderUrlValidation {
  ProviderUrlValidation(this.uri, Iterable<ProviderUrlWarning> warnings)
    : warnings = List.unmodifiable(List<ProviderUrlWarning>.from(warnings));

  final Uri uri;
  final List<ProviderUrlWarning> warnings;
}

final class ProviderUrlPolicy {
  ProviderUrlPolicy._();

  static Result<ProviderUrlValidation> parseAndValidate(String value) {
    try {
      return validate(Uri.parse(value));
    } on FormatException {
      return const Failure<ProviderUrlValidation>(
        ProviderValidationFailure('The provider endpoint is invalid.'),
      );
    }
  }

  static Result<ProviderUrlValidation> validate(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      return _invalid();
    }
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.hasFragment) {
      return _invalid();
    }
    if (scheme == 'https') {
      return Success<ProviderUrlValidation>(
        ProviderUrlValidation(uri, const <ProviderUrlWarning>[]),
      );
    }
    if (!_isSafeHttpHost(uri.host)) return _invalid();
    return Success<ProviderUrlValidation>(
      ProviderUrlValidation(uri, const <ProviderUrlWarning>[
        ProviderUrlWarning.insecureLocalHttp,
      ]),
    );
  }

  static Failure<ProviderUrlValidation> _invalid() =>
      const Failure<ProviderUrlValidation>(
        ProviderValidationFailure('The provider endpoint is not allowed.'),
      );

  static bool _isSafeHttpHost(String host) {
    final lowercaseHost = host.toLowerCase();
    if (lowercaseHost == 'localhost' || host == '::1') {
      return true;
    }
    final segments = host.split('.');
    if (segments.length != 4) return false;
    final octets = <int>[];
    for (final segment in segments) {
      final value = int.tryParse(segment);
      if (value == null || value < 0 || value > 255 || '$value' != segment) {
        return false;
      }
      octets.add(value);
    }
    return octets[0] == 127 ||
        octets[0] == 10 ||
        (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
        (octets[0] == 192 && octets[1] == 168);
  }
}
