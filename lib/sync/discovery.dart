import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:logging/logging.dart';

import 'identity.dart';
import 'models.dart';

final _log = Logger('sentorr.sync.discovery');

const _type = '_sentorr._tcp';

/// Announces this device over mDNS and lists the other Sentorrs on the
/// network. Failures are logged, never thrown: devices can still be
/// reached by address.
class LocalDiscovery {
  LocalDiscovery({required this.identity, required this.port, this.onChanged});
  DeviceIdentity identity;
  final int port;

  /// The devices found changed.
  final void Function(Map<String, NearbyDevice> nearby)? onChanged;

  final _nearby = <String, NearbyDevice>{};

  /// Service names to device ids, since a lost service carries only its name.
  final _names = <String, String>{};
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _events;
  bool _pairing = false;

  Map<String, NearbyDevice> get nearby => Map.unmodifiable(_nearby);

  Future<void> start() async {
    await _announce();
    try {
      final discovery = _discovery = BonsoirDiscovery(type: _type);
      await discovery.initialize();
      _events = discovery.eventStream?.listen(
        (e) => _onEvent(discovery, e),
        onError: (Object error) => _log.warning('Discovery failed', error),
      );
      await discovery.start();
    } catch (error, stack) {
      _log.warning('Discovery unavailable', error, stack);
    }
  }

  /// Announces whether this device is open for pairing.
  Future<void> setPairing(bool open) async {
    if (open == _pairing) return;
    _pairing = open;
    await _announce();
  }

  /// Announces under [renamed]'s name from now on.
  Future<void> rename(DeviceIdentity renamed) async {
    identity = renamed;
    await _announce();
  }

  /// Announcements in order, so a quick close and reopen cannot overlap.
  Future<void> _announcing = Future.value();

  Future<void> _announce() =>
      _announcing = _announcing.then((_) => _replaceBroadcast());

  Future<void> _replaceBroadcast() async {
    try {
      await _broadcast?.stop();
      final broadcast = _broadcast = BonsoirBroadcast(
        service: BonsoirService(
          name: identity.name,
          type: _type,
          port: port,
          attributes: {'id': identity.id, 'v': '1', if (_pairing) 'pair': '1'},
        ),
      );
      await broadcast.initialize();
      await broadcast.start();
    } catch (error, stack) {
      _log.warning('Could not announce this device', error, stack);
    }
  }

  void _onEvent(BonsoirDiscovery discovery, BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent(:final service):
      case BonsoirDiscoveryServiceUpdatedEvent(:final service):
        if (service.attributes['id'] != identity.id) {
          service.resolve(discovery.serviceResolver);
        }
      case BonsoirDiscoveryServiceResolvedEvent(:final service):
        final id = service.attributes['id'];
        final host = _pickHost(service.hostAddresses);
        if (id == null || id == identity.id || host == null) return;
        _names[service.name] = id;
        _nearby[id] = NearbyDevice(
          id: id,
          name: service.name,
          address: (host: host, port: service.port),
          pairing: service.attributes['pair'] == '1',
        );
        _log.fine('Found ${service.name} at $host:${service.port}');
        onChanged?.call(nearby);
      case BonsoirDiscoveryServiceLostEvent(:final service):
        final id = _names.remove(service.name);
        if (id != null && _nearby.remove(id) != null) onChanged?.call(nearby);
      default:
    }
  }

  /// An IPv4 address when there is one; a link-local v6 one needs a zone
  /// that URIs cannot carry portably.
  static String? _pickHost(List<String> addresses) {
    final parsed = addresses.map(InternetAddress.tryParse).nonNulls;
    return (parsed
                .where((a) => a.type == InternetAddressType.IPv4)
                .firstOrNull ??
            parsed.where((a) => !a.isLinkLocal).firstOrNull)
        ?.address;
  }

  Future<void> stop() async {
    await _events?.cancel();
    try {
      await _discovery?.stop();
      await _broadcast?.stop();
    } catch (error) {
      _log.fine('Stopping discovery failed: $error');
    }
  }
}
