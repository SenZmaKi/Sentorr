import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../app/services.dart';
import '../../torrents/models.dart';
import '../persistence/json_file_store.dart';
import '../signed_envelope.dart';
import 'models.dart';

const sourceDirectoryUrl = String.fromEnvironment(
  'SOURCE_DIRECTORY_URL',
  defaultValue: 'https://senzmaki.github.io/Sentorr/source-directory.json',
);
final sourceDirectoryProvider =
    NotifierProvider<SourceDirectoryController, SourceDirectory>(
      SourceDirectoryController.new,
    );

class SourceDirectoryController extends Notifier<SourceDirectory> {
  SourceDirectoryController({Future<SourceDirectory> Function(String)? decode})
    : _decode = decode ?? decodeDirectory;
  final Future<SourceDirectory> Function(String) _decode;
  Future<void>? _refresh;
  final _cancel = CancelToken();
  bool _disposed = false;
  @override
  SourceDirectory build() {
    ref.onDispose(() {
      _disposed = true;
      _cancel.cancel();
    });
    return SourceDirectory.defaults();
  }

  Future<void> initialize() async {
    final paths = ref.read(appPathsProvider);
    final store = JsonFileStore(paths.sourceDirectoryFile);
    try {
      final cached = await store.read();
      if (cached != null) state = await _decode(jsonEncode(cached));
    } catch (error) {
      Logger('sentorr.source_directory')
          .warning('Ignoring invalid cached directory', error);
    }
    // UI startup does not wait for the network; searches await this refresh.
    unawaited(refresh());
  }

  Future<void> refresh() =>
      _refresh ??= _fetch().whenComplete(() => _refresh = null);
  Future<void> waitForRefresh() async => await _refresh;
  String endpointFor(TorrentSourceId id) => state.endpoints[id]!;

  Future<void> _fetch() async {
    final paths = ref.read(appPathsProvider);
    try {
      final fetchState = JsonFileStore(paths.sourceDirectoryFetchStateFile);
      final previous = await fetchState.read();
      final response = await ref
          .read(networkClientProvider)
          .dio
          .get<String>(
            sourceDirectoryUrl,
            cancelToken: _cancel,
            options: Options(
              responseType: ResponseType.plain,
              headers: {
                'Cache-Control': 'no-cache',
                if (state.version > 0 &&
                    state.expiresAt.isAfter(DateTime.now().toUtc()) &&
                    previous?['eTag'] is String)
                  'If-None-Match': previous!['eTag'],
              },
              validateStatus: (status) => status == 200 || status == 304,
            ),
          );
      if (response.statusCode == 304) return;
      final directory = await _decode(response.data!);
      if (_disposed) return;
      if (directory.version < state.version) {
        throw const FormatException('Source directory rollback');
      }
      await JsonFileStore(paths.sourceDirectoryFile)
          .write(jsonDecode(response.data!) as Map<String, dynamic>);
      await fetchState.write({'eTag': response.headers.value('etag')});
      state = directory;
    } catch (error) {
      Logger('sentorr.source_directory')
          .warning('Source refresh failed; retaining valid endpoints', error);
    }
  }
}

Future<SourceDirectory> decodeDirectory(String envelope) async =>
    SourceDirectory.fromJson(
      await decodeSignedJsonEnvelope(
        envelope,
        publicKeyBase64: sourceDirectoryPublicKeyBase64,
      ),
    );
