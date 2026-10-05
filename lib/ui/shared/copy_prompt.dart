import 'package:flutter/material.dart';

import '../../sync/copy_offer.dart';
import '../components/adaptive_sheet.dart';
import '../components/buttons.dart';
import '../components/dialog_actions.dart';
import 'theme/theme.dart';

enum CopyChoice { copy, download }

/// Asks whether to copy what [offer] found on paired devices instead of
/// downloading it; null when the viewer cancels. [rest] names what would
/// still download, e.g. "the rest of season 2"; null when the offer covers
/// the whole request.
Future<CopyChoice?> askToCopy(
  BuildContext context,
  CopyOffer offer, {
  String? rest,
}) => showAdaptiveSheet<CopyChoice>(
  context,
  maxWidth: 480,
  builder: (context) {
    final c = context.colors;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Copy from ${offer.devices}?',
            style: context.type.title.copyWith(color: c.foreground),
          ),
          const SizedBox(height: Space.s8),
          Text(
            copyMessage(offer, rest: rest),
            style: context.type.body.copyWith(color: c.foregroundSecondary),
          ),
          const SizedBox(height: Space.s24),
          DialogActions(
            children: [
              SButton.ghost(
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
              SButton(
                label: rest == null ? 'Download instead' : 'Download all',
                onPressed: () => Navigator.pop(context, CopyChoice.download),
              ),
              SButton.primary(
                label: rest == null ? 'Copy' : 'Copy and download the rest',
                onPressed: () => Navigator.pop(context, CopyChoice.copy),
              ),
            ],
          ),
        ],
      ),
    );
  },
);

/// What the prompt says, e.g. "Episodes 1–3 and 5 are already on MacBook.
/// Copy them over your network and download the rest of season 2?"
String copyMessage(CopyOffer offer, {String? rest}) {
  final several = offer.copies.length > 1;
  final had = {for (final c in offer.copies) c.deviceName}.length == 1
      ? '${_capital(offer.what)} ${several ? 'are' : 'is'} already on '
            '${offer.devices}.'
      : 'Already on your other devices: ${offer.summary}.';
  final them = several ? 'them' : 'it';
  return rest == null
      ? '$had Copying $them over your network is quicker than downloading '
            '$them again.'
      : '$had Copy $them over your network and download $rest?';
}

String _capital(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
