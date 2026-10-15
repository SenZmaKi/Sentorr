import '../../../player/stats_recording.dart';

typedef StatsRow = (String, String);
typedef StatsSection = ({String title, List<StatsRow> rows});

/// The latest native property values, read as display text or typed values.
extension type const NativeReadout(Map<String, String> values) {
  String operator [](String key) => values[key] ?? 'Waiting';
  Object? typed(String key) => StatsRecording.typed(values[key]);
  bool? flag(String key) => switch (values[key]) {
    'yes' || 'true' => true,
    'no' || 'false' => false,
    _ => null,
  };

  /// Bits/s as "4.2 Mb/s".
  String bitrate(String key) => switch (num.tryParse(values[key] ?? '')) {
    null => this[key],
    final b when b >= 1e6 => '${(b / 1e6).toStringAsFixed(1)} Mb/s',
    final b => '${(b / 1e3).round()} kb/s',
  };
}

String yesNo(bool? value) => switch (value) {
  true => 'Yes',
  false => 'No',
  null => 'Unavailable',
};
