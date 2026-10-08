import '../imdb/models.dart';
import '../watching/title_codec.dart';

/// Where a movie or series stands with the viewer. Playing something moves
/// it to [watching], or [rewatching] once [completed]; finishing a movie or
/// the last episode of an ended series moves it to [completed].
enum WatchStatus {
  watching('Watching'),
  rewatching('Rewatching'),
  planned('Plan to watch'),
  paused('Paused'),
  dropped('Dropped'),
  completed('Completed');

  const WatchStatus(this.label);
  final String label;

  static WatchStatus? byName(Object? name) =>
      values.where((s) => s.name == name).firstOrNull;
}

/// A title on one of the viewer's lists. A null [status] is a removal,
/// kept so synced devices and backups do not bring the title back.
class ListEntry {
  const ListEntry({
    required this.title,
    required this.status,
    required this.updatedAt,
    this.revision = 0,
    this.rewatches = 0,
  });

  final ImdbTitle title;
  final WatchStatus? status;
  final DateTime updatedAt;
  final int revision;

  /// Times the viewer finished it again after completing it.
  final int rewatches;

  String get id => title.id;
  bool get removed => status == null;

  Map<String, dynamic> toJson() => {
    'title': titleToJson(title),
    'status': status?.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (revision != 0) 'revision': revision,
    if (rewatches != 0) 'rewatches': rewatches,
  };

  /// Null when [json] is not a record, so one bad record is skipped.
  static ListEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final title = titleFromJson(json['title']);
    final at = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final status = WatchStatus.byName(json['status']);
    if (title == null || at == null) return null;
    if (status == null && json['status'] != null) return null;
    return ListEntry(
      title: title,
      status: status,
      updatedAt: at.toLocal(),
      revision: json['revision'] is int ? json['revision'] as int : 0,
      rewatches: json['rewatches'] is int ? json['rewatches'] as int : 0,
    );
  }
}
