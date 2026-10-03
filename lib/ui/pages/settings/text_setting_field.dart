import 'package:flutter/material.dart';

import '../../components/inputs.dart';

/// Free text, saved when submitted or left.
class TextSettingField extends StatefulWidget {
  const TextSettingField({
    super.key,
    required this.value,
    required this.onSubmitted,
    required this.semanticLabel,
    this.hint,
    this.obscureText = false,
  });

  final String value;
  final ValueChanged<String> onSubmitted;
  final String semanticLabel;
  final String? hint;
  final bool obscureText;

  @override
  State<TextSettingField> createState() => _TextSettingFieldState();
}

class _TextSettingFieldState extends State<TextSettingField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(TextSettingField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != old.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final value = widget.obscureText
        ? _controller.text
        : _controller.text.trim();
    if (value != widget.value) widget.onSubmitted(value);
  }

  @override
  Widget build(BuildContext context) {
    return STextField(
      controller: _controller,
      focusNode: _focus,
      width: 200,
      technical: !widget.obscureText,
      hint: widget.hint,
      obscureText: widget.obscureText,
      semanticLabel: widget.semanticLabel,
      onSubmitted: (_) => _commit(),
    );
  }
}
