import 'dart:io';

/// Lab knobs; Mbps is decimal megabits, native rate limits are bytes/second.
class StreamingProfile {
  const StreamingProfile({
    this.bufferSeconds = 60,
    this.resumeSeconds = 10,
    this.readAheadMiB = 16,
    this.downloadMbps = 40,
  });
  factory StreamingProfile.environment() {
    int value(String name, int fallback, int minimum, int maximum) =>
        (int.tryParse(Platform.environment[name] ?? '') ?? fallback).clamp(
          minimum,
          maximum,
        );
    return StreamingProfile(
      bufferSeconds: value('STREAMING_BUFFER_SECONDS', 60, 5, 120),
      resumeSeconds: value('STREAMING_RESUME_SECONDS', 10, 1, 30),
      readAheadMiB: value('STREAMING_READAHEAD_MIB', 16, 1, 64),
      downloadMbps: value('STREAMING_DOWNLOAD_MBPS', 40, 0, 1000),
    );
  }
  final int bufferSeconds, resumeSeconds, readAheadMiB, downloadMbps;
  Map<String, int> toJson() => {
    'bufferSeconds': bufferSeconds,
    'resumeSeconds': resumeSeconds,
    'readAheadMiB': readAheadMiB,
    'downloadMbps': downloadMbps,
  };
}
