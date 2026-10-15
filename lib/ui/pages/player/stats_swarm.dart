import '../../shared/title_format.dart';
import 'stats_readout.dart';

/// The torrent engine's own view, from `TorrentStreamSession.diagnose`:
/// whether the swarm can supply the pieces playback waits on, or the
/// engine is asking for the wrong ones.
class SwarmStats {
  SwarmStats(this._t);

  final Map<String, Object?>? _t;

  Object? _at(String section, String key, [String? inner]) {
    final value = (_t?[section] as Map?)?[key];
    return inner == null ? value : (value as Map?)?[inner];
  }

  num? _num(String section, String key, [String? inner]) =>
      _at(section, key, inner) as num?;

  String _n(String section, String key, [String? inner]) =>
      '${_num(section, key, inner) ?? '—'}';

  String _bytes(String section, String key) => switch (_num(section, key)) {
    final b? => sizeLabel(b.toInt()),
    null => '—',
  };

  String _ms(num? ms) =>
      ms == null ? '—' : '${(ms / 1000).toStringAsFixed(1)} s';

  Map<String, Object?>? get _window =>
      ((_t?['stream'] as Map?)?['window'] as Map?)?.cast<String, Object?>();
  Map<String, Object?>? get _reads =>
      ((_t?['stream'] as Map?)?['reads'] as Map?)?.cast<String, Object?>();
  List<Map> get _pending =>
      ((_reads?['pending'] as List?) ?? const []).cast<Map>();
  num? get _longestPending => _pending
      .map((p) => p['waitingMs'] as num)
      .fold<num?>(null, (a, b) => a == null || b > a ? b : a);

  bool get available => _t != null;

  List<StatsSection> get sections {
    if (_t == null) return const [];
    final sources = (_at('peers', 'bySource') as Map?) ?? const {};
    final top = ((_at('peers', 'top') as List?) ?? const []).cast<Map>();
    final requests =
        (((_t['stream'] as Map?)?['requests'] as List?) ?? const [])
            .cast<Map>();
    final last = requests.lastOrNull;
    return [
      (
        title: 'Swarm',
        rows: [
          (
            'Sending to us / choking us',
            '${_n('peers', 'sendingToUs')} / ${_n('peers', 'interestingButChoking')}',
          ),
          (
            'Connected / connecting',
            '${_n('peers', 'connected')} / ${_n('peers', 'connecting')}',
          ),
          (
            'Peers by source',
            [
              for (final MapEntry(:key, :value) in sources.entries)
                if (value != 0) '$key $value',
            ].join(' · ').ifEmpty('None'),
          ),
          (
            'uTP / encrypted / snubbed',
            '${_n('peers', 'utp')} / ${_n('peers', 'encrypted')} / ${_n('peers', 'snubbed')}',
          ),
          (
            'Swarm seeds / leechers',
            '${_n('swarm', 'seedsInSwarm')} / ${_n('swarm', 'leechersInSwarm')}',
          ),
          ('Availability (copies)', _n('swarm', 'distributedCopies')),
          (
            'Trackers',
            [
              _n('swarm', 'trackers'),
              if (_at('swarm', 'currentTracker') case final String host) host,
            ].join(' · '),
          ),
          (
            'DHT nodes / reachable',
            '${_n('session', 'dhtNodes')} / ${yesNo(_at('session', 'incomingConnections') as bool?)}'
                ' · port ${_n('session', 'listenPort')}',
          ),
          (
            'Overhead / wasted',
            '${_bytes('swarm', 'overheadDownBytesPerSecond')}/s / '
                '${sizeLabel(((_num('swarm', 'failedBytes') ?? 0) + (_num('swarm', 'redundantBytes') ?? 0)).toInt())}',
          ),
          if (top.firstOrNull case final p?)
            (
              'Fastest peer',
              '${(p['client'] as String?)?.ifEmpty('Unknown') ?? 'Unknown'} · '
                  '${sizeLabel((p['downBytesPerSecond'] as num).toInt())}/s · ${p['transport']}',
            ),
        ],
      ),
      (
        title: 'Pieces',
        rows: [
          (
            'Piece size / count',
            '${_bytes('pieces', 'length')} / ${_n('pieces', 'count')}',
          ),
          (
            'In flight (pieces / blocks)',
            '${_n('pieces', 'inFlight')} / ${_n('pieces', 'blocksRequested')} requested',
          ),
          ('With deadlines', _n('pieces', 'withDeadlines')),
          if (_window case final w?)
            (
              'Verified ahead / next missing',
              '${w['verifiedAhead']} pieces / '
                  '${w['nextMissingPiece'] == null ? 'none' : '#${w['nextMissingPiece']} (priority ${w['nextMissingPriority']})'}',
            ),
          if (_reads case final r?) ...[
            (
              'Read waits (count / total / slowest)',
              '${r['waits']} / ${_ms(r['waitedMs'] as num?)} / ${_ms(r['slowestMs'] as num?)}',
            ),
            (
              'Waiting now',
              _pending.isEmpty
                  ? 'Nothing'
                  : '${_pending.map((p) => '#${p['piece']}').join(', ')} · ${_ms(_longestPending)}',
            ),
          ],
          if (last != null)
            (
              'Last player request',
              '${sizeLabel((last['start'] as num).toInt())}+ · ${last['outcome']} · ${_ms(last['ms'] as num?)}',
            ),
        ],
      ),
    ];
  }

  Map<String, Object?> get metrics => _t == null
      ? const {}
      : {
          'sendingToUs': _num('peers', 'sendingToUs'),
          'chokingUs': _num('peers', 'interestingButChoking'),
          'connectedPeers': _num('peers', 'connected'),
          'connectingPeers': _num('peers', 'connecting'),
          'utpPeers': _num('peers', 'utp'),
          'snubbedPeers': _num('peers', 'snubbed'),
          'swarmSeeds': _num('swarm', 'seedsInSwarm'),
          'swarmLeechers': _num('swarm', 'leechersInSwarm'),
          'distributedCopies': _num('swarm', 'distributedCopies'),
          'dhtNodes': _num('session', 'dhtNodes'),
          'incomingConnections': _at('session', 'incomingConnections'),
          'overheadDownBytesPerSecond': _num(
            'swarm',
            'overheadDownBytesPerSecond',
          ),
          'failedBytes': _num('swarm', 'failedBytes'),
          'redundantBytes': _num('swarm', 'redundantBytes'),
          'piecesInFlight': _num('pieces', 'inFlight'),
          'blocksRequested': _num('pieces', 'blocksRequested'),
          'deadlinePieces': _num('pieces', 'withDeadlines'),
          'verifiedAheadPieces': _window?['verifiedAhead'],
          'nextMissingPiece': _window?['nextMissingPiece'],
          'readWaits': _reads?['waits'],
          'readWaitedMs': _reads?['waitedMs'],
          'slowestReadMs': _reads?['slowestMs'],
          'pendingReads': _reads == null ? null : _pending.length,
          'longestPendingReadMs': _longestPending,
        };
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
