import 'dart:async';

/// A non-reentrant asynchronous lock that runs critical sections one at a
/// time, in the order [protect] was called.
///
/// Used to serialise read-modify-write cycles on shared state, such as the
/// vault's account index, so that concurrent writers cannot lose updates. It
/// only coordinates code within one isolate; it does not protect against
/// other isolates or processes. Calling [protect] from inside a protected
/// section deadlocks.
final class AsyncMutex {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  /// Whether a critical section is running or waiting to run.
  bool get isLocked => _pending > 0;

  /// Runs [action] once every earlier critical section has finished and
  /// returns its result.
  ///
  /// The lock is released whether [action] completes or throws (synchronously
  /// or asynchronously); errors propagate to the caller.
  Future<T> protect<T>(FutureOr<T> Function() action) {
    final previous = _tail;
    final released = Completer<void>();
    _tail = released.future;
    _pending++;
    return previous.then((_) => action()).whenComplete(() {
      _pending--;
      released.complete();
    });
  }
}
