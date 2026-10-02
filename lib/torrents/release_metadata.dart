import 'package:anitomy_dart/anitomy_dart.dart';

/// Anitomy owns episode extraction; Sentorr adapts two unsupported scene forms.
class ReleaseMetadata {
  ReleaseMetadata._(this.seasons, this.episodes);
  final List<int> seasons, episodes;

  static ReleaseMetadata parse(String name) {
    var filename = name.replaceAll(RegExp(r'[._]'), ' ');
    // Anitomy supports season zero in long form, but rejects S00Exx.
    filename = filename.replaceAllMapped(
      RegExp(r'\b(?:s00e|0x)(\d{1,3})\b', caseSensitive: false),
      (m) => 'Season 0 Episode ${m[1]}',
    );
    // Anitomy 1.0.1 leaves bare Sxx packs in the title.
    filename = filename.replaceAllMapped(
      RegExp(r'\bs(\d{1,2})\b', caseSensitive: false),
      (m) => 'Season ${m[1]}',
    );
    final parser = Anitomy()..options.parseEpisodeTitle = false;
    parser.parse(filename);
    List<int> numbers(ElementCategory category) => List.unmodifiable(
      parser.elements.getAll(category).map(int.tryParse).whereType<int>(),
    );
    return ReleaseMetadata._(
      numbers(ElementCategory.animeSeason),
      numbers(ElementCategory.episodeNumber),
    );
  }
}
