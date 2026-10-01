import 'package:flutter/material.dart';

import '../components/buttons.dart';
import '../components/inputs.dart';
import '../components/overlays.dart';
import '../components/selection.dart';
import '../components/status.dart';
import '../components/surface.dart';
import '../shared/theme/theme.dart';

/// Component gallery: variants and states side by side.
class ComponentsPage extends StatefulWidget {
  const ComponentsPage({super.key});

  @override
  State<ComponentsPage> createState() => _ComponentsPageState();
}

class _ComponentsPageState extends State<ComponentsPage> {
  bool _check = true;
  bool _check2 = false;
  bool _switch = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Components', style: context.type.headline.copyWith(color: c.foreground)),
        const SizedBox(height: Space.s8),
        Text(
          'Every surface here resolves from the theme: canvas → panel → raised, with inset wells.',
          style: context.type.body.copyWith(color: c.foregroundSecondary),
        ),
        const SizedBox(height: Space.s32),
        _Group(
          title: 'Buttons',
          children: [
            SButton.primary(label: 'Primary', onPressed: () {}),
            SButton(label: 'Secondary', onPressed: () {}),
            SButton.ghost(label: 'Ghost', onPressed: () {}),
            SButton.destructive(label: 'Delete', icon: Icons.delete_outline, onPressed: () {}),
            const SButton.primary(label: 'Loading', loading: true),
            const SButton(label: 'Disabled'),
            SIconButton(icon: Icons.favorite_border, tooltip: 'Favourite', onPressed: () {}),
            SIconButton(icon: Icons.grid_view, tooltip: 'Grid view', selected: true, onPressed: () {}),
          ],
        ),
        _Group(
          title: 'Inputs',
          children: const [
            STextField(width: 240, hint: 'Search', prefixIcon: Icons.search, semanticLabel: 'Search'),
            STextField(width: 240, hint: '/Volumes/Media', technical: true, semanticLabel: 'Path'),
            STextField(width: 240, hint: 'Port', errorText: 'Port must be 1024–65535', semanticLabel: 'Port'),
          ],
        ),
        _Group(
          title: 'Selection',
          children: [
            SCheckbox(value: _check, label: 'Prefer HDR', onChanged: (v) => setState(() => _check = v)),
            SCheckbox(value: _check2, label: 'Hide CAM releases', onChanged: (v) => setState(() => _check2 = v)),
            const SCheckbox(value: true, label: 'Disabled', onChanged: null),
            SSwitch(value: _switch, semanticLabel: 'Example switch', onChanged: (v) => setState(() => _switch = v)),
            const SSwitch(value: true, semanticLabel: 'On switch', onChanged: null),
          ],
        ),
        _Group(title: 'Status', children: [for (final s in TransferStatus.values) StatusBadge(s)]),
        _Group(
          title: 'Progress',
          children: const [
            SizedBox(width: 240, child: InsetProgress(value: 0.25, semanticLabel: 'Download')),
            SizedBox(width: 240, child: InsetProgress(value: 0.8, semanticLabel: 'Download')),
            SizedBox(width: 240, child: InsetProgress(value: null, semanticLabel: 'Buffering')),
          ],
        ),
        _Group(
          title: 'Overlays',
          children: [
            SButton(
              label: 'Open dialog',
              onPressed: () => showSDialog(
                context,
                title: 'Stop streaming?',
                body: 'Playback will end and peers will be disconnected. Cached pieces are kept.',
                actions: (ctx) => [
                  SButton.ghost(label: 'Keep watching', onPressed: () => Navigator.pop(ctx)),
                  SButton.primary(label: 'Stop', onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            SButton(
              label: 'Show toast',
              onPressed: () => showSToast(context, message: 'Subtitles downloaded'),
            ),
          ],
        ),
        _Group(
          title: 'Depth roles',
          children: [
            for (final d in [SurfaceDepth.panel, SurfaceDepth.raised, SurfaceDepth.inset, SurfaceDepth.floating])
              Surface(
                depth: d,
                padding: const EdgeInsets.all(Space.s16),
                child: SizedBox(
                  width: 120,
                  height: 56,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(d.name, style: context.type.technical.copyWith(color: c.foregroundSecondary)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s24),
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.type.subtitle.copyWith(color: context.colors.foreground)),
            const SizedBox(height: Space.s16),
            Wrap(
              spacing: Space.s16,
              runSpacing: Space.s16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}
