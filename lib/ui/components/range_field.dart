import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../search/models.dart';
import 'inputs.dart';
import '../shared/theme/theme.dart';

/// "7" rather than "7.0".
String formatBound(num v) =>
    v is double && v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Paired minimum and maximum inputs for an optional numeric filter. Typing
/// commits once it pauses, so each keystroke does not start a search;
/// submitting or leaving a field commits at once.
class RangeField<T extends num> extends StatefulWidget {
  const RangeField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.parse,
    required this.name,
    this.decimal = false,
  });

  final Bounds<T> value;
  final ValueChanged<Bounds<T>> onChanged;

  /// Reads one side, clamped to its valid range; null when empty or invalid.
  final T? Function(String text) parse;

  /// Lower-case filter name for accessible labels, e.g. "year".
  final String name;
  final bool decimal;

  @override
  State<RangeField<T>> createState() => _RangeFieldState<T>();
}

class _RangeFieldState<T extends num> extends State<RangeField<T>> {
  static const _pause = Duration(milliseconds: 700);

  late final _min = TextEditingController(text: _text(widget.value.min));
  late final _max = TextEditingController(text: _text(widget.value.max));
  final _minFocus = FocusNode();
  final _maxFocus = FocusNode();
  Timer? _timer;

  String _text(T? v) => v == null ? '' : formatBound(v);

  @override
  void initState() {
    super.initState();
    for (final f in [_minFocus, _maxFocus]) {
      f.addListener(() {
        if (!f.hasFocus) _commit();
      });
    }
  }

  @override
  void didUpdateWidget(RangeField<T> old) {
    super.didUpdateWidget(old);
    // Outside changes (a removed chip, swapped bounds) rewrite the text;
    // text that already means the new value is left as typed.
    if (old.value == widget.value) return;
    if (widget.parse(_min.text) != widget.value.min) {
      _min.text = _text(widget.value.min);
    }
    if (widget.parse(_max.text) != widget.value.max) {
      _max.text = _text(widget.value.max);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _min.dispose();
    _max.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    super.dispose();
  }

  void _schedule(String _) {
    _timer?.cancel();
    _timer = Timer(_pause, _commit);
  }

  void _commit() {
    _timer?.cancel();
    final next = Bounds<T>.sorted(
      widget.parse(_min.text),
      widget.parse(_max.text),
    );
    if (next != widget.value) widget.onChanged(next);
  }

  Widget _field(
    TextEditingController controller,
    FocusNode focus,
    String side,
  ) => STextField(
    controller: controller,
    focusNode: focus,
    hint: 'Any',
    semanticLabel: '$side ${widget.name}',
    technical: true,
    keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
    textInputAction: TextInputAction.done,
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        RegExp(widget.decimal ? r'[0-9.]' : r'[0-9]'),
      ),
      LengthLimitingTextInputFormatter(4),
    ],
    onChanged: _schedule,
    onSubmitted: (_) => _commit(),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _field(_min, _minFocus, 'Minimum')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s8),
          child: Text(
            'to',
            style: context.type.bodySmall.copyWith(
              color: context.colors.foregroundMuted,
            ),
          ),
        ),
        Expanded(child: _field(_max, _maxFocus, 'Maximum')),
      ],
    );
  }
}
