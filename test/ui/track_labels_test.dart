import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sentorr/ui/pages/player/track_labels.dart';

void main() {
  test('recognizes numbered subtitle names and codes from sidecars', () {
    const labels = {
      '6_Danish': 'Danish',
      '7_German': 'German',
      '8_Greek': 'Greek',
      '9_Spanish': 'Spanish',
      '4_Arabic': 'Arabic',
      '5_Czech': 'Czech',
      '3_English': 'English',
      '22_may': 'Malay',
      '10_Spanish': 'Spanish',
      '11_Spanish': 'Spanish',
      '12_Spanish': 'Spanish',
      '13_Finnish': 'Finnish',
      '14_French': 'French',
      '15_Hebrew': 'Hebrew',
      '16_hrv': 'Croatian',
    };
    for (final entry in labels.entries) {
      expect(subtitleLabel(SubtitleTrack('1', entry.key, null)), entry.value);
    }
  });

  test('preserves variants, unknown titles and authoritative metadata', () {
    expect(
      subtitleLabel(const SubtitleTrack('1', '3_English_SDH', 'eng')),
      'English · SDH',
    );
    expect(
      subtitleLabel(const SubtitleTrack('1', ' 03-English Forced ', 'und')),
      'English · Forced',
    );
    expect(
      subtitleLabel(const SubtitleTrack('1', '3_English', 'fra')),
      'French · 3_English',
    );
    expect(
      subtitleLabel(const SubtitleTrack('1', '22_unknown', null)),
      '22_unknown',
    );
    expect(
      subtitleLabel(const SubtitleTrack('1', 'Englishman', null)),
      'Englishman',
    );
    expect(subtitleLabel(const SubtitleTrack('2', ' ', 'und')), 'Track 2');
    expect(audioLabel(const AudioTrack('1', 'English', ' en ')), 'English');
  });
}
