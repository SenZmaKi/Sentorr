import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/ui/pages/player/nerd_stats_sections.dart';
import 'package:sentorr/ui/pages/player/stats_swarm.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

/// The shape `TorrentStreamSession.diagnose` returns.
final Map<String, Object?> diagnosis = {
  'swarm': {
    'seedsInSwarm': 40,
    'leechersInSwarm': null,
    'distributedCopies': 3.5,
    'trackers': 4,
    'currentTracker': 'tracker.example',
    'failedBytes': 1024,
    'redundantBytes': 1024,
    'overheadDownBytesPerSecond': 2048,
  },
  'session': {
    'dhtNodes': 120,
    'incomingConnections': false,
    'listenPort': 6881,
  },
  'peers': {
    'connected': 9,
    'connecting': 3,
    'sendingToUs': 4,
    'interestingButChoking': 5,
    'utp': 2,
    'encrypted': 1,
    'snubbed': 0,
    'bySource': {'tracker': 6, 'dht': 3, 'pex': 0},
    'top': [
      {
        'client': 'qBittorrent',
        'downBytesPerSecond': 1048576,
        'transport': 'utp',
      },
    ],
  },
  'pieces': {
    'length': 1048576,
    'count': 900,
    'inFlight': 6,
    'blocksRequested': 40,
    'withDeadlines': 4,
  },
  'stream': {
    'window': {
      'verifiedAhead': 3,
      'nextMissingPiece': 120,
      'nextMissingPriority': 7,
    },
    'reads': {
      'waits': 12,
      'waitedMs': 9000,
      'slowestMs': 4200,
      'pending': [
        {'piece': 120, 'waitingMs': 2500},
      ],
    },
    'requests': [
      {'start': 524288, 'outcome': 'open', 'ms': 1500},
    ],
  },
};

void main() {
  test('headline swarm numbers become flat recorded metrics', () {
    final metrics = SwarmStats(diagnosis).metrics;
    expect(metrics['sendingToUs'], 4);
    expect(metrics['chokingUs'], 5);
    expect(metrics['swarmLeechers'], isNull);
    expect(metrics['nextMissingPiece'], 120);
    expect(metrics['pendingReads'], 1);
    expect(metrics['longestPendingReadMs'], 2500);
    expect(metrics['incomingConnections'], false);
    expect(SwarmStats(null).metrics, isEmpty);
    expect(SwarmStats(null).sections, isEmpty);
  });

  testWidgets('swarm and piece rows render from an engine diagnosis', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildSentorrTheme(Brightness.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatsSectionList(
              sections: SwarmStats(diagnosis).sections,
              columns: 2,
            ),
          ),
        ),
      ),
    );
    expect(find.text('SWARM'), findsOneWidget);
    expect(find.text('PIECES'), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);
    expect(find.text('tracker 6 · dht 3'), findsOneWidget);
    expect(find.text('4 · tracker.example'), findsOneWidget);
    expect(find.text('3 pieces / #120 (priority 7)'), findsOneWidget);
    expect(find.text('#120 · 2.5 s'), findsOneWidget);
    expect(find.textContaining('qBittorrent'), findsOneWidget);
  });
}
