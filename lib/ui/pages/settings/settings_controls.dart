import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../components/inputs.dart';
import '../../components/select.dart';
import '../../shared/theme/theme.dart';

/// A whole number with its unit, saved when submitted or left. Values
/// outside [min]–[max] are clamped; blank restores the saved value.
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.value,
    required this.unit,
    required this.onSubmitted,
    required this.semanticLabel,
    this.min = 0,
    this.max,
  });

  final int value;
  final String unit;
  final int min;
  final int? max;
  final ValueChanged<int> onSubmitted;
  final String semanticLabel;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final _controller = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(NumberField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != old.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      _controller.text = '${widget.value}';
      return;
    }
    final value = parsed.clamp(widget.min, widget.max ?? parsed);
    _controller.text = '$value';
    if (value != widget.value) widget.onSubmitted(value);
  }

  @override
  Widget build(BuildContext context) {
    return STextField(
      controller: _controller,
      focusNode: _focus,
      width: 160,
      technical: true,
      textAlign: TextAlign.end,
      semanticLabel: widget.semanticLabel,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => _commit(),
      trailing: Padding(
        padding: const EdgeInsets.only(left: Space.s8),
        child: Text(
          widget.unit,
          style: context.type.bodySmall.copyWith(
            color: context.colors.foregroundMuted,
          ),
        ),
      ),
    );
  }
}

/// One choice from a short list, in a fixed-width dropdown.
class ChoiceField<T> extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
    required this.semanticLabel,
  });

  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: SSelect<T>(
        options: options,
        selected: {value},
        labelOf: labelOf,
        onSelected: onChanged,
        semanticLabel: semanticLabel,
      ),
    );
  }
}

const megabyte = 1024 * 1024;

/// A number with named non-numeric values, e.g. Unlimited or Off: a
/// dropdown of [presets] plus Custom, and a number field while Custom is
/// chosen. Values are in the field's own unit.
class LimitField extends StatefulWidget {
  const LimitField({
    super.key,
    required this.value,
    required this.presets,
    required this.customDefault,
    required this.unit,
    required this.onChanged,
    required this.semanticLabel,
    this.min = 0,
    this.max,
  });

  final int value;

  /// Values with names instead of a number, e.g. {0: 'Unlimited'}.
  final Map<int, String> presets;

  /// What Custom starts at when no custom value was entered yet.
  final int customDefault;
  final String unit;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;
  final String semanticLabel;

  @override
  State<LimitField> createState() => _LimitFieldState();
}

class _LimitFieldState extends State<LimitField> {
  static const _custom = -1;

  /// Custom stays chosen while its value happens to equal a preset's.
  late bool _customChosen;
  late int _lastCustom;

  @override
  void initState() {
    super.initState();
    _customChosen = !widget.presets.containsKey(widget.value);
    _lastCustom = _customChosen ? widget.value : widget.customDefault;
  }

  @override
  void didUpdateWidget(LimitField old) {
    super.didUpdateWidget(old);
    if (widget.value == old.value) return;
    // Follow changes made elsewhere, e.g. a reset to defaults.
    if (!widget.presets.containsKey(widget.value)) {
      _customChosen = true;
      _lastCustom = widget.value;
    } else if (widget.value != _lastCustom) {
      _customChosen = false;
    }
  }

  void _choose(int option) {
    if (option == _custom) {
      setState(() => _customChosen = true);
      widget.onChanged(_lastCustom);
    } else {
      setState(() => _customChosen = false);
      widget.onChanged(option);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [...widget.presets.keys, _custom];
    final mode = _customChosen ? _custom : widget.value;
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.s8,
      runSpacing: Space.s8,
      children: [
        ChoiceField<int>(
          value: mode,
          options: options,
          labelOf: (o) => o == _custom ? 'Custom' : widget.presets[o]!,
          onChanged: _choose,
          semanticLabel: widget.semanticLabel,
        ),
        if (_customChosen)
          NumberField(
            value: _lastCustom,
            unit: widget.unit,
            min: widget.min,
            max: widget.max,
            semanticLabel: '${widget.semanticLabel}, custom value',
            onSubmitted: (n) {
              _lastCustom = n;
              widget.onChanged(n);
            },
          ),
      ],
    );
  }
}
