# Sentorr design direction

Sentorr should feel calm, precise and focused on the media. Take typography,
restraint and monochrome chrome from Resend/Vercel, with a layered sense of depth.
Artwork supplies most of the color. Support light and dark modes with the same
visual hierarchy.

This document guides design decisions. Exact values and component behavior live
in the implementation; keep this about enduring principles rather than a catalogue
of screens, features or historical decisions.

## Visual language

- Use neutral surfaces, clear typography and generous but purposeful spacing.
  Keep secondary information quieter than the main content and action.
- Build depth through surface luminance, fine edges and soft local shadows.
  Canvas, grouped panels, raised controls, recessed tracks and floating overlays
  should have a consistent relationship in both modes.
- Group related content without putting a card around everything. Dense lists
  can share a surface with subtle dividers. Avoid excessive nesting and heavy
  outlines.
- Keep actions mostly monochrome. Reserve semantic color for information,
  success, warning and error; always accompany meaningful color with text or shape.
- Use a clear sans-serif hierarchy for ordinary content and monospace or tabular
  figures where technical values need to align. Prefer sentence case.
- Motion should explain state changes and preserve continuity. Keep it restrained,
  avoid layout jumps, and respect reduced motion.

The supplied [light](docs/design-references/depth/after-light.png) and
[dark](docs/design-references/depth/after-dark.png) frames illustrate the intended
surface depth. Treat them as direction for grouping and lighting, not layouts to
copy. [Design references](docs/design-references/README.md) preserve provenance.

## Tokens and theme ownership

Resolve appearance through:

`theme identity + brightness → primitives → semantic roles → component styles → widgets`

- **Primitives:** shared scales for color, typography, spacing, radii, borders,
  icons and motion. Favor a small, consistent vocabulary over isolated values.
- **Semantic roles:** name values by purpose, such as canvas, foreground, action,
  focus and status. Pair foregrounds with backgrounds. Keep their meaning stable
  across light and dark modes.
- **Component styles:** resolve common dimensions, surfaces and interaction states
  centrally. Use Flutter's `ThemeData`, `ColorScheme` and `TextTheme` where they fit;
  typed theme extensions cover Sentorr-specific needs.

Theme definitions in `lib/ui/shared/theme/` own exact values: `tokens.dart` for
shared scales, `colors.dart` for semantic colors, `typography.dart` for type,
`depth.dart` for surfaces and lighting, and `theme.dart` for Flutter integration.
Layout patterns live in `lib/ui/shared/layout/`; reusable components live in
`lib/ui/components/`.

Screens compose those patterns. Fix shared appearance in the theme or component
that owns it; avoid scattered palette values, shadow recipes or brightness
branches. Distinct contexts such as controls over artwork or video should have
explicit semantic roles. Content-specific layout calculations need not become
design tokens.

## Reusable patterns

Reuse existing components and named variants before introducing new ones. Keep
shared appearance in the theme and structure, semantics and behavior in widgets.
Add abstractions when a real repeated need appears.

Adapt composition to available space and input method. Preserve hierarchy and
access to actions as layouts change; allow text to wrap and scale. Use the shared
spacing and layout vocabulary rather than unrelated per-screen breakpoints.

Consider hover, focus, pressed, selected, disabled, loading and error states as
part of a component. Loading should preserve context and avoid disruptive shifts.
Selection and keyboard focus must remain distinct and visible.

Maintain readable contrast, keyboard access, accessible names and suitable touch
targets. Status must remain understandable without color, and depth must never be
the only interaction cue. Check relevant states in both modes and report what was
actually verified.
