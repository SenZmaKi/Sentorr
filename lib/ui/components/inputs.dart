import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/theme/theme.dart';
import 'surface.dart';

/// Raised text input with a 2-unit focus border and inline error text.
class STextField extends StatefulWidget {
  const STextField({
    super.key,
    this.controller,
    this.hint,
    this.semanticLabel,
    this.prefixIcon,
    this.errorText,
    this.width,
    this.technical = false,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.trailing,
  });

  final TextEditingController? controller;
  final String? hint;
  final String? semanticLabel;
  final IconData? prefixIcon;
  final String? errorText;
  final double? width;

  /// Numbers, sizes and paths use the technical role.
  final bool technical;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Caller-owned; the field makes its own when omitted.
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  /// Inline action after the text, e.g. a clear button.
  final Widget? trailing;

  @override
  State<STextField> createState() => _STextFieldState();
}

class _STextFieldState extends State<STextField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(STextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode == widget.focusNode) return;
    (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = widget.errorText != null;
    final focused = _focus.hasFocus;
    final borderColor = hasError
        ? c.error
        : focused
        ? c.focus
        : c.borderControl;
    final textStyle =
        (widget.technical ? context.type.technical : context.type.bodySmall)
            .copyWith(color: c.foreground);
    return SizedBox(
      width: widget.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DepthBox(
            style: context.depth.of(SurfaceDepth.raised),
            radius: Radii.control,
            height: ControlHeights.standard,
            border: Border.all(
              color: borderColor,
              width: focused || hasError ? Borders.focus : Borders.edge,
            ),
            padding: const EdgeInsets.symmetric(horizontal: Space.s12),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  Icon(
                    widget.prefixIcon,
                    size: IconSizes.metadata,
                    color: c.foregroundMuted,
                  ),
                  const SizedBox(width: Space.s8),
                ],
                Expanded(
                  child: Semantics(
                    label: widget.semanticLabel,
                    textField: true,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      style: textStyle,
                      textAlign: widget.textAlign,
                      cursorColor: c.foreground,
                      cursorWidth: 1.5,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      textInputAction: widget.textInputAction,
                      decoration: InputDecoration.collapsed(
                        hintText: widget.hint,
                        hintStyle: textStyle.copyWith(color: c.foregroundMuted),
                      ),
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: Space.s8),
                  widget.trailing!,
                ],
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: Space.s4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: IconSizes.metadata,
                  color: c.error,
                ),
                const SizedBox(width: Space.s4),
                Text(
                  widget.errorText!,
                  style: context.type.caption.copyWith(color: c.error),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
