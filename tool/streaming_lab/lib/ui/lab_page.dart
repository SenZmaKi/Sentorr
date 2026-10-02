import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sentorr/ui/components/buttons.dart';
import 'package:sentorr/ui/components/surface.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../runtime/lab_controller.dart';
import 'diagnostics_panel.dart';
import 'lab_player.dart';
import 'profile_controls.dart';

class LabPage extends StatefulWidget {
  const LabPage({super.key, this.smoke});
  final Future<void> Function(LabController)? smoke;
  @override
  State<LabPage> createState() => _LabPageState();
}

class _LabPageState extends State<LabPage> {
  final lab = LabController();
  final magnet = TextEditingController();
  late final video = VideoController(lab.player);
  @override
  void initState() {
    super.initState();
    lab.addListener(_changed);
    if (widget.smoke != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.smoke!(lab));
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    lab.removeListener(_changed);
    unawaited(lab.shutdown());
    magnet.dispose();
    super.dispose();
  }

  Future<void> _pick(bool local) async {
    final result = await FilePicker.pickFiles(
      type: local ? FileType.any : FileType.custom,
      allowedExtensions: local ? null : ['torrent'],
    );
    final path = result?.files.single.path;
    if (path != null) await lab.open(path, localSeed: local);
  }

  Future<void> _export() async {
    final path = await FilePicker.saveFile(
      fileName: 'sentorr-streaming-report.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path != null) await lab.export(path);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sentorr Streaming Lab'),
      actions: [
        IconButton(
          onPressed: _export,
          tooltip: 'Export diagnostics',
          icon: const Icon(Icons.save_alt),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(Space.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Watch while pieces arrive',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Space.s8),
          const Text(
            'Controlled seed tests the full torrent → HTTP → MediaKit path using a local media file.',
          ),
          const SizedBox(height: Space.s24),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfileControls(lab: lab),
                const SizedBox(height: Space.s16),
                Wrap(
                  spacing: Space.s12,
                  runSpacing: Space.s12,
                  children: [
                    SButton.primary(
                      label: 'Controlled seed',
                      icon: Icons.science_outlined,
                      loading: lab.busy,
                      onPressed: lab.busy ? null : () => _pick(true),
                    ),
                    SButton(
                      label: 'Open torrent',
                      icon: Icons.folder_open,
                      onPressed: lab.busy ? null : () => _pick(false),
                    ),
                    SButton(
                      label: 'Stop session',
                      icon: Icons.stop,
                      onPressed: lab.busy || lab.files.isNotEmpty
                          ? lab.stop
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: Space.s16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: magnet,
                        decoration: const InputDecoration(
                          labelText: 'Magnet URI',
                        ),
                        onSubmitted: lab.busy
                            ? null
                            : (value) => lab.open(value),
                      ),
                    ),
                    const SizedBox(width: Space.s12),
                    SButton(
                      label: 'Load magnet',
                      onPressed: lab.busy
                          ? null
                          : () => lab.open(magnet.text.trim()),
                    ),
                  ],
                ),
                if (lab.files.isNotEmpty) ...[
                  const SizedBox(height: Space.s16),
                  DropdownButtonFormField<int>(
                    initialValue: lab.selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Media file'),
                    items: lab.files
                        .where(
                          (f) =>
                              (f['size'] as int) > 0 &&
                              ((f['flags'] as int) & 1) == 0,
                        )
                        .map(
                          (f) => DropdownMenuItem(
                            value: f['index'] as int,
                            child: Text(
                              '${f['path']} · ${formatBytes(f['size'] as int)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: lab.active || lab.busy
                        ? null
                        : (value) => setState(() => lab.selected = value),
                  ),
                  if (!lab.active)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.s12),
                      child: SButton.primary(
                        label: 'Play selected file',
                        onPressed: lab.busy || lab.selected == null
                            ? null
                            : lab.playSelected,
                      ),
                    ),
                ],
                if (lab.busy)
                  const Padding(
                    padding: EdgeInsets.only(top: Space.s16),
                    child: LinearProgressIndicator(),
                  ),
                if (lab.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.s16),
                    child: SelectableText(
                      lab.error!,
                      style: TextStyle(color: context.colors.error),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Space.s24),
          LayoutBuilder(
            builder: (context, constraints) {
              final player = LabPlayer(lab: lab, video: video);
              final diagnostics = DiagnosticsPanel(lab: lab);
              if (constraints.maxWidth < 1000) {
                return Column(
                  children: [
                    player,
                    const SizedBox(height: Space.s24),
                    diagnostics,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: player),
                  const SizedBox(width: Space.s24),
                  Expanded(flex: 2, child: diagnostics),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
