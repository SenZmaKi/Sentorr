import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('sentorr.net.mobile_data');

/// The device's links as the platform reports them; tests override it.
final connectionKindsProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) async* {
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

/// Whether traffic goes over mobile data: a cellular link with no Wi-Fi or
/// Ethernet beside it. Platforms report the link, not whether it is
/// metered, so a phone's Wi-Fi hotspot counts as Wi-Fi. Unknown reads as
/// not mobile, as on desktops where the plugin is unavailable.
final onMobileDataProvider = Provider<bool>((ref) {
  final kinds = ref.watch(connectionKindsProvider).value ?? const [];
  final mobile =
      kinds.contains(ConnectivityResult.mobile) &&
      !kinds.contains(ConnectivityResult.wifi) &&
      !kinds.contains(ConnectivityResult.ethernet);
  _log.fine('Links ${kinds.map((k) => k.name).join(', ')}: mobile $mobile');
  return mobile;
});
