import '../torrents/models.dart';
import 'json.dart';

/// How a torrent is chosen when the viewer presses Play.
class TorrentSettings {
  const TorrentSettings({
    this.preferredResolution = 1080,
    this.languages = const {},
    this.reviewExactMatches = true,
    this.autoPlayDelaySeconds = 4,
    this.minimumSeeders = 1,
    this.includeBatchCandidates = true,
  });

  static const resolutions = [2160, 1080, 720, 480];
  static const minAutoPlayDelay = 1, maxAutoPlayDelay = 30;

  final int preferredResolution;

  /// Audio languages a release must confirm; empty accepts any.
  final Set<String> languages;

  /// Show an exact match with a short countdown before it plays. Close
  /// matches and misses always ask the viewer.
  final bool reviewExactMatches;

  /// How long that countdown runs.
  final int autoPlayDelaySeconds;

  /// Releases with fewer seeders are never offered.
  final int minimumSeeders;
  final bool includeBatchCandidates;

  Duration get autoPlayDelay => Duration(seconds: autoPlayDelaySeconds);

  TorrentSettings copyWith({
    int? preferredResolution,
    Set<String>? languages,
    bool? reviewExactMatches,
    int? autoPlayDelaySeconds,
    int? minimumSeeders,
    bool? includeBatchCandidates,
  }) => TorrentSettings(
    preferredResolution: preferredResolution ?? this.preferredResolution,
    languages: languages ?? this.languages,
    reviewExactMatches: reviewExactMatches ?? this.reviewExactMatches,
    autoPlayDelaySeconds: autoPlayDelaySeconds ?? this.autoPlayDelaySeconds,
    minimumSeeders: minimumSeeders ?? this.minimumSeeders,
    includeBatchCandidates:
        includeBatchCandidates ?? this.includeBatchCandidates,
  );

  factory TorrentSettings.fromJson(Map<String, dynamic> json) {
    final resolution = json['preferredResolution'];
    final languages = json['languages'];
    return TorrentSettings(
      preferredResolution: resolutions.contains(resolution)
          ? resolution as int
          : 1080,
      languages: languages is List
          ? {
              for (final l in languages)
                if (l is String && l.trim().isNotEmpty) l.trim(),
            }
          : const {},
      reviewExactMatches: jsonBool(json['reviewExactMatches'], true),
      autoPlayDelaySeconds: jsonInt(
        json['autoPlayDelaySeconds'],
        4,
        min: minAutoPlayDelay,
        max: maxAutoPlayDelay,
      ),
      minimumSeeders: jsonInt(json['minimumSeeders'], 1, min: 1),
      includeBatchCandidates: jsonBool(json['includeBatchCandidates'], true),
    );
  }

  Map<String, dynamic> toJson() => {
    'preferredResolution': preferredResolution,
    'languages': languages.toList(),
    'reviewExactMatches': reviewExactMatches,
    'autoPlayDelaySeconds': autoPlayDelaySeconds,
    'minimumSeeders': minimumSeeders,
    'includeBatchCandidates': includeBatchCandidates,
  };
}

/// Which torrent sites are searched. Sources are listed as disabled so one
/// added in a later version starts enabled.
class SourceSettings {
  const SourceSettings({this.disabled = const {}});

  final Set<TorrentSourceId> disabled;

  bool enabled(TorrentSourceId id) => !disabled.contains(id);

  SourceSettings toggled(TorrentSourceId id, bool enabled) => SourceSettings(
    disabled: enabled ? ({...disabled}..remove(id)) : {...disabled, id},
  );

  factory SourceSettings.fromJson(Map<String, dynamic> json) {
    final disabled = json['disabled'];
    return SourceSettings(
      disabled: disabled is List
          ? {
              for (final name in disabled)
                ?TorrentSourceId.values
                    .where((v) => v.name == name)
                    .firstOrNull,
            }
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
    'disabled': [for (final id in disabled) id.name],
  };
}
