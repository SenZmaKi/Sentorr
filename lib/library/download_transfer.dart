import 'package:torrent_stream/torrent_stream.dart';

import '../downloads/models.dart';
import '../downloads/queue.dart';

/// Observe the download owner without acquiring or changing its torrent.
Stream<TorrentStreamState> downloadTransfers(
  DownloadQueue queue,
  String downloadId,
  int fileIndex,
) async* {
  TorrentStreamState snapshot(List<DownloadItem> items) {
    final download = items.where((d) => d.id == downloadId).firstOrNull;
    final file = download?.files.where((f) => f.index == fileIndex).firstOrNull;
    return TorrentStreamState(
      selectedFile: file == null
          ? null
          : TorrentStreamFile(
              index: file.index,
              path: file.path,
              length: file.totalBytes,
              isPadFile: false,
            ),
      selectedBytes: file?.downloadedBytes ?? 0,
      downloadBytesPerSecond: download?.downloadBytesPerSecond.round() ?? 0,
      uploadBytesPerSecond: download?.uploadBytesPerSecond.round() ?? 0,
      uploadedBytes: download?.uploadedBytes ?? 0,
      peers: download?.peers ?? 0,
      seeds: download?.seeds ?? 0,
    );
  }

  yield snapshot(queue.items);
  yield* queue.changes.map(snapshot);
}
