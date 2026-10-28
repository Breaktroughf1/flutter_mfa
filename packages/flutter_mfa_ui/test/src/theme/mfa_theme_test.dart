import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<MfaThemeData?> capture(
    WidgetTester tester,
    Widget Function(Widget probe) wrap, {
    bool maybe = false,
  }) async {
    MfaThemeData? seen;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            seen = maybe ? MfaTheme.maybeOf(context) : MfaTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return seen;
  }

  testWidgets('of returns the nearest theme', (tester) async {
    final custom = MfaThemeData.light().copyWith(radius: 3);
    expect(
      await capture(tester, (probe) => MfaTheme(data: custom, child: probe)),
      custom,
    );
  });

  testWidgets('without a theme, of follows the platform brightness', (
    tester,
  ) async {
    expect(
      await capture(
        tester,
        (probe) => MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: probe,
        ),
      ),
      MfaThemeData.dark(),
    );
    expect(await capture(tester, (probe) => probe), MfaThemeData.light());
    expect(await capture(tester, (probe) => probe, maybe: true), isNull);
  });

  testWidgets('dependents rebuild only when the data changes', (tester) async {
    _Probe.builds = 0;
    Widget app(MfaThemeData data) =>
        MfaTheme(data: data, child: const _Probe());
    await tester.pumpWidget(app(MfaThemeData.light()));
    expect(_Probe.builds, 1);
    await tester.pumpWidget(app(MfaThemeData.light()));
    expect(_Probe.builds, 1, reason: 'equal data does not notify');
    await tester.pumpWidget(app(MfaThemeData.dark()));
    expect(_Probe.builds, 2);
  });
}

class _Probe extends StatelessWidget {
  const _Probe();

  static var builds = 0;

  @override
  Widget build(BuildContext context) {
    MfaTheme.of(context);
    builds++;
    return const SizedBox();
  }
}
