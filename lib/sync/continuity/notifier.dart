import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../player/continuity_receive.dart';
import '../../player/session.dart';
import '../peer_file.dart';
import '../devices.dart';
import '../peers.dart';
import '../service.dart';
import 'receiver.dart';
import 'session.dart';

class ContinuityOffer {
  const ContinuityOffer(this.deviceId, this.deviceName, this.session);
  final String deviceId, deviceName;
  final ContinuitySession session;
  String get key => '$deviceId:${session.id}';
}

final continuityOffersProvider =
    NotifierProvider.autoDispose<ContinuityOffers, List<ContinuityOffer>>(
      ContinuityOffers.new,
    );

/// Poll only while the home entry point is mounted. Each result is a fresh
/// observation, so failed peers disappear rather than keeping stale prompts.
class ContinuityOffers extends Notifier<List<ContinuityOffer>> {
  Future<void>? _refreshing;
  Timer? _poll;
  int _epoch = 0;
  final _dismissed = <String>{};
  @override
  List<ContinuityOffer> build() {
    ref.onDispose(() => _poll?.cancel());
    ref.listen(devicesProvider, (_, _) {
      _epoch++;
      // Resuming a hidden consumer can flush device changes during build.
      // Invalidate in-flight requests now, but publish after that build ends.
      Future.microtask(() {
        if (!ref.mounted) return;
        state = state
            .where((o) => ref.read(devicesProvider).byId(o.deviceId) != null)
            .toList();
        _schedule();
      });
    });
    _schedule();
    return const [];
  }

  void _schedule() {
    if (ref.read(devicesProvider).paired.isEmpty) {
      _poll?.cancel();
      _poll = null;
    } else {
      _poll ??= Timer.periodic(const Duration(seconds: 3), (_) => refresh());
      Future.microtask(refresh);
    }
  }

  void dismiss(ContinuityOffer offer) {
    _dismissed.add(offer.key);
    state = state.where((o) => o.key != offer.key).toList();
  }

  Future<void> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<void> _refresh() async {
    if (!ref.mounted) return;
    final epoch = _epoch;
    final devices = ref.read(devicesProvider).paired;
    if (devices.isEmpty) {
      state = const [];
      return;
    }
    final service = ref.read(syncServiceProvider);
    final offers = await Future.wait([
      for (final device in devices)
        () async {
          final route = ref.read(peersProvider.notifier).route(device.id);
          if (route == null) return null;
          try {
            final answer = await service.client.call(
              route.address,
              route.fingerprint,
              '/v1/continuity',
              timeout: const Duration(seconds: 2),
            );
            final session = ContinuitySession.fromResponse(answer);
            return session == null
                ? null
                : ContinuityOffer(device.id, device.name, session);
          } on Object {
            return null;
          }
        }(),
    ]);
    if (ref.mounted && epoch == _epoch) {
      state = offers.nonNulls
          .where((o) => !_dismissed.contains(o.key))
          .toList();
    }
  }
}

final continuityTransferProvider =
    NotifierProvider<ContinuityTransfer, AsyncValue<void>>(
      ContinuityTransfer.new,
    );

class ContinuityTransfer extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> take(ContinuityOffer offer) async {
    if (state.isLoading || ref.read(playerSessionProvider) != null) return;
    final devices = ref.read(devicesProvider);
    final fingerprint = devices.byId(offer.deviceId)?.fingerprint;
    final route = ref.read(peersProvider.notifier).route(offer.deviceId);
    if (route == null || fingerprint == null) return;
    final playback = ContinuityPlayback(ref);
    var preparing = false;
    var sourcePaused = false;
    state = const AsyncLoading();
    try {
      final service = ref.read(syncServiceProvider);
      await receiveContinuity(
        client: service.client,
        route: route,
        sessionId: offer.session.id,
        handoffId: Random.secure().nextInt(1 << 32).toRadixString(16),
        current: () =>
            ref.mounted &&
            ref.read(devicesProvider).byId(offer.deviceId)?.fingerprint ==
                fingerprint &&
            (!preparing || playback.current),
        prepare: (session) async {
          final source = peerFileForOffer(
            service,
            offer.deviceId,
            offer.deviceName,
            session.media,
          );
          if (source == null) {
            throw StateError('Device streaming is unavailable');
          }
          String? captionData;
          if (session.settings?.item.subtitle?.file == true) {
            final caption = await service.client.call(
              route.address,
              route.fingerprint,
              '/v1/continuity/caption',
              body: {'session': session.id},
            );
            final data = caption['data'];
            if (data is! String || data.length > 512 * 1024) {
              throw const FormatException('Invalid caption transfer');
            }
            captionData = data;
          }
          preparing = true;
          await playback.prepare(
            session,
            source.withCaption(
              data: captionData,
              title: session.settings?.item.subtitle?.title,
              enabled: session.settings?.item.captionsEnabled,
            ),
          );
          sourcePaused = true;
        },
        start: (position) async {
          sourcePaused = true;
          await playback.start(position);
        },
      );
      if (ref.mounted) state = const AsyncData(null);
    } catch (error, stack) {
      playback.close();
      if (ref.mounted) {
        state = AsyncError(
          sourcePaused
              ? StateError(
                  '$error The other player may be paused; press Play there to resume.',
                )
              : error,
          stack,
        );
      }
    }
  }
}
