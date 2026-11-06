import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/services.dart';
import '../../shared/errors/error_reports.dart';
import '../../shared/persistence/json_file_store.dart';
import '../shared/theme/theme.dart';
import 'adaptive_sheet.dart';
import 'buttons.dart';
import 'dialog_actions.dart';
import 'motion.dart';

const _repositoryUrl = 'https://github.com/SenZmaKi/Sentorr';
final _log = Logger('sentorr.github_star_prompt');

/// Mounted once in the release app, below its navigator.
class GithubStarPromptHost extends ConsumerStatefulWidget {
  const GithubStarPromptHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GithubStarPromptHost> createState() =>
      _GithubStarPromptHostState();
}

class _GithubStarPromptHostState extends ConsumerState<GithubStarPromptHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final paths = ref.read(appPathsProvider);
      if (await recordGithubStarPromptLaunch(
            JsonFileStore(paths.githubStarPromptFile),
          ) &&
          mounted) {
        await showGithubStarPrompt(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Record the prompt before presenting it so a later launch never repeats it.
Future<bool> recordGithubStarPromptLaunch(JsonFileStore store) async {
  try {
    final state = await store.read();
    if (state?['shown'] == true) return false;
    final previousLaunches = state?['launches'];
    final launches = (previousLaunches is int ? previousLaunches : 0) + 1;
    final show = launches >= 3;
    await store.write({'launches': launches, 'shown': show});
    return show;
  } catch (error, stack) {
    _log.warning('Could not save GitHub star prompt state', error, stack);
    return false;
  }
}

Future<void> showGithubStarPrompt(BuildContext context) async {
  final open = await showAdaptiveSheet<bool>(
    context,
    maxWidth: 410,
    builder: (_) => const _GithubStarPrompt(),
  );
  if (open != true || !context.mounted) return;

  try {
    if (await launchUrl(
      Uri.parse(_repositoryUrl),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
    ErrorReports.report(
      'Could not open GitHub',
      'Unable to open the repository.',
    );
  } catch (error, stack) {
    ErrorReports.report('Could not open GitHub', error, stack);
  }
}

class _GithubStarPrompt extends StatefulWidget {
  const _GithubStarPrompt();

  @override
  State<_GithubStarPrompt> createState() => _GithubStarPromptState();
}

class _GithubStarPromptState extends State<_GithubStarPrompt> {
  static const _star = AssetImage('assets/images/spool-github-star.webp');
  static const _please = AssetImage('assets/images/spool-github-please.webp');
  bool _pleading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(_please, context);
  }

  Widget _fade(BuildContext context, Widget child) => AnimatedSwitcher(
    duration: reduceMotion(context) ? Duration.zero : Motion.panel,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.center,
      children: [
        for (final outgoing in previous) ExcludeSemantics(child: outgoing),
        ?current,
      ],
    ),
    child: KeyedSubtree(key: ValueKey(_pleading), child: child),
  );

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion(context) ? Duration.zero : Motion.panel;
    final dismiss = _pleading ? 'No thanks' : 'Not now';
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _fade(
            context,
            Image(
              image: _pleading ? _please : _star,
              width: 170,
              height: 170,
              semanticLabel: _pleading
                  ? 'Spool pinches his fingers to ask for one tiny star'
                  : 'Spool holds up a star',
            ),
          ),
          const SizedBox(height: Space.s12),
          Semantics(
            liveRegion: true,
            child: AnimatedSize(
              duration: duration,
              curve: Motion.enter,
              child: _fade(
                context,
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _pleading ? 'Pretty please?' : 'Enjoying Sentorr?',
                      textAlign: TextAlign.center,
                      style: context.type.title.copyWith(
                        color: context.colors.foreground,
                      ),
                    ),
                    const SizedBox(height: Space.s8),
                    Text(
                      _pleading
                          ? 'Just one tiny star for Spool?'
                          : 'A GitHub star helps more people find Sentorr.',
                      textAlign: TextAlign.center,
                      style: context.type.body.copyWith(
                        color: context.colors.foregroundSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.s24),
          Center(
            child: DialogActions(
              children: [
                SButton.ghost(
                  label: dismiss,
                  labelContent: _fade(
                    context,
                    Text(dismiss, textAlign: TextAlign.center),
                  ),
                  onPressed: _pleading
                      ? () => Navigator.pop(context, false)
                      : () => setState(() => _pleading = true),
                ),
                SButton.primary(
                  label: 'Star on GitHub',
                  icon: Icons.star_rounded,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
