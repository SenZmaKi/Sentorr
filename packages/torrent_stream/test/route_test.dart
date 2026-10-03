import 'package:libtorrent_dart/libtorrent_dart.dart';
import 'package:test/test.dart';
import 'package:torrent_stream/src/engine/native_session.dart';
import 'package:torrent_stream/torrent_stream.dart';

void main() {
  test(
    'binds to the interface and proxies from the start, then clears',
    () async {
      final native = NativeSession(
        const TorrentEngineSettings(
          listenInterfaces: '127.0.0.1:0',
          networkInterface: 'wg0',
          proxy: TorrentProxy(
            kind: TorrentProxyKind.socks5,
            host: ' proxy.example ',
            port: 1080,
            username: 'user',
            password: 'secret',
          ),
        ),
      );
      addTearDown(native.close);
      final s = native.session;
      expect(
        s.getStringSetting(LibtorrentSettingsTag.listenInterfaces),
        'wg0:0',
      );
      expect(s.getStringSetting(4), 'wg0');
      expect(
        s.getIntSetting(LibtorrentSettingsTag.proxyType),
        LibtorrentProxyType.socks5Password,
      );
      expect(
        s.getStringSetting(LibtorrentSettingsTag.proxyHostname),
        'proxy.example',
      );
      expect(s.getIntSetting(LibtorrentSettingsTag.proxyPort), 1080);
      expect(s.getStringSetting(LibtorrentSettingsTag.proxyPassword), 'secret');

      native.configure(
        const TorrentEngineSettings(listenInterfaces: '127.0.0.1:0'),
      );
      expect(
        s.getStringSetting(LibtorrentSettingsTag.listenInterfaces),
        '127.0.0.1:0',
      );
      expect(s.getStringSetting(4), '');
      expect(
        s.getIntSetting(LibtorrentSettingsTag.proxyType),
        LibtorrentProxyType.none,
      );
      expect(s.getStringSetting(LibtorrentSettingsTag.proxyHostname), '');
    },
  );

  test(
    'SOCKS4 sends no password and HTTP without a login skips auth',
    () async {
      final native = NativeSession(
        const TorrentEngineSettings(
          listenInterfaces: '127.0.0.1:0',
          proxy: TorrentProxy(
            kind: TorrentProxyKind.socks4,
            host: 'h',
            port: 1,
            username: 'u',
            password: 'p',
          ),
        ),
      );
      addTearDown(native.close);
      final s = native.session;
      expect(s.getStringSetting(LibtorrentSettingsTag.proxyPassword), '');
      native.configure(
        const TorrentEngineSettings(
          listenInterfaces: '127.0.0.1:0',
          proxy: TorrentProxy(
            kind: TorrentProxyKind.http,
            host: 'h',
            port: 8080,
          ),
        ),
      );
      expect(
        s.getIntSetting(LibtorrentSettingsTag.proxyType),
        LibtorrentProxyType.http,
      );
    },
  );
}
