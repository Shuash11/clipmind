sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppFailure error;
}

abstract base class AppFailure {
  const AppFailure(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

final class ProjectValidationFailure extends AppFailure {
  const ProjectValidationFailure(String message)
    : super('project_validation', message);
}

final class ProjectPersistenceFailure extends AppFailure {
  const ProjectPersistenceFailure(String message)
    : super('project_persistence', message);
}

final class ProjectRecoveryFailure extends AppFailure {
  const ProjectRecoveryFailure(String message)
    : super('project_recovery', message);
}
