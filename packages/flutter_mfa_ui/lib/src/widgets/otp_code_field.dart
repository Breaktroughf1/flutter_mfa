import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../l10n/mfa_strings.dart';
import '../theme/mfa_theme.dart';
import '../theme/mfa_theme_data.dart';
import 'mfa_pressable.dart';

/// Entry field for a 6–8 digit one-time code (FR-UI-01).
///
/// One text field for assistive technology (a single screen-reader focus,
/// announced as a text field) drawn as one box per digit. Only digits are
/// accepted, so pasting `123 456` or `Code: 123456` fills every box; the
/// platform's one-time-code autofill (SMS on mobile, `one-time-code` on the
/// web) is enabled, and the keyboard is numeric. Codes are always laid out
/// left to right, also in right-to-left locales.
///
/// [onCompleted] fires once each time the field becomes full, whether the
/// user typed, pasted or autofilled the code or the [controller] was set.
///
/// Protects against: secrets in logs (the code is never logged), shoulder
/// surfing when [obscure] is set. Does not rate-limit attempts: verify codes
/// with a `TotpVerifier` and an `AttemptLimiter`.
class OtpCodeField extends StatefulWidget {
  /// Creates a code field with [length] boxes (6, 7 or 8).
  const OtpCodeField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.controller,
    this.errorText,
    this.autofocus = false,
    this.obscure = false,
    this.semanticLabel,
  }) : assert(length >= 6 && length <= 8, 'length must be 6, 7 or 8');

  /// Number of digits.
  final int length;

  /// Called with the code each time the field becomes full.
  final ValueChanged<String> onCompleted;

  /// Called with the digits entered so far whenever they change.
  final ValueChanged<String>? onChanged;

  /// Controls the text; the field creates its own when `null`.
  final TextEditingController? controller;

  /// An error message shown under the boxes and announced to screen readers;
  /// `null` for no error.
  final String? errorText;

  /// Whether the field requests focus when first shown.
  final bool autofocus;

  /// Whether digits are drawn as dots and hidden from assistive technology.
  final bool obscure;

  /// The accessible label; defaults to the localized "One-time code".
  final String? semanticLabel;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final _editableTextKey = GlobalKey<EditableTextState>();
  final _focusNode = FocusNode(debugLabel: 'OtpCodeField');
  late final _gestureBuilder = TextSelectionGestureDetectorBuilder(
    delegate: this,
  );
  TextEditingController? _ownController;
  String _lastText = '';
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);
  bool _wasComplete = false;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  GlobalKey<EditableTextState> get editableTextKey => _editableTextKey;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  void initState() {
    super.initState();
    _attach();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onChanged);
      if (widget.controller != null) {
        _ownController?.dispose();
        _ownController = null;
      }
      _attach();
    }
    if (oldWidget.length != widget.length) {
      if (_controller.text.length > widget.length) {
        final truncated = _controller.text.substring(0, widget.length);
        _lastText = truncated;
        _controller.value = TextEditingValue(
          text: truncated,
          selection: TextSelection.collapsed(offset: truncated.length),
        );
        _lastSelection = _controller.selection;
      }
      _wasComplete = _controller.text.length == widget.length;
    }
  }

  void _attach() {
    _controller.addListener(_onChanged);
    _lastText = _controller.text;
    _lastSelection = _controller.selection;
    _wasComplete = _lastText.length == widget.length;
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _ownController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() => setState(() {});

  void _requestKeyboard() {
    if (!_controller.selection.isValid) {
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
    _editableTextKey.currentState?.requestKeyboard();
  }

  void _onChanged() {
    final text = _controller.text;
    final selection = _controller.selection;
    if (text == _lastText) {
      if (selection != _lastSelection) {
        _lastSelection = selection;
        setState(() {});
      }
      return;
    }
    _lastText = text;
    _lastSelection = selection;
    setState(() {});
    widget.onChanged?.call(text);
    final complete = text.length == widget.length;
    if (complete && !_wasComplete) widget.onCompleted(text);
    _wasComplete = complete;
  }

  @override
  Widget build(BuildContext context) {
    final theme = MfaTheme.of(context);
    final strings = mfaStrings(context);
    final error = widget.errorText;
    final text = _controller.text;
    final field = EditableText(
      key: _editableTextKey,
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      obscureText: widget.obscure,
      // The boxes draw the digits; the editable text is transparent.
      style: theme.codeTextStyle.copyWith(color: const Color(0x00000000)),
      cursorColor: const Color(0x00000000),
      backgroundCursorColor: const Color(0x00000000),
      selectionColor: const Color(0x00000000),
      showCursor: false,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      inputFormatters: [_OtpInputFormatter(widget.length)],
      rendererIgnoresPointer: true,
      contextMenuBuilder: _buildContextMenu,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          container: true,
          // Without it the web announces the field as disabled and skips
          // it on Tab.
          enabled: true,
          label: widget.semanticLabel ?? strings.otpCodeFieldLabel,
          hint: strings.otpCodeFieldHint(widget.length),
          // Screen readers activate and focus the field through these, as
          // Material's TextField does.
          onTap: _requestKeyboard,
          onFocus: _requestKeyboard,
          child: _gestureBuilder.buildGestureDetector(
            behavior: HitTestBehavior.translucent,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ExcludeSemantics(child: _boxes(theme, text)),
                  Positioned.fill(child: field),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: theme.bodyTextStyle.copyWith(color: theme.error),
              ),
            ),
          ),
      ],
    );
  }

  Widget _boxes(MfaThemeData theme, String text) {
    final hasError = widget.errorText != null;
    final focused = _focusNode.hasFocus;
    final activeIndex = _controller.selection.isValid
        ? _controller.selection.baseOffset.clamp(0, widget.length - 1)
        : text.length.clamp(0, widget.length - 1);
    final split = (widget.length + 1) ~/ 2;
    final boxes = <Widget>[];
    for (var i = 0; i < widget.length; i++) {
      if (i == split) boxes.add(SizedBox(width: theme.spacing * 2));
      if (i > 0 && i != split) boxes.add(SizedBox(width: theme.spacing));
      final isCurrent = focused && i == activeIndex;
      final borderColor = hasError
          ? theme.error
          : isCurrent
          ? theme.primary
          : theme.outline;
      final digit = i < text.length ? (widget.obscure ? '•' : text[i]) : '';
      boxes.add(
        Container(
          key: ValueKey('otp-box-$i'),
          constraints: BoxConstraints(
            minWidth: theme.minTapTarget * 0.85,
            minHeight: theme.minTapTarget * 1.2,
          ),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: theme.spacing / 2),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radius),
            border: Border.all(
              color: borderColor,
              width: isCurrent || hasError ? 2 : 1,
            ),
          ),
          child: Text(digit, style: theme.codeTextStyle),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: boxes),
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    if (SystemContextMenu.isSupported(context)) {
      return SystemContextMenu.editableText(
        editableTextState: editableTextState,
      );
    }
    return _PasteToolbar(editableTextState: editableTextState);
  }
}

