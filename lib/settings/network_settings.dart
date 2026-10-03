import 'package:torrent_stream/torrent_stream.dart';

import 'json.dart';

/// The one torrent session's limits and peer discovery, shared by streams
/// and downloads.
class NetworkSettings {
  const NetworkSettings({
    this.downloadLimitBytesPerSecond = 0,
    this.uploadLimitBytesPerSecond = 0,
    this.maxConnections = 200,
    this.utp = true,
    this.dht = true,
    this.lsd = true,
    this.upnp = true,
    this.natPmp = true,
    this.proxy = const ProxySettings(),
    this.networkInterface,
  });

  /// Zero means unlimited.
  final int downloadLimitBytesPerSecond, uploadLimitBytesPerSecond;
  final int maxConnections;

  /// Also reach peers over uTP, not only TCP.
  final bool utp;

  /// Peer discovery: the distributed hash table, the local network, and
  /// opening a port on the router.
  final bool dht, lsd, upnp, natPmp;

  final ProxySettings proxy;

  /// The device all torrent traffic is bound to, usually a VPN's, e.g.
  /// `utun4` or `wg0`. Null uses any.
  final String? networkInterface;

  NetworkSettings copyWith({
    int? downloadLimitBytesPerSecond,
    int? uploadLimitBytesPerSecond,
    int? maxConnections,
    bool? utp,
    bool? dht,
    bool? lsd,
    bool? upnp,
    bool? natPmp,
    ProxySettings? proxy,
    String? networkInterface,
    bool anyInterface = false,
  }) => NetworkSettings(
    downloadLimitBytesPerSecond:
        downloadLimitBytesPerSecond ?? this.downloadLimitBytesPerSecond,
    uploadLimitBytesPerSecond:
        uploadLimitBytesPerSecond ?? this.uploadLimitBytesPerSecond,
    maxConnections: maxConnections ?? this.maxConnections,
    utp: utp ?? this.utp,
    dht: dht ?? this.dht,
    lsd: lsd ?? this.lsd,
    upnp: upnp ?? this.upnp,
    natPmp: natPmp ?? this.natPmp,
    proxy: proxy ?? this.proxy,
    networkInterface: anyInterface
        ? null
        : networkInterface ?? this.networkInterface,
  );

  /// [legacy] is the streaming settings these limits used to live in.
  factory NetworkSettings.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic> legacy = const {},
  }) {
    const d = NetworkSettings();
    return NetworkSettings(
      downloadLimitBytesPerSecond: jsonInt(
        json['downloadLimitBytesPerSecond'] ??
            legacy['downloadLimitBytesPerSecond'],
        d.downloadLimitBytesPerSecond,
      ),
      uploadLimitBytesPerSecond: jsonInt(
        json['uploadLimitBytesPerSecond'],
        d.uploadLimitBytesPerSecond,
      ),
      maxConnections: jsonInt(
        json['maxConnections'],
        d.maxConnections,
        min: 10,
        max: 2000,
      ),
      utp: jsonBool(json['utp'] ?? legacy['utp'], d.utp),
      dht: jsonBool(json['dht'], d.dht),
      lsd: jsonBool(json['lsd'], d.lsd),
      upnp: jsonBool(json['upnp'], d.upnp),
      natPmp: jsonBool(json['natPmp'], d.natPmp),
      proxy: ProxySettings.fromJson(jsonObject(json['proxy'])),
      networkInterface: switch (json['networkInterface']) {
        final String name when name.trim().isNotEmpty => name.trim(),
        _ => null,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'downloadLimitBytesPerSecond': downloadLimitBytesPerSecond,
    'uploadLimitBytesPerSecond': uploadLimitBytesPerSecond,
    'maxConnections': maxConnections,
    'utp': utp,
    'dht': dht,
    'lsd': lsd,
    'upnp': upnp,
    'natPmp': natPmp,
    'proxy': proxy.toJson(),
    'networkInterface': networkInterface,
  };
}

/// A proxy for torrent traffic. Credentials live in the system keychain
/// outside debug builds; see `SettingsRepository`.
class ProxySettings {
  const ProxySettings({
    this.kind = TorrentProxyKind.none,
    this.host = '',
    this.port = 1080,
    this.username = '',
    this.password = '',
  });

  final TorrentProxyKind kind;
  final String host;
  final int port;
  final String username, password;

  bool get enabled => kind != TorrentProxyKind.none;

  TorrentProxy get engine => TorrentProxy(
    kind: kind,
    host: host,
    port: port,
    username: username,
    password: password,
  );

  ProxySettings copyWith({
    TorrentProxyKind? kind,
    String? host,
    int? port,
    String? username,
    String? password,
  }) => ProxySettings(
    kind: kind ?? this.kind,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    password: password ?? this.password,
  );

  factory ProxySettings.fromJson(Map<String, dynamic> json) {
    const d = ProxySettings();
    String text(Object? value) => value is String ? value : '';
    return ProxySettings(
      kind: jsonEnum(TorrentProxyKind.values, json['kind'], d.kind),
      host: text(json['host']).trim(),
      port: jsonInt(json['port'], d.port, min: 1, max: 65535),
      username: text(json['username']),
      password: text(json['password']),
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
  };
}
