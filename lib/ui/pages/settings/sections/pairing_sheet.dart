import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../sync/devices.dart';
import '../../../../sync/models.dart';
import '../../../../sync/pairing.dart';
import '../../../../sync/server.dart';
import '../../../../sync/service.dart';
import '../../../components/adaptive_sheet.dart';
import '../../../components/buttons.dart';
import '../../../components/dialog_actions.dart';
import '../../../components/inputs.dart';
import '../../../shared/theme/theme.dart';

/// Pairs this device with another: wait for one, or join one, then both
/// viewers confirm the same six digits.
Future<void> showPairingSheet(BuildContext context, WidgetRef ref) async {
  await showAdaptiveSheet<void>(
    context,
    maxWidth: 480,
    builder: (_) => const _PairingSheet(),
  );
  final pairing = ref.read(pairingProvider.notifier);
  // Closing the sheet cancels a pairing still in progress.
  if (ref.read(pairingProvider) is! PairingIdle) pairing.close();
}

class _PairingSheet extends ConsumerStatefulWidget {
  const _PairingSheet();

  @override
  ConsumerState<_PairingSheet> createState() => _PairingSheetState();
}

class _PairingSheetState extends ConsumerState<_PairingSheet> {
  /// What the sheet showed last. Closing it resets pairing, which must not
  /// flash the first step while the sheet slides away.
  Widget? _shown;

  @override
  Widget build(BuildContext context) {
    final closing = ModalRoute.of(context)?.isActive == false;
    final state = ref.watch(pairingProvider);
    if (closing && _shown != null) return _shown!;
    return _shown = _content(context, state);
  }

  Widget _content(BuildContext context, PairingState state) {
    final pairing = ref.read(pairingProvider.notifier);
    void done() => Navigator.pop(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: switch (state) {
          PairingIdle() => _choose(context),
          PairingOpen() => [
            _heading(context, 'Waiting for your other device'),
            _text(
              context,
              'On it, open Settings → Devices → Pair a device and choose '
              '${ref.watch(devicesProvider).identity.name}. Pairing stays '
              'open for five minutes.',
            ),
            const _Addresses(),
            _actions([SButton.ghost(label: 'Cancel', onPressed: done)]),
          ],
          PairingConnecting(:final name) => [
            _heading(context, 'Connecting to $name'),
            const _Spinner(),
            _actions([SButton.ghost(label: 'Cancel', onPressed: done)]),
          ],
          PairingCompare(:final code, :final peerName, :final waiting) => [
            _heading(context, 'Does $peerName show this code?'),
            _text(
              context,
              'Pair only if both devices show the same six digits.',
            ),
            const SizedBox(height: Space.s24),
            Text(
              '${code.substring(0, 3)} ${code.substring(3)}',
              textAlign: TextAlign.center,
              semanticsLabel: code.split('').join(' '),
              // The code is a technical value, so it takes the mono family.
              style: context.type.headline.copyWith(
                color: context.colors.foreground,
                fontFamily: context.type.technical.fontFamily,
              ),
            ),
            if (waiting) ...[
              const SizedBox(height: Space.s16),
              _text(context, 'Waiting for $peerName…', center: true),
            ],
            _actions([
              SButton.ghost(
                label: "Doesn't match",
                onPressed: waiting ? null : () => pairing.decide(false),
              ),
              SButton.primary(
                label: 'Match',
                loading: waiting,
                onPressed: waiting ? null : () => pairing.decide(true),
              ),
            ]),
          ],
          PairingDone(:final peerName) => [
            _heading(context, 'Paired with $peerName'),
            _text(
              context,
              'Your watch history and followed series now sync between them, '
              'and each can stream the other’s downloads on this network.',
            ),
            _actions([SButton.primary(label: 'Done', onPressed: done)]),
          ],
          PairingFailed(:final message) => [
            _heading(context, "Couldn't pair"),
            _text(context, message),
            _actions([
              SButton.ghost(label: 'Close', onPressed: done),
              SButton.primary(label: 'Try again', onPressed: pairing.close),
            ]),
          ],
        },
      ),
    );
  }

  List<Widget> _choose(BuildContext context) {
    final open = [
      for (final d in ref.watch(nearbyDevicesProvider).values)
        if (d.pairing) d,
    ];
    final pairing = ref.read(pairingProvider.notifier);
    return [
      _heading(context, 'Pair a device'),
      _text(
        context,
        'Choose a device that is waiting to pair, or let another device '
        'find this one. Both must be on the same network.',
      ),
      const SizedBox(height: Space.s16),
      if (open.isEmpty)
        _text(context, 'No device is waiting to pair nearby.')
      else
        for (final d in open)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s8),
            child: SButton(
              label: d.name,
              icon: Icons.devices_rounded,
              onPressed: () => pairing.join(d.address, name: d.name),
            ),
          ),
      const SizedBox(height: Space.s16),
      const _AddressForm(),
      _actions([
        SButton.primary(
          label: 'Let another device pair',
          onPressed: pairing.open,
        ),
      ]),
    ];
  }

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: Space.s8),
    child: Text(
      text,
      style: context.type.title.copyWith(color: context.colors.foreground),
    ),
  );

  Widget _text(BuildContext context, String text, {bool center = false}) =>
      Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: context.type.body.copyWith(
          color: context.colors.foregroundSecondary,
        ),
      );

  Widget _actions(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: Space.s24),
    child: DialogActions(children: children),
  );
}

/// Joins a device by the address it shows, for networks that hide devices
/// from each other's discovery.
class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm();

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _join() {
    final address = parseDeviceAddress(_controller.text);
    if (address == null) {
      setState(() => _error = 'Enter an address like 192.168.1.20:47615');
      return;
    }
    ref.read(pairingProvider.notifier).join(address);
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: Space.s8,
    children: [
      Expanded(
        child: STextField(
          controller: _controller,
          hint: 'Or enter its address',
          semanticLabel: 'Address of the device to pair with',
          technical: true,
          errorText: _error,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _join(),
        ),
      ),
      SButton(label: 'Join', onPressed: _join),
    ],
  );
}

/// `host`, `host:port` or `[v6]:port`; the default port when none is given.
DeviceAddress? parseDeviceAddress(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse('https://$trimmed');
  if (uri == null || uri.host.isEmpty) return null;
  return (host: uri.host, port: uri.hasPort ? uri.port : preferredSyncPort);
}

/// This device's addresses, for the other to enter by hand.
class _Addresses extends ConsumerWidget {
  const _Addresses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final port = ref.watch(syncServiceProvider).server.port;
    return FutureBuilder(
      future: NetworkInterface.list(type: InternetAddressType.IPv4),
      builder: (context, snapshot) {
        final addresses = [
          for (final i in snapshot.data ?? <NetworkInterface>[])
            for (final a in i.addresses)
              if (!a.isLoopback && !a.isLinkLocal) '${a.address}:$port',
        ];
        if (addresses.isEmpty || port == 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: Space.s16),
          child: Text(
            'If it isn’t listed there, enter ${addresses.join(' or ')}',
            style: context.type.bodySmall.copyWith(
              color: context.colors.foregroundSecondary,
            ),
          ),
        );
      },
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Space.s24),
    child: Center(
      child: SizedBox.square(
        dimension: IconSizes.control,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.colors.action,
        ),
      ),
    ),
  );
}
