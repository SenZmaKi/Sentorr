import 'package:sentorr/torrents/release_traits.dart';
import 'package:test/test.dart';

void main() {
  test('scene names give origin, codec and HDR', () {
    final t = ReleaseTraits.of(
      'Dune.Part.Two.2024.2160p.WEB-DL.DV.HDR10.H.265',
    );
    expect(t.origin, VideoOrigin.web);
    expect(t.codec, VideoCodec.hevc);
    expect(t.hdr, isTrue);
  });

  test('a Blu-ray remux is a remux', () {
    final t = ReleaseTraits.of('Heat 1995 1080p BluRay REMUX AVC DTS-HD');
    expect(t.origin, VideoOrigin.remux);
    expect(t.codec, VideoCodec.h264);
    expect(t.hdr, isFalse);
  });

  test('camera copies are recognised', () {
    expect(ReleaseTraits.of('Film 2026 HDCAM x264').origin, VideoOrigin.cam);
    expect(ReleaseTraits.of('Film.2026.TS.XviD').origin, VideoOrigin.cam);
    expect(ReleaseTraits.of('Film.2026.TS.XviD').codec, VideoCodec.xvid);
  });

  test('words inside other words do not count', () {
    final t = ReleaseTraits.of('Cats and Dogs 2001 DTS Stereo');
    expect(t.origin, isNull);
    expect(t.codec, isNull);
    expect(t.hdr, isFalse);
  });
}
