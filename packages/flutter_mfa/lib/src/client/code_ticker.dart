import 'dart:async';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';

/// The displayed code of [totp] at [now].
OtpCode totpCode(Totp totp, DateTime now) => OtpCode(
  value: totp.generate(now),
  remaining: totp.remaining(now),
  progress: totp.progress(now),
  step: totp.stepAt(now),
);

/// Whole-second ticks of [clock], shared by every code stream of a client
/// (02_ARCHITECTURE §8).
///
/// One timer runs while anything listens, however many codes are on screen.
/// It is re-armed for the next whole second after each tick, so it never
/// drifts; step boundaries are whole seconds (periods are whole seconds),
/// so every code change falls on a tick.
final class CodeTicker {
  /// Creates a ticker over [clock]; no timer runs until someone listens.
  CodeTicker(this.clock);

  /// Time source for the ticks.
  final Clock clock;

  late final _ticks = StreamController<DateTime>.broadcast(
    onListen: _schedule,
    onCancel: _stop,
  );
  Timer? _timer;

  /// The time at each whole second; done once the ticker is closed.
  Stream<DateTime> get ticks => _ticks.stream;

  void _schedule() {
    _timer?.cancel();
    final ms = clock.now().millisecondsSinceEpoch % 1000;
    _timer = Timer(Duration(milliseconds: 1000 - ms), _tick);
  }

  void _tick() {
    _ticks.add(clock.now());
    if (_ticks.hasListener) _schedule();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Stops the timer and ends [ticks].
  Future<void> close() {
    _stop();
    return _ticks.close();
  }
}

/// A stream of TOTP codes: one when listened to, then one on every tick of
/// [ticker] (FR-FAC-02).
///
/// [load] runs once per subscription, so the secret is read from the vault
/// (and any biometric prompt shown) once, not every second. Cancelling
/// stops listening to the ticker and drops the [Totp]. Errors from [load]
/// or from generating a code (for example a clock before T0) are delivered
/// on the stream, which then closes; it also closes when the ticker does.
Stream<OtpCode> tickCodes({
  required CodeTicker ticker,
  required Future<Totp> Function() load,
}) {
  late final StreamController<OtpCode> controller;
  StreamSubscription<DateTime>? ticks;
  var cancelled = false;

  void stopTicks() {
    unawaited(ticks?.cancel());
    ticks = null;
  }

  void fail(Object error, StackTrace stackTrace) {
    stopTicks();
    controller.addError(error, stackTrace);
    unawaited(controller.close());
  }

  void emit(Totp totp, DateTime now) {
    try {
      controller.add(totpCode(totp, now));
    } on Object catch (error, stackTrace) {
      fail(error, stackTrace);
    }
  }

  controller = StreamController<OtpCode>(
    onListen: () async {
      final Totp totp;
      try {
        totp = await load();
      } on Object catch (error, stackTrace) {
        fail(error, stackTrace);
        return;
      }
      if (cancelled) return;
      emit(totp, ticker.clock.now());
      if (controller.isClosed) return;
      ticks = ticker.ticks.listen(
        (now) => emit(totp, now),
        onDone: () => unawaited(controller.close()),
      );
    },
    onCancel: () {
      cancelled = true;
      stopTicks();
    },
  );
  return controller.stream;
}
