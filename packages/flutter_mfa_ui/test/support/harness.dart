import 'package:flutter/widgets.dart';
import 'package:flutter_mfa_ui/flutter_mfa_ui.dart';

/// Hosts [child] the way an app would, without Material: theme, media
/// query, direction and an overlay for menus. Re-pumping with a new child
/// rebuilds it.
Widget host(
  Widget child, {
  MfaThemeData? theme,
  TextDirection direction = TextDirection.ltr,
  MediaQueryData media = const MediaQueryData(),
}) => MediaQuery(
  data: media,
  child: Directionality(
    textDirection: direction,
    child: MfaTheme(data: theme ?? MfaThemeData.light(), child: _Host(child)),
  ),
);

class _Host extends StatefulWidget {
  const _Host(this.child);

  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => Center(child: widget.child),
  );

  @override
  void didUpdateWidget(_Host oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
