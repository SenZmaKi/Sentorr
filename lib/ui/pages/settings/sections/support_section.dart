import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../components/buttons.dart';
import '../settings_group.dart';

class SupportSection extends StatelessWidget {
  const SupportSection({super.key});

  @override
  Widget build(BuildContext context) => SettingsGroup(
    title: 'Support Sentorr',
    description: 'Help keep Sentorr growing',
    children: [
      SettingsTile(
        icon: Icons.volunteer_activism_outlined,
        title: 'GitHub Sponsors',
        subtitle: 'Support ongoing development',
        keywords: 'sponsor donate funding open source',
        trailing: SButton(
          label: 'Sponsor',
          onPressed: () => _open('https://github.com/sponsors/SenZmaKi'),
        ),
      ),
      SettingsTile(
        icon: Icons.star_outline_rounded,
        title: 'Star Sentorr on GitHub',
        subtitle: 'Help more people discover Sentorr',
        keywords: 'repository community support',
        trailing: SButton(
          label: 'Open GitHub',
          onPressed: () => _open('https://github.com/SenZmaKi/Sentorr'),
        ),
      ),
    ],
  );

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
