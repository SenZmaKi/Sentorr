part of 'queue.dart';

extension DownloadAttachments on DownloadQueue {
  /// Adds the torrent, waits for metadata and chooses its files, without
  /// holding up other commands.
  void _attach(String id) {
    unawaited(() async {
      String? hash;
      try {
        final job = _item(id).job;
        _uploadBefore[id] = _item(id).uploadedBytes;
        hash = await torrents.add(
          job.source,
          owner: _item(id).owner,
          directory: job.destinationDirectory,
        );
        final current = await _serial(() async {
          final item = _items.where((i) => i.id == id).firstOrNull;
          if (item == null || item.status != DownloadStatus.preparing) {
            // Paused, cancelled or cleared while adding.
            await torrents.release(hash!, 'download:$id');
            return false;
          }
          _replace(item.copyWith(infoHash: hash));
          return true;
        });
        if (!current) return;
        final files = await torrents
            .metadata(hash)
            .timeout(
              preparationTimeout,
              onTimeout: () => throw TimeoutException('Torrent preparation'),
            );
        final chosen = chooseFiles(job, files);
        if (job.renamedFiles.isNotEmpty) {
          await torrents
              .rename(hash, job.renamedFiles)
              .timeout(preparationTimeout);
        }
        await torrents
            .want(hash, _item(id).owner, chosen.keys.toSet())
            .timeout(preparationTimeout);
        await _serial(() async {
          final item = _item(id);
          if (item.status != DownloadStatus.preparing) return;
          _attached.add(id);
          _replace(
            item.copyWith(
              status: DownloadStatus.queued,
              files: [
                for (final f in chosen.values)
                  DownloadFileProgress(
                    f.index,
                    job.renamedFiles[f.index] ?? f.path,
                    f.length,
                    0,
                  ),
              ],
            ),
          );
          _reconcile();
          await _commit();
        });
      } catch (error, stack) {
        if (_disposed) return;
        await _serial(() async {
          final item = _items.where((i) => i.id == id).firstOrNull;
          if (item == null || item.status != DownloadStatus.preparing) return;
          _log.warning('Could not start ${item.job.title}', error, stack);
          if (hash != null) await _release(item.copyWith(infoHash: hash));
          _replace(item.withStatus(DownloadStatus.failed, error: '$error'));
          await _commit();
        });
      }
    }());
  }
}
