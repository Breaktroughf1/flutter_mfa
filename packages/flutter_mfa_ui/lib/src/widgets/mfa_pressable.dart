import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/mfa_theme.dart';

/// Makes [child] pressable by pointer, keyboard and switch access
/// (FR-UI-08, WCAG 2.1.1 and 2.4.7).
///
/// It is reachable with Tab, activated with Enter or Space, and outlined in
/// the theme's primary colour while it has keyboard focus. Wrap it in a
/// `Semantics` with a label, `button: true` and `onTap` (and no
/// `excludeSemantics`): this widget adds its focus state to that node and
/// hides [child]'s own semantics, so the node is announced once, by its
/// label. A `null` [onPressed] disables it.
class MfaPressable extends StatefulWidget {
  /// Creates a pressable area around [child].
  const MfaPressable({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius,
  });

  /// Called on tap, Enter or Space; `null` disables the control.
  final VoidCallback? onPressed;

  /// The visual content; size it to at least `MfaThemeData.minTapTarget`.
  final Widget child;

  /// Corner radius of the focus outline; defaults to the theme radius.
  final BorderRadius? borderRadius;

  @override
  State<MfaPressable> createState() => _MfaPressableState();
}

class _MfaPressableState extends State<MfaPressable> {
  // Explicit, so keyboard activation works without a WidgetsApp ancestor.
  static const _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    final theme = MfaTheme.of(context);
    return FocusableActionDetector(
      enabled: onPressed != null,
      shortcuts: _shortcuts,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed?.call();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (value) => setState(() => _highlighted = value),
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        // The enclosing Semantics carries the label and tap action.
        excludeFromSemantics: true,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: _highlighted
                ? Border.all(color: theme.primary, width: 2)
                : null,
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(theme.radius),
          ),
          child: ExcludeSemantics(child: widget.child),
        ),
      ),
    );
  }
}
