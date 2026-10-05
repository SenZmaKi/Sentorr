import 'package:flutter_test/flutter_test.dart';
import 'package:sentorr/following/notifier.dart';
import 'package:sentorr/player/models.dart';
import 'package:sentorr/sync/devices.dart';
import 'package:sentorr/sync/pairing.dart';
import 'package:sentorr/sync/peers.dart';
import 'package:sentorr/watching/notifier.dart';

import '../support/fake_imdb.dart';
import 'harness.dart';

void main() {
  test(
    'pairs over the network once both viewers confirm, then syncs',
    () async {
      final laptop = await syncDevice('Laptop'),
          phone = await syncDevice('Phone');
      final (onLaptop, onPhone) = await compareCodes(laptop, phone);
      expect(onLaptop.code, onPhone.code);
      expect(onLaptop.peerName, 'Phone');
      expect(onPhone.peerName, 'Laptop');

      await laptop.read(pairingProvider.notifier).decide(true);
      final joined = phone.read(pairingProvider.notifier).decide(true);
      await until(
        () =>
            laptop.read(pairingProvider) is PairingDone &&
            phone.read(pairingProvider) is PairingDone,
      );
      await joined;
      final laptopId = laptop.read(devicesProvider).identity.id;
      final phoneId = phone.read(devicesProvider).identity.id;
      expect(laptop.read(devicesProvider).byId(phoneId), isNotNull);
      expect(phone.read(devicesProvider).byId(laptopId), isNotNull);

      final series = fakeTitle(2, series: true);
      await laptop
          .read(watchHistoryProvider.notifier)
          .record(
            PlaybackItem(title: fakeTitle(1)),
            position: const Duration(minutes: 30),
            duration: const Duration(minutes: 90),
          );
      await laptop
          .read(followedSeriesProvider.notifier)
          .record(
            PlaybackItem(
              title: fakeTitle(3),
              series: series,
              season: 1,
              episode: 4,
            ),
            position: const Duration(minutes: 40),
            duration: const Duration(minutes: 45),
          );

      await phone.read(peersProvider.notifier).syncWith(laptopId);
      expect(phone.read(peersProvider)[laptopId]?.online, true);
      expect(
        phone.read(watchHistoryProvider).single.position,
        const Duration(minutes: 30),
      );
      expect(phone.read(followedSeriesProvider).single.reached, (
        season: 1,
        episode: 4,
      ));

      // And back: the laptop reaches the phone where it called from.
      await phone.read(followedSeriesProvider.notifier).unfollow(series.id);
      await laptop.read(peersProvider.notifier).syncWith(phoneId);
      expect(laptop.read(peersProvider)[phoneId]?.online, true);
      expect(laptop.read(followedSeriesProvider), isEmpty);
    },
  );

  test('either viewer rejecting the code pairs nothing', () async {
    final laptop = await syncDevice('Laptop'),
        phone = await syncDevice('Phone');
    await compareCodes(laptop, phone);
    await phone.read(pairingProvider.notifier).decide(false);
    await until(() => laptop.read(pairingProvider) is PairingFailed);
    expect(phone.read(pairingProvider), isA<PairingFailed>());
    expect(laptop.read(devicesProvider).paired, isEmpty);
    expect(phone.read(devicesProvider).paired, isEmpty);
  });

  test('a device that is not open for pairing refuses', () async {
    final laptop = await syncDevice('Laptop'),
        phone = await syncDevice('Phone');
    await phone.read(pairingProvider.notifier).join(addressOf(laptop));
    expect(phone.read(pairingProvider), isA<PairingFailed>());
  });

  test('a host whose joiner backs out waits for another', () async {
    final laptop = await syncDevice('Laptop'),
        phone = await syncDevice('Phone');
    await compareCodes(laptop, phone);
    // The joiner closes its sheet before choosing.
    phone.read(pairingProvider.notifier).close();
    await until(() => laptop.read(pairingProvider) is PairingFailed);
    expect(laptop.read(devicesProvider).paired, isEmpty);
    // Pairing can be started again straight away.
    laptop.read(pairingProvider.notifier).open();
    expect(laptop.read(pairingProvider), isA<PairingOpen>());
  });
}
