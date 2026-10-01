import 'package:flutter/material.dart';

import '../shared/theme/theme.dart';
import 'interactive.dart';
import 'surface.dart';

/// Raised trigger that opens a floating menu (radius 8, padding 8).
class SDropdown<T> extends StatefulWidget {
  const SDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.semanticLabel,
    this.labelOf,
    this.minWidth = 96,
  });

  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String semanticLabel;
  final String Function(T)? labelOf;
  final double minWidth;

  @override
  State<SDropdown<T>> createState() => _SDropdownState<T>();
}

class _SDropdownState<T> extends State<SDropdown<T>> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  String _label(T v) => widget.labelOf?.call(v) ?? '$v';

  void _select(T v) {
    _portal.hide();
    setState(() {});
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final raised = context.depth.of(SurfaceDepth.raised);
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => _menu(context),
        child: Interactive(
          semanticLabel: '${widget.semanticLabel}: ${_label(widget.value)}',
          onTap: () => setState(_portal.toggle),
          builder: (context, s) => DepthBox(
            style: s.pressed
                ? raised.pressed(c.statePressed)
                : s.hovered
                ? raised.hovered()
                : raised,
            radius: Radii.control,
            height: ControlHeights.compact,
            padding: const EdgeInsets.only(left: Space.s12, right: Space.s8),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: widget.minWidth - Space.s12 - Space.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_label(widget.value), style: context.type.label.copyWith(color: c.foreground)),
                  const SizedBox(width: Space.s8),
                  Icon(
                    _portal.isShowing ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: IconSizes.metadata,
                    color: c.foregroundSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    final c = context.colors;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => setState(_portal.hide)),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, Space.s4),
          child: Align(
            alignment: Alignment.topRight,
            child: IntrinsicWidth(
              child: DepthBox(
                style: context.depth.of(SurfaceDepth.floating),
                radius: Radii.control,
                border: Border.all(color: c.borderStrong),
                padding: const EdgeInsets.all(Space.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final item in widget.items) _item(context, item)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(BuildContext context, T item) {
    final c = context.colors;
    final selected = item == widget.value;
    return Interactive(
      onTap: () => _select(item),
      selected: selected,
      semanticLabel: _label(item),
      builder: (context, s) => AnimatedContainer(
        duration: Motion.hover,
        height: ControlHeights.compact,
        padding: const EdgeInsets.symmetric(horizontal: Space.s8),
        decoration: BoxDecoration(
          color: s.pressed
              ? c.statePressed
              : s.hovered
              ? c.stateHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Row(
          children: [
            SizedBox(
              width: IconSizes.control,
              child: selected ? Icon(Icons.check, size: IconSizes.metadata, color: c.foreground) : null,
            ),
            const SizedBox(width: Space.s4),
            Text(_label(item), style: context.type.bodySmall.copyWith(color: c.foreground)),
            const SizedBox(width: Space.s16),
          ],
        ),
      ),
    );
  }
}
