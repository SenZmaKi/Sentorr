import 'package:flutter/material.dart';

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

  @override
  State<STextField> createState() => _STextFieldState();
}

class _STextFieldState extends State<STextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
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
    final textStyle = (widget.technical ? context.type.technical : context.type.bodySmall).copyWith(
      color: c.foreground,
    );
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
            border: Border.all(color: borderColor, width: focused || hasError ? Borders.focus : Borders.edge),
            padding: const EdgeInsets.symmetric(horizontal: Space.s12),
            child: Row(
              children: [
                if (widget.prefixIcon != null) ...[
                  Icon(widget.prefixIcon, size: IconSizes.metadata, color: c.foregroundMuted),
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
                      decoration: InputDecoration.collapsed(
                        hintText: widget.hint,
                        hintStyle: textStyle.copyWith(color: c.foregroundMuted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: Space.s4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: IconSizes.metadata, color: c.error),
                const SizedBox(width: Space.s4),
                Text(widget.errorText!, style: context.type.caption.copyWith(color: c.error)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
