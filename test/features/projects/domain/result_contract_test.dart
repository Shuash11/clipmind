import 'package:clipmind/core/results/result.dart';
import 'package:flutter_test/flutter_test.dart';

final class ExternalProjectFailure extends AppFailure {
  const ExternalProjectFailure()
    : super('external_project_failure', 'from another library');
}

void main() {
  test('AppFailure is extensible from a different Dart library', () {
    const failure = ExternalProjectFailure();
    expect(failure.code, 'external_project_failure');
    expect(failure.message, 'from another library');
  });

  test('Result exposes typed success and typed failure values', () {
    const Result<int> success = Success<int>(7);
    const Result<int> failure = Failure<int>(ExternalProjectFailure());
    expect((success as Success<int>).value, 7);
    expect((failure as Failure<int>).error, isA<ExternalProjectFailure>());
  });
}
