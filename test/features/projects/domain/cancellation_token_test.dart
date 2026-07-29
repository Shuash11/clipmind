import 'package:clipmind/core/async/cancellation_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cancellation is idempotent and signals observers exactly once',
    () async {
      final controller = CancellationController();
      var signals = 0;
      controller.token.whenCancelled.then((Object? _) => signals++);
      controller.cancel();
      controller.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(controller.token.isCancelled, isTrue);
      expect(signals, 1);
    },
  );

  test('cancelled token rejects further work', () {
    final controller = CancellationController()..cancel();
    expect(
      controller.token.throwIfCancelled,
      throwsA(isA<CancelledException>()),
    );
  });
}