/// A one-button "Paste" menu built on the widgets layer, used where the
/// platform has no system context menu (ADR-0006: no Material toolbar).
class _PasteToolbar extends StatelessWidget {
  const _PasteToolbar({required this.editableTextState});

  final EditableTextState editableTextState;

  @override
  Widget build(BuildContext context) =>
      // The clipboard is checked asynchronously; rebuild when it is known.
      ValueListenableBuilder<ClipboardStatus>(
        valueListenable: editableTextState.clipboardStatus,
        builder: (context, status, _) {
          if (status != ClipboardStatus.pasteable) {
            return const SizedBox.shrink();
          }
          final paste = editableTextState.contextMenuButtonItems
              .where((item) => item.type == ContextMenuButtonType.paste)
              .firstOrNull;
          if (paste == null) return const SizedBox.shrink();
          return _toolbar(context, paste.onPressed);
        },
      );

  Widget _toolbar(BuildContext context, VoidCallback? onPressed) {
    final anchors = editableTextState.contextMenuAnchors;
    final theme = MfaTheme.of(context);
    final label = mfaStrings(context).paste;
    return CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: anchors.primaryAnchor,
        anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      ),
      child: Semantics(
        container: true,
        button: true,
        label: label,
        onTap: onPressed,
        child: MfaPressable(
          onPressed: onPressed,
          child: Container(
            constraints: BoxConstraints(
              minHeight: theme.minTapTarget,
              minWidth: theme.minTapTarget,
            ),
            padding: EdgeInsets.symmetric(horizontal: theme.spacing * 2),
            decoration: BoxDecoration(
              color: theme.onSurface,
              borderRadius: BorderRadius.circular(theme.radius),
            ),
            // Size to the label (the overlay gives loose, screen-sized
            // constraints) while keeping the minimum tap target.
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: theme.bodyTextStyle.copyWith(color: theme.surface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpInputFormatter extends TextInputFormatter {
  _OtpInputFormatter(this.length)
    : _exactMatch = RegExp('(?<!\\d)\\d{$length}(?!\\d)'),
      _groupedMatch = RegExp(
        '(?<!\\d)\\d{${(length + 1) ~/ 2}}[\\s-]\\d{${length - (length + 1) ~/ 2}}(?!\\d)',
      );

  final int length;
  final RegExp _exactMatch;
  final RegExp _groupedMatch;

  static final _nonDigit = RegExp('[^0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final delta = newValue.text.length - oldValue.text.length;
    if (delta > 1 || _nonDigit.hasMatch(newValue.text)) {
      String? inserted;
      if (oldValue.selection.isValid) {
        final prefix = oldValue.selection.start;
        final suffix = oldValue.text.length - oldValue.selection.end;
        if (newValue.text.length >= prefix + suffix) {
          inserted = newValue.text.substring(
            prefix,
            newValue.text.length - suffix,
          );
        }
      }
      final match =
          (inserted != null && inserted.length > 1
              ? (_exactMatch.firstMatch(inserted) ??
                    _groupedMatch.firstMatch(inserted))
              : null) ??
          _exactMatch.firstMatch(newValue.text) ??
          _groupedMatch.firstMatch(newValue.text);
      if (match != null) {
        final digits = match.group(0)!.replaceAll(_nonDigit, '');
        return TextEditingValue(
          text: digits,
          selection: TextSelection.collapsed(offset: digits.length),
        );
      }
    }
    final filtered = FilteringTextInputFormatter.digitsOnly.formatEditUpdate(
      oldValue,
      newValue,
    );
    return LengthLimitingTextInputFormatter(
      length,
    ).formatEditUpdate(oldValue, filtered);
  }
}
