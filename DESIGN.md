# Sentorr design contract

Status: locked for the initial Flutter implementation, 1 October 2026. Use Resend/Vercel typography and restraint with the layered depth in the user-supplied reference frames; extend component contracts as features need them.

## Purpose

Keep Sentorr visually coherent as features grow. Shared appearance belongs in the theme system; screens compose components and express product behavior. Begin with one design identity in light and dark modes, while allowing future identities to use the same component contracts.

## Sources of truth

- This document owns design intent, usage rules and the reasons behind constraints.
- Until the Flutter app is scaffolded, the tables below are the implementation specification. Once implemented, typed Dart definitions own exact runtime values; replace these value tables with code pointers while retaining the intent and usage rules. Change shared values centrally, not through screen overrides.
- Comments next to unusual token mappings explain their purpose or tradeoff. Avoid comments that merely repeat the value.
- Senpwai is a reference for implementation patterns, not Sentorr's identity.

## Locked visual direction

Use a neutral, layered space: canvas behind panels, panels beneath raised controls, recessed wells below their parent surface, and floating overlays above everything else. Surface luminance, soft contact shadows and fine edge highlights establish those relationships. Keep Inter typography (Geist Mono for technical values), monochrome actions and precise spacing from the Resend/Vercel direction. Artwork supplies most of the color.

The user's [before](docs/design-references/depth/before.png), [light after](docs/design-references/depth/after-light.png) and [dark after](docs/design-references/depth/after-dark.png) frames are the primary depth reference. They show grouped panels, brighter child surfaces, recessed tracks and small shadows beneath raised objects. They also change grouping, spacing and information hierarchy; adding shadows alone will not reproduce the improvement. These supplied still frames establish appearance, not video motion or exact source measurements.

The depth specification below supersedes the earlier flat-card and shadow-free dark-mode rules. Values are Sentorr implementation choices derived from the visible relationships, not measured values from the video. Maintain one identity with light and dark modes.

### Color roles

All hex values are opaque sRGB unless explicitly stated. These are resolved semantic roles; Dart implementation may derive them from shared primitives. Both modes use the reference's distinct canvas, panel and control planes. Status pairs and interaction colors complete the references for app use. borderControl sits just above the 3:1 boundary floor against surfaceControl and surface in both modes (softened 2 October 2026), so outlines stay accessible without reading heavy; do not lighten it further.

| Role                | Dark      | Light     | Use                                                          |
| ------------------- | --------- | --------- | ------------------------------------------------------------ |
| canvas              | `#0D0D0D` | `#E7E7E7` | Back plane                                                   |
| surface             | `#191919` | `#F3F3F3` | Panels and grouped containers                                |
| surfaceControl      | `#262626` | `#FFFFFF` | Raised controls and child cards                              |
| surfaceRaised       | `#303030` | `#FFFFFF` | Floating menus and dialogs                                   |
| surfaceInset        | `#090909` | `#DCDCDC` | Recessed wells and tracks                                    |
| foreground          | `#FCFDFF` | `#171717` | Titles and primary text                                      |
| foregroundSecondary | `#B3B3B3` | `#4D4D4D` | Body descriptions and metadata                               |
| foregroundMuted     | `#AAAAAA` | `#606060` | Captions, hints; never essential content in disabled styling |
| foregroundDisabled  | `#464A4D` | `#A1A1A1` | Disabled controls only                                       |
| borderSubtle        | `#333333` | `#D4D4D4` | Decorative dividers and panel edges                          |
| borderStrong        | `#454545` | `#B8B8B8` | Structural edges                                             |
| borderControl       | `#747474` | `#8A8A8A` | Input boundaries and controls requiring visible outlines     |
| action              | `#FCFDFF` | `#171717` | Primary button fill, selected checks and progress            |
| onAction            | `#000000` | `#FFFFFF` | Content on action fill                                       |
| actionHover         | `#E5E5E5` | `#333333` | Primary hover                                                |
| actionPressed       | `#D4D4D4` | `#000000` | Primary pressed                                              |
| stateHover          | `#333333` | `#F5F5F5` | Neutral interactive surface hover                            |
| statePressed        | `#1F1F1F` | `#E5E5E5` | Neutral interactive surface pressed                          |
| selection           | `#262626` | `#EBEBEB` | Selected navigation/rows; pair with foreground               |
| focus               | `#FCFDFF` | `#171717` | Keyboard focus ring                                          |
| link / info         | `#3B9EFF` | `#0761D1` | Links and informational status                               |
| infoSurface         | `#071B30` | `#EAF3FF` | Information badge/background                                 |
| success             | `#11FF99` | `#067647` | Ready, completed, successful action                          |
| successSurface      | `#052619` | `#ECFDF3` | Success badge/background                                     |
| warning             | `#FFC53D` | `#854A0E` | Waiting, degraded conditions requiring attention             |
| warningSurface      | `#2A2108` | `#FFFAEB` | Warning badge/background                                     |
| error               | `#FF6B81` | `#C50000` | Failure, destructive intent                                  |
| errorSurface        | `#300710` | `#FFF1F2` | Error badge/background                                       |

Status foregrounds pair with their corresponding status surfaces. Do not use saturated status colors as large fills. Neutral buttons remain the default, including Play. Use error text/border for destructive actions, with confirmation when product behavior warrants it. Links are underlined in prose. Status labels accompany color: queued and paused are neutral, active transfer is info, ready/completed is success, and failure is error; buffering itself is not an error.

### Typography

