import 'package:flutter/material.dart';

import '../components/buttons.dart';
import '../components/dropdown.dart';
import '../components/inputs.dart';
import '../components/overlays.dart';
import '../components/selection.dart';
import 'settings_side_panels.dart';
import '../components/surface.dart';
import '../shared/theme/theme.dart';

/// Mirrors the depth reference: a settings group beside a summary panel and
/// nested choice cards.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        const playback = _PlaybackPanel();
        const right = Column(
          children: [
            StoragePanel(),
            SizedBox(height: Space.s24),
            StreamingPanel(),
          ],
        );
        return wide
            ? const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: playback),
                  SizedBox(width: Space.s24),
                  Expanded(flex: 5, child: right),
                ],
              )
            : const Column(
                children: [
                  playback,
                  SizedBox(height: Space.s24),
                  right,
                ],
              );
      },
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData? icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: Space.s4),
            child: Icon(icon, size: IconSizes.navigation, color: c.foreground),
          ),
          const SizedBox(width: Space.s12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.type.subtitle.copyWith(color: c.foreground),
              ),
              Text(
                subtitle,
                style: context.type.bodySmall.copyWith(
                  color: c.foregroundSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.control,
  });

  final IconData icon;
  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ControlHeights.touch),
      child: Row(
        children: [
          Icon(icon, size: IconSizes.control, color: c.foregroundSecondary),
          const SizedBox(width: Space.s12),
          Expanded(
            child: Text(
              label,
              style: context.type.body.copyWith(color: c.foreground),
            ),
          ),
          control,
        ],
      ),
    );
  }
}

class _PlaybackPanel extends StatefulWidget {
  const _PlaybackPanel();

  @override
  State<_PlaybackPanel> createState() => _PlaybackPanelState();
}

class _PlaybackPanelState extends State<_PlaybackPanel> {
  String _quality = '1080p';
  String _subtitles = 'English';
  String _audio = 'Original';
  String _sort = 'Seeders';
  bool _hwDecode = true;
  double _buffer = 53;
  final _connections = TextEditingController(text: '200');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            icon: Icons.tune,
            title: 'Playback',
            subtitle: 'How Sentorr picks and plays torrents',
          ),
          const SizedBox(height: Space.s24),
          _SettingRow(
            icon: Icons.high_quality_outlined,
            label: 'Preferred quality',
            control: SDropdown(
              semanticLabel: 'Preferred quality',
              value: _quality,
              items: const ['2160p', '1080p', '720p', '480p'],
              onChanged: (v) => setState(() => _quality = v),
            ),
          ),
          _SettingRow(
            icon: Icons.hub_outlined,
            label: 'Max connections',
            control: STextField(
              controller: _connections,
              width: 72,
              technical: true,
              textAlign: TextAlign.center,
              semanticLabel: 'Max connections',
            ),
          ),
          _SettingRow(
            icon: Icons.subtitles_outlined,
            label: 'Subtitle language',
            control: SDropdown(
              semanticLabel: 'Subtitle language',
              value: _subtitles,
              items: const ['English', 'Spanish', 'French', 'Off'],
              onChanged: (v) => setState(() => _subtitles = v),
            ),
          ),
          _SettingRow(
            icon: Icons.graphic_eq,
            label: 'Audio track',
            control: SDropdown(
              semanticLabel: 'Audio track',
              value: _audio,
              items: const ['Original', 'English', 'Commentary'],
              onChanged: (v) => setState(() => _audio = v),
            ),
          ),
          _SettingRow(
            icon: Icons.memory,
            label: 'Hardware decoding',
            control: SSwitch(
              value: _hwDecode,
              semanticLabel: 'Hardware decoding',
              onChanged: (v) => setState(() => _hwDecode = v),
            ),
          ),
          _SettingRow(
            icon: Icons.av_timer,
            label: 'Buffer ahead',
            control: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  child: Slider(
                    value: _buffer,
                    max: 120,
                    label: '${_buffer.round()} s',
                    onChanged: (v) => setState(() => _buffer = v),
                  ),
                ),
                DepthBox(
                  style: context.depth.of(SurfaceDepth.raised),
                  radius: Radii.control,
                  height: ControlHeights.compact,
                  padding: const EdgeInsets.symmetric(horizontal: Space.s8),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '${_buffer.round().toString().padLeft(3)} s',
                      style: context.type.technical.copyWith(
                        color: c.foreground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SettingRow(
            icon: Icons.sort,
            label: 'Sort results by',
            control: SDropdown(
              semanticLabel: 'Sort results by',
              value: _sort,
              items: const ['Seeders', 'Size', 'Quality'],
              onChanged: (v) => setState(() => _sort = v),
            ),
          ),
          const SizedBox(height: Space.s32),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: Space.s8,
            children: [
              SButton.ghost(
                label: 'Reset defaults',
                icon: Icons.restart_alt,
                onPressed: () => setState(() {
                  _quality = '1080p';
                  _buffer = 30;
                  _hwDecode = true;
                }),
              ),
              SButton(
                label: 'Apply changes',
                onPressed: () =>
                    showSToast(context, message: 'Playback settings saved'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
