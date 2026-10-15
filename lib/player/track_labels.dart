import 'package:media_kit/media_kit.dart';

String audioLabel(AudioTrack t) => _label(t.id, t.title, t.language);
String subtitleLabel(SubtitleTrack t) => _label(t.id, t.title, t.language);

/// "English · SDH", else the language, else the track number.
String _label(String id, String? title, String? code) {
  final rawTitle = title?.trim() ?? '';
  final candidate = rawTitle.replaceFirst(RegExp(r'^\d+[\s_.-]+'), '');
  final match = RegExp(r'^([A-Za-z]+)(.*)$').firstMatch(candidate);
  final titleLanguage = match == null ? null : _knownLanguage(match[1]!);
  final language = _language(code) ?? titleLanguage;
  final detail = titleLanguage != null && titleLanguage == language
      ? match![2]!.replaceFirst(RegExp(r'^[\s_.·-]+'), '').trim()
      : rawTitle;
  final parts = [?language, if (detail.isNotEmpty) detail];
  return parts.isEmpty ? 'Track $id' : parts.join(' · ');
}

String? _knownLanguage(String value) {
  final lower = value.toLowerCase();
  final decoded = _language(lower);
  if (decoded != lower.toUpperCase()) return decoded;
  for (final name in subtitleLanguages) {
    if (name.toLowerCase() == lower) return name;
  }
  return null;
}

const subtitleLanguages = [
  'English',
  'Spanish',
  'French',
  'German',
  'Italian',
  'Portuguese',
  'Russian',
  'Japanese',
  'Korean',
  'Chinese',
  'Arabic',
  'Hindi',
  'Dutch',
  'Polish',
  'Turkish',
  'Swedish',
  'Danish',
  'Greek',
  'Czech',
  'Malay',
  'Finnish',
  'Hebrew',
  'Croatian',
];

String? _language(String? code) => switch (code?.trim().toLowerCase()) {
  null || '' || 'und' => null,
  'en' || 'eng' => 'English',
  'es' || 'spa' => 'Spanish',
  'fr' || 'fre' || 'fra' => 'French',
  'de' || 'ger' || 'deu' => 'German',
  'it' || 'ita' => 'Italian',
  'pt' || 'por' => 'Portuguese',
  'ru' || 'rus' => 'Russian',
  'ja' || 'jpn' => 'Japanese',
  'ko' || 'kor' => 'Korean',
  'zh' || 'chi' || 'zho' => 'Chinese',
  'ar' || 'ara' => 'Arabic',
  'hi' || 'hin' => 'Hindi',
  'nl' || 'dut' || 'nld' => 'Dutch',
  'pl' || 'pol' => 'Polish',
  'tr' || 'tur' => 'Turkish',
  'sv' || 'swe' => 'Swedish',
  'da' || 'dan' => 'Danish',
  'el' || 'ell' || 'gre' => 'Greek',
  'cs' || 'ces' || 'cze' => 'Czech',
  'ms' || 'msa' || 'may' => 'Malay',
  'fi' || 'fin' => 'Finnish',
  'he' || 'heb' => 'Hebrew',
  'hr' || 'hrv' => 'Croatian',
  _ => code!.trim().toUpperCase(),
};

/// Canonical language shared by track labels and automatic caption selection.
String? trackLanguage(String? title, String? code) {
  final metadata = code?.trim();
  if (metadata != null &&
      metadata.isNotEmpty &&
      metadata.toLowerCase() != 'und') {
    return _knownLanguage(metadata) ?? metadata.toUpperCase();
  }
  final candidate = (title ?? '').trim().replaceFirst(
    RegExp(r'^\d+[\s_.-]+'),
    '',
  );
  final first = RegExp(r'^([A-Za-z]+)(?:$|[\s_.·(-])').firstMatch(candidate);
  if (first != null) {
    final language = _knownLanguage(first[1]!);
    if (language != null) return language;
  }
  // Sidecars commonly append their language to the video filename.
  for (final token in candidate.split(RegExp(r'[\s_.\[\]()-]+')).reversed) {
    final language = _knownLanguage(token);
    if (language != null) return language;
  }
  return null;
}
