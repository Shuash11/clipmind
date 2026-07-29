import 'dart:async';

final class CancellationToken {
  CancellationToken._(this._isCancelled, this._whenCancelled);
  final bool Function() _isCancelled;
  final Future<void> _whenCancelled;

  bool get isCancelled => _isCancelled();
  Future<void> get whenCancelled => _whenCancelled;

  void throwIfCancelled() {
    if (isCancelled) throw const CancelledException();
  }
}

final class CancellationController {
  bool _cancelled = false;
  final Completer<void> _completer = Completer<void>();
  late final CancellationToken token = CancellationToken._(
    () => _cancelled,
    _completer.future,
  );

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _completer.complete();
  }
}

final class CancelledException implements Exception {
  const CancelledException();
}
