import 'dart:async';

import 'package:flutter_mfa_core/flutter_mfa_core.dart';

/// The displayed code of [totp] at [now].
OtpCode totpCode(Totp totp, DateTime now) => OtpCode(
  value: totp.generate(now),
  remaining: totp.remaining(now),
  progress: totp.progress(now),
  step: totp.stepAt(now),
);

/// A stream of TOTP codes: one when listened to, then one on every whole
/// second of [clock] (FR-FAC-02).
///
/// Step boundaries are whole seconds (periods are whole seconds), so every
/// code change is emitted exactly once, at its boundary. [load] runs once
/// per subscription, so the secret is read from the vault (and any biometric
/// prompt shown) once, not every second. Cancelling stops the timer and
/// drops the [Totp]. Errors from [load] are delivered on the stream, which
/// then closes.
Stream<OtpCode> tickCodes({
  required Clock clock,
  required Future<Totp> Function() load,
}) {
  late final StreamController<OtpCode> controller;
  Timer? timer;
  Totp? totp;
  var cancelled = false;

  void tick() {
    // ignore: avoid_print
    print('tick cancelled=$cancelled');
    final current = totp;
    if (current == null) return;
    controller.add(totpCode(current, clock.now()));
    final ms = clock.now().millisecondsSinceEpoch % 1000;
    timer = Timer(Duration(milliseconds: 1000 - ms), tick);
  }

  controller = StreamController<OtpCode>(
    onListen: () async {
      try {
        final loaded = await load();
        if (cancelled) return;
        totp = loaded;
      } on Object catch (error, stackTrace) {
        controller.addError(error, stackTrace);
        await controller.close();
        return;
      }
      tick();
    },
    onCancel: () {
      cancelled = true;
      timer?.cancel();
      totp = null;
    },
  );
  return controller.stream;
}
