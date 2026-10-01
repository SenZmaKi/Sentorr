import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'diagnostics.dart';
import 'sample.dart';
import 'track_controls.dart';
import 'smoke_check.dart';

class PlayerPage extends StatefulWidget {
  final bool smoke;
  const PlayerPage({super.key, this.smoke = false});
  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      title: 'Sentorr Codec Lab',
      libass: true,
      libassAndroidFont: 'assets/fonts/NotoSans-Regular.ttf',
      libassAndroidFontName: 'Noto Sans',
    ),
  );
  late final VideoController _video = VideoController(_player);
  Diagnostics? _diagnostics;
  StreamSubscription<String>? _errors;
  final List<Sample> _samples = [];
  final Map<String, String> _verdicts = {};
  final List<String> _errorLog = [];
  int _selected = 0;
  bool _loading = true, _showStats = true, _opening = false, _hardware = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _errors = _player.stream.error.listen((error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _errorLog.add(error);
      });
    });
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _diagnostics ??= Diagnostics(_player, View.of(context).display.refreshRate);
  }

  Future<void> _initialize() async {
    try {
      final samples = await Sample.bundled();
      if (!mounted) return;
      setState(() {
        _samples.addAll(samples);
        _loading = false;
      });
      await _player.setPlaylistMode(PlaylistMode.single);
      if (_samples.isNotEmpty) await _open(0, play: false);
      if (widget.smoke) {
        final passed = await smokeCheck(_player, _samples);
        exit(passed ? 0 : 1);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _open(int index, {bool play = true}) async {
    if (_opening) return;
    setState(() {
      _selected = index;
      _error = null;
      _opening = true;
      _errorLog.clear();
    });
    try {
      _diagnostics?.reset();
      await _player.open(Media(_samples[index].uri), play: play);
      // Wait for this file's track metadata before selecting a subtitle.
      // mpv auto-selection may leave non-default subtitle tracks disabled.
      final expectedSubs = (_samples[index].metadata['streams'] as List? ?? [])
          .where((s) => s['codec_type'] == 'subtitle')
          .length;
      if (expectedSubs > 0) {
        bool ready(Tracks tracks) =>
            tracks.subtitle
                .where((t) => t.id != 'auto' && t.id != 'no')
                .length >=
            expectedSubs;
        final tracks = ready(_player.state.tracks)
            ? _player.state.tracks
            : await _player.stream.tracks
                  .firstWhere(ready)
                  .timeout(const Duration(seconds: 10));
        await _player.setSubtitleTrack(
          tracks.subtitle.firstWhere((t) => t.id != 'auto' && t.id != 'no'),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _errorLog.add('$error');
        });
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _addFiles() async {
    final result = await FilePicker.pickFiles(type: FileType.any);
    if (!mounted) return;
    setState(() {
      for (final file in result) {
        if (file.path != null) {
          _samples.add(
            Sample(
              file.name,
              file.path!,
              'User-added file. Stream metadata is available in player diagnostics.',
              {},
            ),
          );
        }
      }
    });
  }

  Future<void> _export() async {
    try {
      final data = const JsonEncoder.withIndent('  ').convert({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'hardwareRequested': _hardware,
        'selectedSample': _samples.isEmpty ? null : _samples[_selected].title,
        'diagnostics': _diagnostics?.snapshot(),
        'errorsForCurrentSample': _errorLog,
        'selectedAudioTrack': _player.state.track.audio.id,
        'selectedSubtitleTrack': _player.state.track.subtitle.id,
        'subtitleText': _player.state.subtitle,
        'availableAudioTracks': _player.state.tracks.audio
            .map((t) => {'id': t.id, 'title': t.title, 'codec': t.codec})
            .toList(),
        'availableSubtitleTracks': _player.state.tracks.subtitle
            .map((t) => {'id': t.id, 'title': t.title, 'codec': t.codec})
            .toList(),
        'results': [
          for (final s in _samples)
            {
              'title': s.title,
              'verdict': _verdicts[s.uri] ?? 'Untested',
              'metadata': s.metadata,
            },
        ],
      });
      final uri = await FilePicker.saveFile(
        fileName: 'sentorr-codec-report.json',
        bytes: Uint8List.fromList(utf8.encode(data)),
        mimeType: 'application/json',
        dialogTitle: 'Save codec compatibility report',
      );
      if (mounted && uri != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Report saved: $uri')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Report export failed: $error')));
      }
    }
  }

  Future<void> _toggleHardware(bool value) async {
    if (_opening) return;
    final native = _player.platform;
    if (native is! NativePlayer) return;
    try {
      await native.setProperty('hwdec', value ? 'auto' : 'no');
      if (mounted) setState(() => _hardware = value);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void dispose() {
    _diagnostics?.dispose();
    _errors?.cancel();
    _player.dispose();
    super.dispose();
  }

  Widget _queue() => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        if (constraints.maxHeight >= 140)
          const ListTile(
            title: Text('COMPATIBILITY QUEUE'),
            subtitle: Text('Select a clip. Clips loop for inspection.'),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _samples.length,
            itemBuilder: (context, index) {
              final sample = _samples[index];
              return ListTile(
                selected: index == _selected,
                enabled: !_opening,
                leading: Text('${index + 1}'.padLeft(2, '0')),
                title: Text(sample.title),
                subtitle: Text(
                  '${sample.expectedTracks}\n${_verdicts[sample.uri] ?? 'Untested'}',
                ),
                onTap: () => _open(index),
              );
            },
          ),
        ),
      ],
    ),
  );
  Widget _playback() => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: Video(controller: _video)),
              if (_showStats && _diagnostics != null)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  bottom: 70,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SingleChildScrollView(
                      child: StatsOverlay(diagnostics: _diagnostics!),
                    ),
                  ),
                ),
              if (_opening) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        if (_samples.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .45),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      SelectableText(
                        _error!,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    Text(
                      _samples[_selected].title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(_samples[_selected].purpose),
                    Text(_samples[_selected].expectedTracks),
                    const SizedBox(height: 8),
                    TrackControls(player: _player),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final verdict in [
                          'Pass',
                          'Video issue',
                          'Audio issue',
                          'Subtitle issue',
                        ])
                          ChoiceChip(
                            label: Text(verdict),
                            selected:
                                _verdicts[_samples[_selected].uri] == verdict,
                            onSelected: (_) => setState(
                              () =>
                                  _verdicts[_samples[_selected].uri] = verdict,
                            ),
                          ),
                        TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Verified fixture metadata'),
                              content: SingleChildScrollView(
                                child: SelectableText(
                                  const JsonEncoder.withIndent('  ')
                                      .convert(_samples[_selected].metadata),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                          child: const Text('Fixture details'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sentorr · Codec Lab'),
      actions: [
        IconButton(
          tooltip: 'Add local media',
          onPressed: _loading ? null : _addFiles,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: 'Export test report',
          onPressed: _loading ? null : _export,
          icon: const Icon(Icons.save_alt),
        ),
        IconButton(
          tooltip: 'Toggle stats for nerds',
          onPressed: () => setState(() => _showStats = !_showStats),
          icon: Icon(_showStats ? Icons.analytics : Icons.analytics_outlined),
        ),
        PopupMenuButton<bool>(
          tooltip: 'Decoding mode',
          onSelected: _toggleHardware,
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: true,
              checked: _hardware,
              child: const Text('Hardware decoding: auto'),
            ),
            CheckedPopupMenuItem(
              value: false,
              checked: !_hardware,
              child: const Text('Software decoding'),
            ),
          ],
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return Row(
                  children: [
                    SizedBox(width: 320, child: _queue()),
                    const VerticalDivider(width: 1),
                    Expanded(child: _playback()),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(flex: 3, child: _playback()),
                  SizedBox(
                    height: constraints.maxHeight * .25,
                    child: _queue(),
                  ),
                ],
              );
            },
          ),
  );
}
