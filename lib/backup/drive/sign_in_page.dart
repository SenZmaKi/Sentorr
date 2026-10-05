/// Opens Sentorr on Android, which cannot bring itself in front of the
/// browser.
const androidReturnLink = 'sentorr://return';

/// What the browser shows once Google sends the viewer back: a Sentorr
/// panel on the canvas, in the app's light or dark roles (DESIGN.md), saying
/// how sign-in went. On desktop the app comes forward on its own; with a
/// [returnLink], as on Android, the page follows it and offers it as a
/// button in case the browser asks first.
String signInPage({required bool signedIn, String? returnLink}) {
  final title = signedIn ? "You're signed in" : 'Sign-in cancelled';
  final close = returnLink == null;
  final body = signedIn
      ? 'Sentorr is backing up to your Google Drive.'
            '${close ? ' You can close this tab.' : ''}'
      : 'Nothing was connected. ${close ? 'You can close this tab and try '
                  'again' : 'Try again'} from Sentorr.';
  // A check or a cross, drawn in the status colour.
  final mark = signedIn ? 'M5 12.5l4.5 4.5L19 7.5' : 'M7 7l10 10M17 7L7 17';
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark light">
<title>Sentorr · $title</title>
<style>
  :root {
    --canvas: #0D0D0D; --surface: #191919; --border: #333333;
    --fg: #FCFDFF; --fg2: #B3B3B3; --muted: #AAAAAA;
    --status: ${signedIn ? '#11FF99' : '#FF6B81'};
    --status-surface: ${signedIn ? '#052619' : '#300710'};
    --shadow: 0 1px 2px rgba(0,0,0,.5), 0 8px 24px rgba(0,0,0,.35);
    --edge: inset 0 1px 0 rgba(255,255,255,.04);
    --action: #FCFDFF; --on-action: #000000; --action-hover: #E5E5E5;
  }
  @media (prefers-color-scheme: light) {
    :root {
      --canvas: #E7E7E7; --surface: #F3F3F3; --border: #D4D4D4;
      --fg: #171717; --fg2: #4D4D4D; --muted: #606060;
      --status: ${signedIn ? '#067647' : '#C50000'};
      --status-surface: ${signedIn ? '#ECFDF3' : '#FFF1F2'};
      --shadow: 0 1px 2px rgba(0,0,0,.08), 0 8px 24px rgba(0,0,0,.06);
      --edge: inset 0 1px 0 rgba(255,255,255,.7);
      --action: #171717; --on-action: #FFFFFF; --action-hover: #333333;
    }
  }
  * { box-sizing: border-box; }
  html, body { height: 100%; margin: 0; }
  body {
    display: grid; place-items: center; padding: 16px;
    background: var(--canvas); color: var(--fg);
    font: 400 16px/24px Inter, -apple-system, BlinkMacSystemFont, "Segoe UI",
      system-ui, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  main {
    width: 100%; max-width: 400px; padding: 24px;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: 16px; box-shadow: var(--shadow), var(--edge);
  }
  .badge {
    width: 40px; height: 40px; border-radius: 999px;
    display: grid; place-items: center;
    background: var(--status-surface); color: var(--status);
  }
  h1 {
    margin: 16px 0 8px; font-size: 20px; line-height: 28px;
    font-weight: 600; letter-spacing: -0.2px;
  }
  p { margin: 0; color: var(--fg2); }
  a.back {
    display: block; margin-top: 24px; padding: 0 16px;
    height: 48px; line-height: 48px; text-align: center;
    border-radius: 8px; background: var(--action); color: var(--on-action);
    font-weight: 500; font-size: 14px; text-decoration: none;
  }
  a.back:hover { background: var(--action-hover); }
  a.back:focus-visible { outline: 2px solid var(--action); outline-offset: 2px; }
  footer {
    margin-top: 24px; font-size: 12px; line-height: 16px;
    font-weight: 500; letter-spacing: .4px; color: var(--muted);
  }
</style>
</head>
<body>
<main role="status">
  <div class="badge" aria-hidden="true">
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
      stroke="currentColor" stroke-width="2.25" stroke-linecap="round"
      stroke-linejoin="round"><path d="$mark"/></svg>
  </div>
  <h1>$title</h1>
  <p>$body</p>
${returnLink == null ? '' : '''  <a class="back" href="$returnLink">Back to Sentorr</a>
  <script>location.href = "$returnLink";</script>
'''}  <footer>SENTORR</footer>
</main>
</body>
</html>
''';
}
