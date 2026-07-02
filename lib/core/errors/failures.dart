sealed class AppFailure {
  final String message;
  final Object? cause;
  const AppFailure(this.message, [this.cause]);
}

class Stage1Failure extends AppFailure {
  const Stage1Failure(super.message, [super.cause]);
}

class Stage4Failure extends AppFailure {
  const Stage4Failure(super.message, [super.cause]);
}

class ParseFailure extends AppFailure {
  const ParseFailure(super.message, [super.cause]);
}

class FfmpegFailure extends AppFailure {
  final int? exitCode;
  final String? stderr;
  const FfmpegFailure(super.message, [this.exitCode, this.stderr, super.cause]);
}

class ProviderFailure extends AppFailure {
  final String providerId;
  const ProviderFailure(this.providerId, super.message, [super.cause]);
}

class ImportFailure extends AppFailure {
  const ImportFailure(super.message, [super.cause]);
}

class PersistenceFailure extends AppFailure {
  const PersistenceFailure(super.message, [super.cause]);
}
