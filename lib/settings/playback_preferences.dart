/// Stable track descriptions, scoped to a movie or episode. Native IDs alone
/// are unsafe: another release may assign the same ID to a different language.
class TrackPreference {
  const TrackPreference(
    this.id,
    this.title,
    this.language, {
    this.file = false,
  });
  final String id;
  final String? title, language;
  final bool file;

  bool matches(
    String candidateId,
    String? candidateTitle,
    String? candidateLanguage,
  ) =>
      title == candidateTitle &&
      language == candidateLanguage &&
      (title != null || language != null || id == candidateId);

  factory TrackPreference.fromJson(Map<String, dynamic> json) =>
      TrackPreference(
        json['id'] as String,
        json['title'] as String?,
        json['language'] as String?,
        file: json['file'] == true,
      );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'language': language,
    'file': file,
  };
}

class ItemPlaybackPreferences {
  const ItemPlaybackPreferences({
    this.audio,
    this.subtitle,
    this.captionsEnabled,
  });
  final TrackPreference? audio, subtitle;
  final bool? captionsEnabled;
  ItemPlaybackPreferences copyWith({
    TrackPreference? audio,
    TrackPreference? subtitle,
    bool? captionsEnabled,
  }) => ItemPlaybackPreferences(
    audio: audio ?? this.audio,
    subtitle: subtitle ?? this.subtitle,
    captionsEnabled: captionsEnabled ?? this.captionsEnabled,
  );
  factory ItemPlaybackPreferences.fromJson(Map<String, dynamic> json) =>
      ItemPlaybackPreferences(
        audio: json['audio'] is Map<String, dynamic>
            ? TrackPreference.fromJson(json['audio'])
            : null,
        subtitle: json['subtitle'] is Map<String, dynamic>
            ? TrackPreference.fromJson(json['subtitle'])
            : null,
        captionsEnabled: json['captionsEnabled'] as bool?,
      );
  Map<String, dynamic> toJson() => {
    'audio': audio?.toJson(),
    'subtitle': subtitle?.toJson(),
    'captionsEnabled': captionsEnabled,
  };
}

class PlaybackPreferences {
  const PlaybackPreferences({
    this.volume = 100,
    this.speed = 1,
    this.items = const {},
  });
  final double volume, speed;
  final Map<String, ItemPlaybackPreferences> items;
  PlaybackPreferences copyWith({
    double? volume,
    double? speed,
    Map<String, ItemPlaybackPreferences>? items,
  }) => PlaybackPreferences(
    volume: volume ?? this.volume,
    speed: speed ?? this.speed,
    items: items ?? this.items,
  );
  PlaybackPreferences updateItem(
    String id,
    ItemPlaybackPreferences Function(ItemPlaybackPreferences) change,
  ) {
    final next = {...items}..remove(id);
    next[id] = change(items[id] ?? const ItemPlaybackPreferences());
    // Bound the settings file while retaining the most recently edited titles.
    while (next.length > 200) {
      next.remove(next.keys.first);
    }
    return copyWith(items: Map.unmodifiable(next));
  }

  factory PlaybackPreferences.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return const PlaybackPreferences();
    double number(String key, double fallback, double min, double max) {
      final n = value[key];
      return n is num && n.isFinite ? n.toDouble().clamp(min, max) : fallback;
    }

    return PlaybackPreferences(
      volume: number('volume', 100, 0, 100),
      speed: number('speed', 1, 0.25, 2),
      items: {
        if (value['items'] is Map<String, dynamic>)
          for (final entry in (value['items'] as Map<String, dynamic>).entries)
            if (entry.value is Map<String, dynamic>)
              entry.key: ItemPlaybackPreferences.fromJson(entry.value),
      },
    );
  }
  Map<String, dynamic> toJson() => {
    'volume': volume,
    'speed': speed,
    'items': items.map((key, value) => MapEntry(key, value.toJson())),
  };
}
