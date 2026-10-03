import 'dart:math';

import 'package:flutter/material.dart';

import '../components/status.dart';

/// Fictional catalog entries; artwork is generated so the demo ships no images.
class SampleTitle {
  const SampleTitle(this.title, this.year, this.kind, this.hue);

  final String title;
  final int year;
  final String kind;
  final double hue;

  String get metadata => '$year · $kind';
}

const sampleTitles = [
  SampleTitle('The Quiet Orbit', 2025, 'Movie', 210),
  SampleTitle('Harbor Lights', 2024, 'Series', 28),
  SampleTitle('Glass Meridian', 2026, 'Movie', 280),
  SampleTitle('Northbound', 2023, 'Series', 160),
  SampleTitle('Ember & Ash', 2025, 'Movie', 8),
  SampleTitle('Paper Moons', 2022, 'Movie', 48),
  SampleTitle('Signal Lost', 2026, 'Series', 190),
  SampleTitle('Low Tide', 2024, 'Movie', 330),
  SampleTitle('Copper Valley', 2021, 'Series', 36),
  SampleTitle('Afterglow', 2025, 'Movie', 300),
  SampleTitle('The Long Field', 2023, 'Movie', 95),
  SampleTitle('Static Bloom', 2026, 'Series', 250),
];

class SampleTorrent {
  const SampleTorrent(
    this.filename,
    this.quality,
    this.size,
    this.seeders,
    this.status,
  );

  final String filename;
  final List<String> quality;
  final String size;
  final int seeders;
  final TransferStatus status;
}

const sampleTorrents = [
  SampleTorrent(
    'The.Quiet.Orbit.2025.2160p.WEB-DL.DDP5.1.HDR.HEVC.mkv',
    ['2160p', 'HDR', 'HEVC'],
    '18.42 GB',
    412,
    TransferStatus.active,
  ),
  SampleTorrent(
    'The.Quiet.Orbit.2025.1080p.BluRay.x264.AAC.mp4',
    ['1080p', 'x264'],
    '4.10 GB',
    1287,
    TransferStatus.ready,
  ),
  SampleTorrent(
    'The.Quiet.Orbit.2025.1080p.WEB.H265.10bit.mkv',
    ['1080p', 'H265'],
    '2.36 GB',
    96,
    TransferStatus.buffering,
  ),
  SampleTorrent(
    'The.Quiet.Orbit.2025.720p.WEBRip.x264.mp4',
    ['720p', 'x264'],
    '1.02 GB',
    8,
    TransferStatus.waiting,
  ),
  SampleTorrent(
    'The.Quiet.Orbit.2025.REMUX.2160p.DV.TrueHD.Atmos.mkv',
    ['2160p', 'DV', 'REMUX'],
    '61.80 GB',
    0,
    TransferStatus.failed,
  ),
  SampleTorrent(
    'The.Quiet.Orbit.2025.480p.DVDRip.XviD.avi',
    ['480p', 'XviD'],
    '702 MB',
    21,
    TransferStatus.queued,
  ),
];

/// Generated artwork. Artwork supplies the color; chrome stays neutral.
class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.hue, this.seed = 0, this.label});

  final double hue;
  final int seed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ArtworkPainter(hue, seed),
      child: const SizedBox.expand(),
    );
  }
}

class _ArtworkPainter extends CustomPainter {
  _ArtworkPainter(this.hue, this.seed);

  final double hue;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = HSLColor.fromAHSL(1, hue, 0.45, 0.22).toColor();
    final glow = HSLColor.fromAHSL(1, (hue + 35) % 360, 0.65, 0.55).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glow, base, const Color(0xFF050505)],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    final rnd = Random(hue.toInt() * 31 + seed);
    final sun = Offset(
      size.width * (0.25 + rnd.nextDouble() * 0.5),
      size.height * (0.28 + rnd.nextDouble() * 0.15),
    );
    canvas.drawCircle(
      sun,
      size.shortestSide * 0.22,
      Paint()
        ..color = HSLColor.fromAHSL(
          0.85,
          (hue + 60) % 360,
          0.9,
          0.75,
        ).toColor(),
    );
    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.55 + i * 0.1);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += size.width / 6) {
        path.lineTo(x, y - rnd.nextDouble() * size.height * 0.12);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = HSLColor.fromAHSL(1, hue, 0.35, 0.16 - i * 0.04).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_ArtworkPainter old) => old.hue != hue || old.seed != seed;
}
