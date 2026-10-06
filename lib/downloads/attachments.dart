part of 'queue.dart';

extension DownloadAttachments on DownloadQueue {
  /// Adds the torrent, waits for metadata and chooses its files, without
  /// holding up other commands.
  void _attach(String id) {
    if (_disposed) return;
    final attempt = _DownloadAttempt(
      '${_item(id).owner}:${DownloadQueue._attemptSequence++}',
    );
    _attempts[id] = attempt;
    bool current() =>
        !_disposed &&
        identical(_attempts[id], attempt) &&
        _items.any((i) => i.id == id && i.status == DownloadStatus.preparing);
    unawaited(() async {
      String? hash;
      try {
        final job = _item(id).job;
        _uploadBefore[id] = _item(id).uploadedBytes;
        hash = await torrents.add(
          job.source,
          owner: attempt.owner,
          directory: job.destinationDirectory,
        );
        attempt.hash = hash;
        if (!current()) return;
        final accepted = await _serial(() async {
          final item = _items.where((i) => i.id == id).firstOrNull;
          if (item == null || !current()) return false;
          _replace(item.copyWith(infoHash: hash));
          return true;
        });
        if (!accepted) return;
        final files = await torrents
            .metadata(hash)
            .timeout(
              preparationTimeout,
              onTimeout: () => throw TimeoutException('Torrent preparation'),
            );
        if (!current()) return;
        final chosen = chooseFiles(job, files);
        if (job.renamedFiles.isNotEmpty) {
          await torrents
              .rename(hash, job.renamedFiles)
              .timeout(preparationTimeout);
        }
        if (!current()) return;
        await torrents
            .want(hash, attempt.owner, chosen.keys.toSet())
            .timeout(preparationTimeout);
        if (!current()) return;
        await _serial(() async {
          if (!current()) return;
          final item = _item(id);
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
                    item.files
                            .where(
                              (saved) =>
                                  saved.index == f.index &&
                                  saved.totalBytes == f.length,
                            )
                            .firstOrNull
                            ?.downloadedBytes ??
                        0,
                  ),
              ],
            ),
          );
          _reconcile();
          await _commit();
        });
      } catch (error, stack) {
        if (!current()) return;
        await _serial(() async {
          final item = _items.where((i) => i.id == id).firstOrNull;
          if (item == null || !current()) return;
          _log.warning('Could not start ${item.job.title}', error, stack);
          await _release(item);
          _replace(_afterFailure(item, '$error'));
          await _commit();
        });
      } finally {
        if (!identical(_attempts[id], attempt) || _disposed) {
          await _releaseAttempt(attempt);
        }
      }
    }());
  }
}
