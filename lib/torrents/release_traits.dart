/// Where a release's video came from, roughly best to worst.
enum VideoOrigin {
  remux('Remux'),
  bluRay('Blu-ray'),
  web('WEB'),
  hdtv('HDTV'),
  dvd('DVD'),
  cam('CAM');

  const VideoOrigin(this.label);
  final String label;
}

enum VideoCodec {
  av1('AV1'),
  hevc('HEVC'),
  h264('H.264'),
  xvid('XviD');

  const VideoCodec(this.label);
  final String label;
}

/// What a release name says about its video beyond resolution. Release
/// names are free text, so any trait may be missing.
class ReleaseTraits {
  const ReleaseTraits({this.origin, this.codec, this.hdr = false});

  final VideoOrigin? origin;
  final VideoCodec? codec;

  /// HDR10, HDR10+ or Dolby Vision.
  final bool hdr;

  static ReleaseTraits of(String name) {
    final text = name.replaceAll(RegExp(r'[._\[\]()]'), ' ');
    bool has(String pattern) =>
        RegExp('\\b(?:$pattern)\\b', caseSensitive: false).hasMatch(text);
    return ReleaseTraits(
      // Remux before Blu-ray: "BluRay REMUX" is both.
      origin: has('remux|bdremux')
          ? VideoOrigin.remux
          : has('blu-?ray|bdrip|brrip|bd25|bd50')
          ? VideoOrigin.bluRay
          : has('web-?dl|web-?rip|web|amzn|nf|dsnp|hmax|atvp')
          ? VideoOrigin.web
          : has('hdtv|pdtv|dsr|tvrip')
          ? VideoOrigin.hdtv
          : has('dvd-?rip|dvd|dvd5|dvd9')
          ? VideoOrigin.dvd
          : has('cam|camrip|hdcam|ts|telesync|hdts|hd-ts|tc|telecine')
          ? VideoOrigin.cam
          : null,
      codec: has('av1')
          ? VideoCodec.av1
          : has('x265|h ?265|h\\.265|hevc')
          ? VideoCodec.hevc
          : has('x264|h ?264|h\\.264|avc')
          ? VideoCodec.h264
          : has('xvid|divx')
          ? VideoCodec.xvid
          : null,
      hdr: has('hdr|hdr10|hdr10\\+|dv|dovi|dolby ?vision'),
    );
  }
}
