import 'package:flutter/material.dart';
import 'package:sentorr/ui/shared/theme/theme.dart';

import '../runtime/lab_controller.dart';
import '../runtime/streaming_profile.dart';

class ProfileControls extends StatelessWidget {
  const ProfileControls({super.key, required this.lab});
  final LabController lab;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.s16,
    runSpacing: Space.s12,
    children: [
      SizedBox(
        width: 180,
        child: DropdownButtonFormField<int>(
          initialValue: lab.profile.downloadMbps,
          decoration: const InputDecoration(labelText: 'Download cap'),
          items: [0, 5, 10, 20, 40, 100]
              .map(
                (n) => DropdownMenuItem(
                  value: n,
                  child: Text(n == 0 ? 'Unlimited' : '$n Mbps'),
                ),
              )
              .toList(),
          onChanged: lab.busy || lab.files.isNotEmpty
              ? null
              : (n) {
                  lab.profile = StreamingProfile(
                    downloadMbps: n!,
                    bufferSeconds: lab.profile.bufferSeconds,
                    resumeSeconds: lab.profile.resumeSeconds,
                    readAheadMiB: lab.profile.readAheadMiB,
                  );
                },
        ),
      ),
      SizedBox(
        width: 180,
        child: DropdownButtonFormField<int>(
          initialValue: lab.profile.resumeSeconds,
          decoration: const InputDecoration(labelText: 'Ready buffer'),
          items: [5, 10, 20, 30]
              .map((n) => DropdownMenuItem(value: n, child: Text('$n seconds')))
              .toList(),
          onChanged: lab.busy || lab.files.isNotEmpty
              ? null
              : (n) {
                  lab.profile = StreamingProfile(
                    downloadMbps: lab.profile.downloadMbps,
                    resumeSeconds: n!,
                    bufferSeconds: 60,
                    readAheadMiB: lab.profile.readAheadMiB,
                  );
                },
        ),
      ),
    ],
  );
}