Bundle **Inter** (400, 500, 600), **Inter Display** (600) and **Geist Mono** (400, 500) with the app, including their licenses (`assets/fonts/*-LICENSE.txt`). Inter comes from the [official Inter releases](https://github.com/rsms/inter/releases), Geist Mono from the [official Geist repository](https://github.com/vercel/geist-font). Display, headline and title use Inter Display, Inter's optical cut for large sizes; everything else uses Inter. Use platform fallback only for unavailable glyphs. Inter replaced Geist Sans on 2 October 2026 at the owner's request. **Barlow** (400, 500, 600; [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/barlow)) is on trial as the active face from the same date. Faces are `TypeFace` entries in `lib/ui/shared/theme/typography.dart` that carry their own per-role tracking; switch with `SentorrType.face`. The tracking column below is Inter's.

Dimensions below are Flutter logical units before user text scaling. Line height is an absolute specification; map it to Flutter's `TextStyle.height` as line height divided by font size. Tracking is logical units, not a percentage.

| Text role | Size / line height | Weight | Tracking | Use                                                  |
| --------- | ------------------ | ------ | -------- | ---------------------------------------------------- |
| display   | 48 / 56            | 600    | -1.0     | Media detail title at wide widths                    |
| headline  | 32 / 40            | 600    | -0.5     | Compact detail title; top-level pages carry no title, navigation names them |
| title     | 24 / 32            | 600    | -0.2     | Section and dialog title                             |
| subtitle  | 20 / 28            | 600    | -0.35    | Panel and group heading                              |
| bodyLarge | 18 / 28            | 400    | -0.25    | Synopsis lead where appropriate                      |
| body      | 16 / 24            | 400    | -0.18    | Normal prose and settings                            |
| bodySmall | 14 / 20            | 400    | -0.08    | Metadata, rows and secondary copy                    |
| label     | 14 / 20            | 500    | -0.08    | Controls, tabs and navigation                        |
| caption   | 12 / 16            | 400    | 0        | Nonessential annotations                             |
| technical | 13 / 20            | 400    | 0        | Geist Mono: filenames, speeds, sizes and diagnostics |
| timecode  | 14 / 20            | 500    | label's  | Player clock and scrub time: the sans face with tabular figures, so it sits with the controls |

Use sentence case. Keep ordinary text at 400, controls at 500 and headings at 600. Technical data and time counters use tabular figures; descriptions stay in sans. Essential data is at least bodySmall. Preserve text scaling, wrapping and font fallback; heights are minima rather than clipping boxes. Long filenames may ellipsize with an accessible way to view the full value.

### Geometry and rhythm

| Scale                  | Approved values                                 | Application                                                                          |
| ---------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------ |
| Spacing                | 0, 2, 4, 8, 12, 16, 24, 32, 40, 48, 64, 96, 128 | Base step 4; 2 reserved for optical micro-adjustments                                |
| Radius                 | 0, 4, 6, 8, 12, 16, full                        | Controls 8; child cards 12; group panels/dialogs 16; chips 6; circular controls full |
| Border                 | 1, 2                                            | 1 for edges; 2 for focus and selected indicators                                     |
| Icon                   | 16, 20, 24                                      | Metadata 16; ordinary controls 20; navigation/player 24                              |
| Control minimum height | 36 compact, 40 standard, 48 touch               | Compact is desktop-only; touch hit regions at least 48 × 48                          |
| Motion duration        | 100, 150, 200, 360 ms; media 450/700 ms, 9 s    | Press 100; hover/focus 150; panels/theme 200; content entry 360; media rules below   |

Use 8 between related inline items, 12–16 within groups, 24–32 between groups, and 48 between major sections. Panels use 24 padding; dense rows use 12 vertical and 16 horizontal. App content has 24 horizontal gutters on larger layouts and 16 on compact layouts. The 96/128 steps are reserved for exceptional feature openings, not routine lists or empty states.

### Depth as a theme contract

Use a consistent light source above the interface: a fine lighter top edge and a small darker shadow beneath raised objects. In both modes, child controls read as nearer than their parent panel. Dark mode preserves this through brighter surfaces and edge highlights as well as shadows; light mode uses light surfaces against a darker canvas. No perspective transforms are needed.

| Depth role | Surface        | Treatment                        | Use                                                      |
| ---------- | -------------- | -------------------------------- | -------------------------------------------------------- |
| base       | canvas         | No shadow                        | Page background                                          |
| panel      | surface        | panel shadow + edge highlight    | Settings group, detail summary, grouped selections       |
| raised     | surfaceControl | raised shadow + edge highlight   | Secondary buttons, child selection cards, input controls |
| inset      | surfaceInset   | inset shading                    | Slider/progress trough, technical well                   |
| floating   | surfaceRaised  | floating shadow + edge highlight | Dialog, menu, popover                                    |

Starting shadow recipes use `(offsetX, offsetY, blur, spread, black opacity)` in Flutter logical units. Each recipe is an ordered stack. Theme code owns these values:

| Recipe   | Light                                       | Dark                                        |
| -------- | ------------------------------------------- | ------------------------------------------- |
| panel    | `(0, 1, 2, 0, 8%)`, `(0, 4, 12, -2, 6%)`    | `(0, 2, 4, 0, 24%)`, `(0, 8, 16, -4, 20%)`  |
| raised   | `(0, 1, 2, 0, 12%)`, `(0, 3, 6, -1, 8%)`    | `(0, 1, 2, 0, 32%)`, `(0, 4, 8, -2, 24%)`   |
| floating | `(0, 2, 4, 0, 10%)`, `(0, 12, 32, -4, 14%)` | `(0, 2, 4, 0, 36%)`, `(0, 12, 32, -4, 32%)` |

`edgeHighlight`: white at 70% in light mode and 8% in dark mode, on the top edge with a 1-unit width. `edgeShade`: black at 8% light / 24% dark on the bottom edge. These edges describe lighting; accessible control boundaries still use borderControl when required.

`insetShade`: black at 10% light / 40% dark, fading inward over 3 units from the top of a recessed well; a 1-unit bottom highlight uses edgeHighlight. Render this within the component, not as an outer drop shadow. Raised progress fills/thumbs may use the raised recipe; active contrast remains governed by action and onAction.

Provide a small typed `SurfaceDepth` vocabulary (`base`, `panel`, `raised`, `inset`, `floating`) and theme-owned resolved styles containing fill, edge treatment and shadow stack. Shared surface widgets render those styles. Where Flutter's component theme cannot express edge lighting or inset shading, use a shared decorator or painter consuming the typed style. Feature screens choose the role; they do not compose their own shadows or gradients. Avoid combining automatic Material elevation with the explicit shadow stack. Disable automatic colored surface tint.

Maintain readable depth through grouping and spacing. Show no more than three persistent planes in a typical region (canvas → panel → child control); a temporary overlay may add the floating plane. From 600 wide, navigation sits on the canvas and pages sit on one panel inset 8 from the window; groups inside a page are therefore raised, not panels. Compact layouts put pages directly on surface. Add a containing surface for a meaningful group, not around every label or row. Dense lists remain on one plane with dividers. Leave space for shadows, and clip artwork independently so panel shadows are not cut off.

Hover on an already raised control may increase its edge highlight; pressing retains only the first contact-shadow layer of the raised recipe and uses statePressed. No translation, layout shift or scale bounce. Flat/ghost controls remain flat. Selection adds a check or indicator rather than a larger shadow. Focus remains an independent high-contrast ring. Neutral surface gradients are allowed only for these theme-owned lighting/inset treatments; saturated decorative gradients stay outside app chrome.

### Depth acceptance

- In grayscale, canvas, panel, raised controls and recessed tracks remain distinguishable by their surfaces and lighting.
- Light and dark layouts preserve the same grouping and front-to-back order.
- The reference's panel/child separation is evident at rest; hover is not needed to reveal hierarchy.
- Shadows stay local and soft; edge highlights remain fine. No broad white halos around dark panels or embossed treatment on text/icons.
- Focus, selected state, status and readable text still work when shadows are absent. Depth does not substitute for accessible interaction cues.
- Evaluate a settings group, nested choice cards and a progress track in both modes when implemented. These docs do not establish visual implementation verification.

### Responsive layout

Code: `lib/ui/shared/layout/`. One vocabulary everywhere; no raw width comparisons in widgets.

- **Width classes:** compact < 600 (phones), medium 600–959 (portrait tablets, small windows), expanded 960–1439 (landscape tablets, laptops), large ≥ 1440 (desktop monitors). `LayoutSize.pick(compact:, medium:, expanded:, large:)` chooses a value and falls back to the nearest smaller class.
- **Short height:** below 480 tall a layout is `short`; `phoneLandscape` is short and landscape. Short layouts give vertical space to content: heroes cap their height, bars and headers slim down, dialogs fill the height and scroll, the player hides chrome sooner and never docks a mini player over content.
- **Which size to ask:** chrome that belongs to the window (navigation, overlay type, player chrome, docking) reads `context.screen`. Content composition (columns, card sizes, grids, side-by-side details) reads its own constraints through `ResponsiveBuilder`, so a component behaves the same wherever it is placed.
- **Input mode is not size:** `context.input` is touch or pointer. It decides interaction only: hover previews, hover-revealed actions and tooltips need a pointer and must have a touch path (tap, long press or always-visible action); touch raises icon and row targets to 48. Components resolve this from `context.density` (`SentorrDensity`, `lib/ui/shared/theme/density.dart`): buttons, inputs, selects and icon buttons 40 → 48, menu rows 36 → 48, and visually small controls (chips, switches, pager dots, the seek bar) keep their drawing inside a 48 hit region (`MinTarget`). Heights are minimums, so large text grows a control instead of clipping it. Shortcut suffixes such as "(k)" are dropped from labels on touch. A wide touch tablet keeps the expanded layout with touch interaction.
- **Context, not scaling:** each class should use its space differently rather than stretching one layout. Compact stacks content, uses bottom navigation, bottom sheets for menus and pickers, and full-width primary actions. Medium uses the rail, two columns where content fits and centred dialogs. Expanded and large add persistent side content (details beside lists, panels beside the player), more grid columns and denser shelves while keeping the 1400 content cap; extra width beyond the cap becomes margin, not stretched text.
- **Safe areas and insets:** respect notches and system bars in every orientation (including the leading/trailing cut-outs of a landscape phone), and lift inputs and sheets above the keyboard.
- **Verification:** the shared viewport matrix in `test/support/viewports.dart` (phone portrait and landscape, tablet portrait and landscape, small window, laptop, desktop, ultrawide) must lay out every page without overflow.

### Composition and artwork

- At available width below 600, use compact navigation and stacked details; from 600 use the navigation rail at every width, giving the space to content; 600–959 may use two-column details when content fits, and 960 and above the full desktop layout. Layouts respond to local constraints, not platform names. The full rules are under Responsive layout above.
- Keep normal content centered with a maximum width of 1400. Player and artwork backdrops may fill available space. Reading prose caps at 720.
- Catalog poster grids choose their column count from available width, with nominal tile widths of 160–220 and 16 gaps; smaller layouts may use two columns if titles and targets still fit. Never fix a desktop column count on mobile.
- Posters use a 2:3 frame; backdrops and video previews use 16:9. Crop posters/backdrops appropriately; preserve the video's actual aspect ratio with letterboxing rather than cropping playback.
- Put media title and metadata below posters. Detail pages may put titles over artwork using the image-overlay roles below. Artwork stays in its original colors; surrounding chrome stays neutral.
- Selection uses a neutral fill plus a visible indicator or check. Hover uses surface and border changes, with no card lift, scale bounce or new glow.
- Media exception (approved 2 October 2026): on hover or focus a media tile's frame stays fixed while its artwork zooms up to 6% inside the clip over 450 ms, with an overlay of play/info glyphs fading in over a bottom artwork fade. Neighbours and layout never move. Reduced motion skips the zoom.
- Hover preview exception (approved 2 October 2026, after Hayase): when a mouse pointer deliberately rests 400 ms on the artwork of a title, episode or resume tile (never its text), a floating `PreviewCard` opens over it, centred on posters and stills or from the leading edge of episode rows, clamped 8 inside the window. It enters over 360 ms (fade, rise 12, scale 0.95 → 1, ease-out) and leaves over 150 ms once the pointer has left both tile and card for 80 ms. Only intent opens it: the wait starts on real pointer movement over the artwork, not on content scrolling under a still pointer; moving more than 6 restarts it; any wheel or trackpad scroll, or a list still moving, cancels it. One preview at a time; a wheel or tap inside it closes it at once. It floats above the tile rather than enlarging it, so neighbours and layout never move. Pointer only: touch taps go to the tile, a touch long press opens the same card in a sheet (`showPreviewSheet`), and keyboard focus keeps the artwork zoom. Reduced motion shows and hides it immediately.
- Keep torrent rows aligned by information: filename, quality, size, availability and action. Technical information uses the technical role; the primary action remains visually obvious.
- Offline (`onlineProvider`, checked when a request gets no answer and every 5 s until back), the home page swaps the spotlight and its ambient wash for `OfflineNotice`: a panel with a warning-colored cloud-off glyph in a raised 40 tile, You’re offline, what still plays, and Open Downloads when anything is downloaded. Continue watching and a Downloaded row (finished downloads as `EpisodeCard`s, a movie's year in the code stamp) follow; rows that failed hide rather than each showing a retry, and everything reloads once the connection returns. Code: `lib/ui/pages/home/offline_notice.dart`, `lib/shared/net/online.dart`.
- Empty, loading and error states retain the same layout rhythm. Use neutral skeletons without decorative shimmer by default. Explain errors and offer the next action in plain language.

Gradients serve artwork legibility and the theme-owned depth lighting described above. The home spotlight may wash the top of the page with its own artwork, blurred, veiled by the `ambientVeil` role and faded into surface; it drifts slower than scroll and is the only ambient artwork treatment. The initial app does not need marketing mesh gradients, other ambient glows, glass panels, gradient buttons or colored heading text. Keep any future marketing treatment separate from these app components.

### Playback and image overlays

Image overlays (text and controls on artwork) are an explicit presentation context independent of app brightness: overlay foreground `#FFFFFF`, secondary `#D4D4D4`, control surface black at 80%, scrim black at 60%, focus `#FFFFFF`. A bottom artwork fade runs from transparent to black at 80%; maintain a scrim behind text where needed rather than trusting the image to be dark. The player is different: it follows app brightness with its own scheme, `PlayerColors` (`lib/ui/shared/theme/player_colors.dart`). Dark puts white controls on fades over the picture; light lifts the top and bottom bars onto floating light surfaces inset 12 from the edges with dark controls, and veils (end screen, errors, docked hover, opening cover) become light. Captions always keep the dark overlay treatment because they are read against the picture.

Player buttons use circular targets of at least 48, icons 24, and the hover/pressed washes from `PlayerColors`. The played track and thumb use its foreground, the buffered span its `inactiveTrack`. Keep captions legible using dedicated caption styling and preserve user subtitle preferences. Never put dark controls straight on the picture: in light mode they sit on the floating bars or a disc.

### Player

The player is a layer over the app. Code: `lib/ui/pages/player/`, presentation modes in `lib/ui/shared/player_view.dart`, playback and queue in `lib/player/`.

- **Modes.** Full covers the whole window, navigation included. Back or Escape closes an open panel, then leaves full screen, then docks the player as a 16:9 card (floating depth, radius 12) in the app's bottom-right corner while the app stays usable. A separate close control stops playback. Pop out turns the window itself into a frameless, always-on-top 480 × 270 video window in the screen corner; it never saves those bounds as the window's own. One player instance moves between modes, so playback never restarts.
- **Chrome.** Top: dock control (always docks, never toggles full screen; from full screen it restores the window first, and full screen lives only on the bar's trailing control), series over `S1 E2` and episode name, then the live torrent (`TorrentStats`: a progress ring with the downloaded percentage, download and upload speeds, connected peers, each in the technical role behind a 16 icon, its tooltip carrying totals; narrow players keep progress and download only), close. Before the first frame the opening cover names the torrent stage: finding, connecting to peers, preparing, buffering, with the peer count. Bottom: scrubber, then play/pause, previous, next, volume, clock, the current item as a chip that is the only control opening Episodes / Up next; trailing at the far end a speed badge when not Normal, captions, settings, pop out, full screen. Each action has one control: docking lives only on the top-left control (and Esc / i), the queue only on the chip (and q). Chrome hides after 3 s of playback idle and stays while paused, pointed at, or a panel is open. The cursor hides with it.
- **App surfaces over video.** Settings, Episodes and the Next hover card use the app's floating surface (`PlayerMenuSurface`), not a separate dark glass. Episodes reuses the title page's section header, season chips and `EpisodeRow` (with its `selected` Now playing state). Up next is a slim row on the same surface. Artwork in the corner Up next row opens the standard `HoverPreview` card like any media tile (the episodes panel rows do not); its secondary action opens the title page and docks the player. Flat bar controls use `PlayerControl` with the overlay hover/pressed washes.
- **Scrubber.** Played white, buffered `inactiveTrack`, unloaded `trackUnloaded`, hovered span `trackHover`. It thickens from 4 to 6 and shows its thumb when hovered or focused, previews the time under the pointer, and seeks once on release so a stream fetches one position.
- **Feedback.** Commands acknowledge in the picture with a glyph disc that fades out (seeks toward their side). Buffering shows after 300 ms. Captions are drawn by the app over a scrim and rise above visible chrome.
- **Ends.** Over the closing seconds a slim Up next row (still, eyebrow with the countdown and code, title, Play now, a dismiss control at the row's end) sits in the corner on the floating surface. When the item ends the next one starts on its own, in every mode, with no second countdown. The end screen (Play next / Replay, or Replay / Back when nothing follows) appears only when Up next was dismissed, the sleep timer's End of video claimed the ending, or the queue is exhausted.
- **Keys.** YouTube's layout: k/space, j/l, arrows, m, f, c, Shift+N/P, </> speed, ,/. a frame back or forward while paused, 0–9, i for mini player, q for episodes, t for torrents, ? for a shortcuts dialog (also in Settings on pointer devices) that pauses while open and resumes on close, Escape as above. The dialog draws a compact keyboard in a recessed deck: bound keys are raised caps carrying their command's glyph, unused keys faint outlines; a grouped legend follows, and hovering (or tapping) a key or legend row lights the other (keys in action/onAction, rows in stateHover). Code: `shortcuts_dialog.dart`, `shortcut_keyboard.dart`, `shortcut_map.dart`.

### Play launch

Play anywhere (cards, previews, title page, the episodes panel) first finds a torrent; the player opens once one is chosen. One floating dialog (radius 16, padding 24, max width 560, scrim barrier) owned by the app, not the tile, so a closed hover preview cannot strand it. Code: `lib/ui/pages/launch/`, logic in `lib/player/launch.dart`.

- **Header.** Subject as a muted eyebrow (`Title · 2026`, `Series · S1 E2 · Episode`), then a title-role heading naming the state: Finding a torrent, Ready to play, Closest match, Couldn’t find a torrent, Couldn’t prepare playback.
- **Exact match** (preferred quality, single file): the best `TorrentOption` selected, a ghost Show N more, an inset countdown track with action fill, and primary Play in Ns. It plays after 4 s. Any touch, scroll or key in the dialog stops the countdown for that launch; it does not restart. A viewer setting can skip the dialog for exact matches.
- **Close match** (other or unknown quality, whole season): every option listed, the best selected, and a warning-pair note naming the compromise. No countdown.
- **Miss:** the resolver's message and recovery suggestions, then a labelled field to search under another title.
- **Offline:** a failure or miss while offline is headed You’re offline, explains that only downloads play without a connection, and offers Try again in place of the search field. Downloads play without the dialog's search at all; a series whose episode list cannot be fetched queues its downloaded episodes in air order.
- **`TorrentOption`:** a row on the dialog plane, not a card: radio glyph or check, filename in technical (two lines, full name in a tooltip), then a `MetaLine` of best-match marker, quality, size, seeders and Whole season. stateHover/statePressed, selection fill when chosen, borderSubtle dividers.

Name the data provider nowhere in the interface; rows, errors and labels describe what the viewer gets, not where it comes from.

### Toasts

Transient notices that need no decision; anything blocking uses a dialog. `Toast` (`lib/ui/components/toast.dart`) is the floating surface with borderStrong, radius 12, padding 16 (8 trailing beside the 40 dismiss control): a 20 status icon in the tone's foreground (info, success, warning, error), title in label, optional message in bodySmall foregroundSecondary (four lines), then ghost actions. It is a live region. `ErrorToasts` hosts uncaught errors from `ErrorReports` top-right, newest first, at most three, revealed with the standard rise; each closes after 8 s unless pointed at, and Copy details puts the error, stack trace, platform and recent log on the clipboard, confirming in place as Copied.

## Fundamental component contracts

These are implementation requirements as components are introduced, not a request to prebuild every widget.

| Component / variant       | Theme-owned appearance                                                                                               | Composition and behavior                                                                                                |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Button / primary          | action + onAction; raised recipe; radius 8; label; height 40; horizontal padding 16                                  | Dominant action per task group; hover/pressed use action state roles                                                    |
| Button / secondary        | surfaceControl + foreground; raised depth; borderStrong; otherwise primary geometry                                  | Secondary action; hover/pressed use neutral state roles                                                                 |
| Button / ghost            | Transparent + foreground; radius 8; same sizing                                                                      | Low-emphasis action; visible neutral hover/pressed fill                                                                 |
| Button / destructive      | error foreground; errorSurface on hover/press; radius 8                                                              | Named destructive action; do not style ordinary failures as an action                                                   |
| Icon button               | Ghost style; icon 20; 40 desktop or 48 touch target                                                                  | Accessible label and tooltip; circular only for player/contextual circular variant                                      |
| Input / search / dropdown | surfaceControl + foreground; raised depth; borderControl; focus border 2; radius 8; bodySmall; height 40; padding 12 | Persistent label or accessible name; hints foregroundMuted; inline error text and border                                |
| Checkbox / radio / switch | action + onAction when selected; borderControl otherwise                                                             | Selected state has shape/check/thumb position, not color alone; visible focus                                           |
| Surface / panel           | surface, panel depth, radius 16, padding 24                                                                          | Group related content; decorative border is not an interaction boundary                                                 |
| Dialog / menu / toast     | surfaceRaised, borderStrong, floating depth                                                                          | Dialog radius 16/padding 24; menus radius 8/padding 8; toast radius 12/padding 16; correct focus/announcement semantics |
| Navigation item / tab     | foregroundSecondary idle; selection + foreground active; radius 8                                                    | From 600 wide, an 80-unit rail: 56-unit targets with the icon over a short label; the selected item uses the filled icon and one raised pill that glides between items; no dot indicator; selected semantics |
| Chip / filter             | surfaceInset + foregroundSecondary; radius 6; label; padding 4 vertical/8 horizontal                                 | Selected uses selection + foreground and a check or clear affordance; inflate touch region                              |
| Media tile                | surfaceControl frame, raised depth where framed, radius 12; title bodySmall weight 500; metadata caption             | Poster first, text below; keyboard activation and visible focus; neutral placeholder                                    |
| Torrent / episode row     | Transparent idle; stateHover/statePressed; selection when selected; borderSubtle divider                             | bodySmall + technical values; grow with text scaling; no independent card around every cell                             |
| Status / progress         | Paired status roles for status, action for ordinary progress; surfaceInset track with inset depth                    | Label and icon express state; determinate progress when known; buffering is explicit                                    |
| Player control            | Overlay roles and geometry above                                                                                     | Behavior follows playback requirements; keyboard and touch controls remain discoverable                                 |

### Media card contracts

Each home row uses a card built for its purpose, so a viewer can tell what a click will do before reading. Cards share `ArtworkFrame` (raised frame, artwork zoom on hover/focus, persistent `decorations`, hover overlay) and `card_parts.dart` (`CardTitle`, `CardEyebrow`, icon-led `MetaLine`). Code: `lib/ui/components/cards/`.

| Card | Purpose | Anatomy, in reading order | Notes |
| --- | --- | --- | --- |
| `PosterCard` | Browse a title | 2:3 artwork with rating chip (star, mono) top-right, optional badge top-left, optional `PosterRibbon`; title (label 600); facts: kind icon + kind, year, first genre | Hover shows play and info glyphs. Acclaim rows swap facts for rating and vote count |
| `RankedPosterCard` | A chart position | Outlined numeral (display, stroke foregroundMuted) the poster overlaps, then a `PosterCard` | Trending only; the rank is spoken in the card label |
| `PosterRibbon` | What is new about a title | Solid overlay band across the poster foot: subtitle-sized announcement ("Season 4"), one fact ("8 episodes") | Solid, so poster lettering never competes |
| `ResumeCard` | Pick up playback | 16:9 still as a paused player: kind chip; play control, "Resume", mono clock `position / runtime`, mono time-left stamp; scrubber with thumb; then title (body 600) and facts | Reads as a player before it is clicked |
| `EpisodeCard` | Play a specific episode | 16:9 still stamped with mono `S4 E8` code, "New" badge, mono duration; series eyebrow; episode name (body 600); aired date and rating; two-line synopsis | The episode, not the series, is the subject |
| `SectionHeader` | Name a row | Raised 40 icon tile, subtitle-sized title, optional mono count chip, one-line explanation | Icons name purpose: history, bolt, layers, trending, award, genre glyphs |
| `PreviewCard` | Decide from a tile without leaving the row | Floating surface, borderStrong, radius 12: 16:9 artwork melting into the card fill, optional code and rating chips; optional eyebrow; title (subtitle); facts; Play (primary) and an optional secondary action; genres; four-line synopsis | Shown by `HoverPreview`; tapping the card does what its tile does. `TitlePreview` and `EpisodePreview` fill it from IMDb data |
| `EpisodeRow` | Play one episode of a season | 16:9 still (176, or 128 compact) with code and length stamps; name (body 600); air date and rating; two–three line synopsis | A row on the page plane: stateHover fill, borderSubtle dividers between rows, two columns from 1100 |
| `PersonCard` | Who is in it | Round raised headshot (88, or 72 compact), centred name (label 600) and character (caption, muted) | Informational, not interactive; small so the row reads as credits |
| `ReviewCard` | What viewers thought | Raised tile: mono score and a warning-pair Spoilers badge when flagged; headline (label 600, two lines); four-line excerpt; author and date with mono like and dislike counts | Opens the full review in a floating dialog; spoiler reviews appear only once Show spoilers is on |

### Downloads

Downloading is offered wherever an item can be played, and its state reads the same everywhere. Code: `lib/ui/components/download_button.dart`, `lib/ui/pages/downloads/`, shared actions in `lib/ui/shared/download_actions.dart`.

| Component | Purpose | Anatomy and states | Notes |
| --- | --- | --- | --- |
| `DownloadButton` | Keep a movie or episode offline | Icon button (40) on `EpisodeRow`s and previews; labelled secondary button on the title hero. Download glyph → spinning `DownloadRing` while a torrent is found → determinate ring (action on surfaceInset, 2 stroke) around a 12 glyph: more for queued, arrow for downloading, pause for paused → success check → error glyph on failure. Tooltip and label carry the state and percentage | Once started it opens an `ActionMenu`: pause or resume and cancel; play, show in folder and delete (confirmed); try again and remove. Inside a hover preview, which closes on any tap, it acts directly instead (`menu: false`): downloads, plays, retries, or opens the Downloads page |
| `FollowButton` | Follow a series without watching it | Secondary button: Follow (add), then Following (check, or a download-done glyph while auto-download is on) | Following opens an `ActionMenu` of toggles (notify, download new episodes, hidden while auto-download is off in settings) and a destructive Unfollow |
| `ActionMenu` | Commands on one control | The select menu's floating panel and `MenuOption` rows: a check for toggles, a 16 icon for commands, error foreground for destructive ones | Toggles stay open; commands close it. `SSelect` shares the panel |
| `DownloadRow` | One item on the Downloads page | A row on the page plane: 16:9 still (128, or 96 compact) with its code stamp; series eyebrow; name; a status label with icon in its status role (queued and paused neutral, downloading info, done success, failed error); `TransferStats` that wrap rather than truncate: technical size, then while transferring down and up speed, seeds, peers and time left at fixed slots; a `ProgressTrack` while transferring. On compact the stats and track run the row's full width beneath the artwork | Trailing icon buttons: pause or resume and cancel (confirmed: Keep downloading or Cancel download, the row leaves at once); show in folder and delete; try again and remove. A row plays on tap, with the artwork zoom and primary play glyph on hover or focus; unfinished downloads use the existing streaming launch |

| `SeasonDownloadButton` | Keep a whole season offline | At the end of the season chips (in the Episodes header when there is one season), its right edge on the episode rows' download column. A ghost button with leading glyph and words from medium (Download season, Finding torrents, Downloading 42%, Downloaded), an icon button on compact; the glyphs follow `DownloadButton` with the season's byte share in the ring | Not started: opens the download review (asks first when reviews are off). Started: an `ActionMenu` of pause or resume season, download the rest, show in Downloads and a destructive cancel season |
| Download review | Show the torrents before they download | The play launch's dialog contract. One item: its eyebrow and state heading (Finding a torrent, Ready to download, Closest match, Couldn’t find a torrent), the selected `TorrentOption` with Show N more, countdown track and primary Download in Ns. A batch: eyebrow `Series · Season N`, heading (Finding episodes, Finding torrents, N need a look, Ready to download), a `MetaLine` of counts and size, an inset track filling as each episode is searched, then `ReviewRow`s; primary Download N, disabled while a miss remains, with a ghost Skip N not found | `ReviewRow`: a row on the dialog plane, the episode number in a recessed 40 well, name, a status in its role (exact match and season torrent success, closest match warning, no torrent found error, your choice info, waiting and skipped muted), then filename in technical and a quality, size and seeders line. Tapping opens the item's torrents with Back and Done; a miss has a Skip icon button, a skipped row Undo. Exact batches count down like single items; any action in the review stops the countdown for good. With reviews off in settings, exact matches download without the dialog and only compromises and misses show it. Code: `lib/ui/pages/download_review/`, logic in `lib/library/download_review.dart` |

The Downloads page carries no headline. `SegmentedTabs` at its top split it into Ongoing and Complete, each labelled with its count; Complete adds Open folder at the row's end (an icon button on compact). Opening the page lands on Ongoing while anything is downloading, being found or waiting on a choice, otherwise on Complete; a tab the viewer picks holds until they leave the page. Ongoing: Needs your choice (episodes auto-download could not match exactly, each with Choose torrent, opening the download review, and Dismiss; Review all opens them together), a muted line saying downloads continue while Sentorr is open (or how many torrents are being found), then episodes grouped under a `SeasonHeader`: the season's name, `TransferStats` of episodes done, bytes, combined down and up speed, seeds, peers and time left, one full-width `ProgressTrack` for the season, and Pause or Resume season and Cancel season as icon buttons; Cancel season is confirmed, stops finding and queueing, and removes the unfinished and failed episodes at once, keeping finished ones; seasons whose torrents are still being found head an indeterminate track. Complete: total size, then movies first and each series under its name, each season labelled with its episode count and size (its controls stay in Ongoing). Each tab explains itself when empty, in the page's own rhythm.

### Title page

Cards, the spotlight's More info and recommendations open a title page over the current destination inside the same navigation chrome; the destination beneath keeps its state but takes no input. Opening a recommendation stacks another page; Back, Escape and the page's Back button return one step, and choosing any destination closes them all. Sections, 48 apart: the hero (the spotlight's `HeroFrame` with a circular overlay Back control pinned to its top-left, the poster carrying the rating chip from 960, kind, title, facts including counts and certificate, genres, synopsis, key people by role, Play and, for series, Episodes); a compact round-headshot cast row, kept beside the hero because it is title information; episodes by season chips; More like this; reviews with a Show spoilers chip in the row header. There is no separate details panel: reference facts live in the hero. The hero renders from the catalog summary at once and details fill in; sections without data are omitted rather than shown empty. Code: `lib/ui/pages/title/`.

Typography inside cards: titles are 600 weight; descriptive prose (synopses, row explanations) uses foregroundMuted, or the overlay `foregroundMuted` over artwork, one step quieter than facts; facts are caption with a leading 14 icon; numbers people compare (ratings, clocks, codes, counts) use the technical role, words do not. Metadata lines are single rich-text runs that ellipsize only at the end.

Apply these shared state rules centrally:

- **Focus:** 2-unit focus ring with 2-unit separation, visible beyond the component boundary. An input may use its 2-unit focus border. Focus remains visible during hover and selection.
- **Disabled:** surfaceInset and foregroundDisabled; no hover/pressed feedback or activation. Disabled contrast does not define normal text contrast.
- **Loading:** preserve the control's width and action context, show a progress indicator and prevent duplicate activation; announce busy state.
- **Error:** error foreground on errorSurface or canvas/surface/control, with text explaining what to do. Color alone is insufficient.
- **Fading fills:** animate a fill to its own clear version (`color.clear`), never `Colors.transparent`, which is transparent black and grays light fills midway.
- **Motion:** use ease-out for entry and ease-in-out for state changes. Respect reduced motion by removing nonessential animation and using immediate state changes. No perpetual decorative animation, with one approved exception: the home spotlight advances every 9 s with a 700 ms crossfade and a slow artwork push-in, pauses while hovered or focused, shows its countdown in the active pager dot, and does not advance under reduced motion. Content entering view (tiles, spotlight copy) rises 12 units while fading in, staggered, ease-out.

Normal text must reach 4.5:1 contrast; large text 3:1; essential control boundaries, indicators and focus 3:1 against adjacent colors. Decorative hairlines are intentionally quieter and cannot be the sole cue for an interactive control. Check actual composition, especially images, overlays and pressed states. Support keyboard traversal/activation and text scaling without hiding actions. These are acceptance requirements, not claims that an unbuilt UI has passed them.

## Theme layers

Brand assets follow the same ownership rule: `SentorrBrand` in
`lib/ui/shared/theme/brand.dart` resolves matching light and dark artwork.
Navigation consumes the resolved logo without branching on brightness. Running
desktop icons follow that resolved theme where supported (tray, macOS Dock,
Windows window/taskbar); installed launcher assets keep the dark variant.
Unsupported or failed live updates retain or fall back to the dark icon.

Resolve appearance in this direction:

`theme identity + brightness → primitives → semantic roles → component styles → widgets`

1. **Primitives:** palette values, type metrics, spacing, radii, border widths and motion durations. Name scale entries consistently. Keep raw appearance values inside theme definitions.
2. **Semantic roles:** purpose-based values such as surface, foreground, muted foreground, outline, action, focus and status. Pair backgrounds with foregrounds. Use Flutter's `ColorScheme` and `TextTheme` roles where they fit; add typed extensions for missing roles. A role's meaning must survive a theme change.
3. **Component styles:** resolve shared control appearance, size, padding, shape and interaction states centrally. Use `ThemeData` component themes for Flutter controls; use typed `ThemeExtension` styles for custom Sentorr components as they become necessary.

Components consume semantic roles or resolved component styles, not palette positions. Do not scatter opacity formulas, hex values, font sizes, radii or shadow recipes across screens.

Layout composition may consume named spacing scales directly when a semantic alias adds no meaning. Share reusable layout constraints where needed; screens still decide how content fits available space.

Not every numeric constant is a design token. Aspect ratios, media metadata, seek positions and layout calculations belong with their behavior. Promote repeated visual decisions or intentionally controlled design choices, rather than every number.

## Flutter structure

Proposed location, once the app exists:

```text
lib/ui/shared/theme/
  tokens.dart           # Primitive scales and semantic token types
  theme_definition.dart # An identity with complete light/dark definitions
  theme.dart            # Build ThemeData and resolve component styles
  theme_extensions.dart # Only values not covered by Flutter theme APIs
lib/ui/components/      # Shared widgets consuming the theme
```

Start small; split files as responsibilities grow. Theme selection and persistence belong with settings, not widget styling. Keep identity separate from brightness: initially one identity and light/dark/system selection. New identities should supply the same token contract without requiring branches in feature widgets. A theme editor, import format and preset marketplace are outside the initial scope.

Theme extensions must implement `copyWith` and `lerp`; define interpolation deliberately for values that cannot interpolate. Every identity must resolve a complete set of roles in each supported mode.

## Extending component contracts

When adding a component beyond the fundamental contracts above, document:

| Field       | What to specify                                                                        |
| ----------- | -------------------------------------------------------------------------------------- |
| Purpose     | When it is appropriate and which existing component to reuse                           |
| Variants    | Named intents or sizes; avoid arbitrary styling parameters                             |
| Anatomy     | Content slots, hierarchy and allowed composition                                       |
| Appearance  | Semantic roles and theme-owned dimensions                                              |
| States      | Applicable idle, hover, focus, pressed, selected, disabled, loading and error behavior |
| Interaction | Keyboard behavior, semantics, target size and focus visibility                         |
| Adaptation  | What changes with available space, text scaling and input method                       |

Begin with buttons, icon buttons, inputs, selection controls, surfaces, dialogs and navigation as features need them. Add media cards, status indicators and player controls when their behavior is understood. Do not build an exhaustive component library ahead of use.

Widgets still own structure, semantics and behavior. The theme owns their shared appearance. A custom wrapper is useful when it standardizes behavior or composition; styling alone should use Flutter's existing theme hooks where possible.

## Rules for implementation agents

- Use the supplied after frames as the surface/depth target. Keep their layering consistent with the explicit depth roles above.

- Read this contract and the relevant theme/component implementation before changing UI.
- Reuse existing semantic roles and variants. If a new role is necessary, define its meaning and supply both brightness modes centrally.
- Fix a shared appearance issue at the theme or component contract where it originates. Do not patch individual screens with competing styles.
- Avoid brightness checks and theme-identity checks in feature widgets. Resolve those differences in the theme. An intentionally distinct presentation context, such as controls over video, should have explicit semantic roles.
- Local styles are appropriate for genuine content-specific layout or presentation. Repeated exceptions require a shared variant; explain deliberate one-off visual exceptions beside the code.
- Preserve accessible focus, readable text scaling, reduced-motion behavior and status information that does not rely on color alone.
- Check applicable component states in both modes. Report exactly what was verified. Do not use browser inspection unless explicitly requested.
- Keep this contract synchronized when changing design rules; update Dart definitions when changing values.

## Research

- See [design research](docs/design-research.md) for primary-source examples and the reasoning behind the proposed structure. Research informs the contract. The archived sources in [design references](docs/design-references/README.md) explain provenance; this merged contract controls implementation when those sources conflict.
- See [design demo](tool/design_demo) for a sample flutter app showcasing the design.
