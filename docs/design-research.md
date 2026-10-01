# Design constraints and theme architecture research

Researched 1 October 2026. This note records the initial architecture research. The subsequent Resend/Vercel direction is now locked in [DESIGN.md](../DESIGN.md), with [source snapshots and merge decisions](design-references/README.md). Recommendations below are synthesis, not requirements imposed by the cited sources.

## What agent-readable design files do well

[VoltAgent's awesome-design-md](https://github.com/VoltAgent/awesome-design-md) collects website-derived design documents. Its [Spotify example](https://github.com/VoltAgent/awesome-design-md/blob/main/design-md/spotify/DESIGN.md) combines atmosphere, semantic color roles, typography tables, component recipes, spacing, elevation, explicit prohibitions, responsive behavior and example prompts. Useful pattern: explain both the rule and its purpose, then give concrete component applications. Limitation: these are third-party analyses of brands, not those brands' official systems; a web reference does not establish native-app behavior, font rights, accessibility or complete light/dark support. Adopt the document structure, not the brand values.

[Anthropic's frontend-design skill](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md) connects choices to the product and audience, proposes a compact color/type/layout/principles plan, reviews it against the brief and favors restraint. It explicitly prioritizes a supplied brief over generic stylistic advice. Useful pattern: record rationale and reject arbitrary decoration. Limitation: it is a design process guide, largely oriented toward websites, rather than a Flutter theme architecture or a persistent product contract. Sentorr's approved direction should control agents' choices; agents should not reinvent the look for each feature.

## Flutter already supplies the important seams

[ThemeData](https://api.flutter.dev/flutter/material/ThemeData-class.html) configures the app or a subtree. Material widgets consume its `ColorScheme` and `TextTheme`; it also has dedicated button, input, navigation, menu, dialog and other component themes. Prefer these native slots for standard controls before introducing parallel styling APIs. Flutter's [theming guide](https://docs.flutter.dev/cookbook/design/themes) explains how widgets inherit themes.

[ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html) adds custom typed values to `ThemeData`, with `copyWith` and `lerp` supporting theme transitions. Use extensions for app-specific semantic roles or custom component styles missing from native themes. They need not duplicate standard roles. Theme values describe styling; widgets still own composition, interaction and behavior.

[MaterialApp.themeMode](https://api.flutter.dev/flutter/material/MaterialApp/themeMode.html) selects between `theme` and `darkTheme`, including system brightness. A future theme identity is a separate concern from brightness: each identity can supply the same light/dark contract. Screens should read the resolved theme rather than branch on identity or brightness.

## Recommended token layering

The [Design Tokens Community Group format](https://www.designtokens.org/tr/2025.10/format/) supports typed values, aliases, descriptions and composites such as typography and shadows. Its alias examples distinguish palette values from semantic uses. It does not mandate this exact three-layer architecture; the following is a practical Sentorr recommendation:

| Layer | Responsibility | Consumers |
| --- | --- | --- |
| Primitives | Approved palettes, spacing/shape/type/motion scales | Theme assembly |
| Semantic roles | Surface, content, action, outline, feedback and overlay roles | Native theme assembly and custom widgets |
| Component themes | Named variants and state styling composed from the previous layers | Standard Material controls and shared Sentorr components |

Keep raw palette colors out of screens. Expose spacing primitives where a named scale is sufficient; do not invent a semantic alias for every number. Use `ColorScheme` and `TextTheme` as the standard semantic vocabulary, small `ThemeExtension` classes for missing roles, and native component themes for supported properties. Introduce custom component style extensions only when a real component needs them. Start with typed Dart values; JSON interchange, generators and user-authored theme loading can wait until there is a concrete need.

## Criteria used to form DESIGN.md

1. Product purpose, desired atmosphere, density and visual hierarchy, as supplied by the user.
2. Authority: approved direction in `DESIGN.md`; actual token values and mappings in theme code. Avoid duplicating large value tables across prose and Dart. Resolve conflicts explicitly rather than patching a screen.
3. Theme anatomy and allowed dependencies: primitive → semantic → component → screen; stable semantic roles shared across light/dark and future identities.
4. Fundamental component contracts: action variants, inputs, navigation, surfaces, dialogs, feedback, media tiles and playback controls as needed. Specify hover, focus, pressed, selected, disabled and error states where applicable.
5. Composition rules: hierarchy, content density, responsive layout, poster/backdrop treatment and player overlays. Global visual choices belong to themes; domain behavior and layout composition belong to widgets.
6. Accessibility and input requirements: keyboard focus, text scaling, readable contrast, reduced motion and usable targets. The locked contract now specifies measurable contrast and target-size requirements.
7. Extension rules: reuse existing roles; add a role/variant with a reason when existing ones cannot express a repeated need; reserve local overrides for documented contextual exceptions such as video overlays.
8. Verification expectations: light/dark coverage, component states, overflow/text scaling and appropriate widget or golden checks once implemented. Follow the repository's prohibition on browser inspection unless explicitly requested.

Do not prebuild a complete component library or arbitrary theme engine. Define a narrow contract now and grow it through actual screens. The key extensibility boundary is stable semantic meaning and central component styling, not a large inventory of tokens.
