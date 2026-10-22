# Platform integration and updates audit

> Repair update (22 October 2026): the recorded findings have implementation
> fixes in [the repair report](fixes-2026-10-22.md). This document preserves
> the original audit evidence and its validation limits.

Date: 22 October 2026. Checkpoint 9 of the critical-module sanity checks.
Status: audit complete; four medium-priority findings remain open.
No production code changed by this audit. Concurrent work advanced HEAD during
inspection; the final observed HEAD was
`b94188e28ceebcaf82ce5f484e47d215b5a08f22`.

## Scope and validation

Reviewed update manifest authentication, artifact verification/recovery,
platform installers, Sparkle bridge, release workflow wiring, tray/window
lifecycle, login startup, notification permissions and notification navigation.

Existing checks:

```sh
flutter test --no-pub --concurrency=1 --reporter expanded test/updates test/ui/desktop_tray_controller_test.dart test/ui/update_navigation_test.dart
flutter test --no-pub --concurrency=1 --reporter expanded test/shared/signed_envelope_test.dart test/shared/application_identity_test.dart
python3 -m unittest discover -s tool/release/tests
```

24 focused update/tray/navigation tests and 3 signed-envelope/identity tests
passed, with no skips. Both release-tool tests passed using the bundled Python
runtime. The initial system-Python run could not import Pillow; this was an
environment dependency failure, not a release-code finding.

Three isolated diagnostic tests passed while asserting the defective behavior
below. They use mocked method channels and the production Dart services. Logs
and probes are under `/tmp/sentorr-sanity-9/`: `tests.log`, `trust-tests.log`,
`release-tests.log`, `platform_probe_test.dart`, and `probes.log`.

## S9-01 — Medium: notification denial stays cached after system permission changes

Source: `lib/notifications/notification_service.dart:115` and `:135`.

`requestPermission` stores both true and false in `_permitted` for the lifetime
of the service. Once denied, later notification attempts return false without
checking the platform again. Enabling notifications in OS settings therefore
cannot recover delivery in the running service.

A mocked macOS channel first returned denial. Its permission fixture was then
changed to granted before `showDownload`. Only one permission request occurred
and the plugin's show operation was never called. No real OS permission was
changed. The inverse cache can also become stale, but actual denied-system
handling after a cached grant was not probed.

Fix direction: refresh permission status on resume or before delivery, and
avoid indefinitely caching denial. Regress denial followed by an external grant.

## S9-02 — Medium: notification launch target is not recovered at startup

Sources: `lib/notifications/notification_service.dart:82`,
`lib/ui/components/notification_taps.dart`, and `lib/app/bootstrap.dart`.

Initialization installs the running-app response callback but never calls
`getNotificationAppLaunchDetails`. The pinned notification plugin explicitly
separates running-app callbacks from notification launches. Bootstrap initializes
the service before the navigation subscriber is mounted, so launch actions also
need retention until the UI is ready.

A mocked macOS plugin channel offered a downloads launch payload. Initialization
called only `initialize`; it never requested launch details and emitted no tap
target. This establishes the missing Dart integration, not a physical
notification-click test. The relevant plugin behavior was checked in its local
22.3.1 source. Senpwai's notification service provides an existing reference:
`_captureLaunchNotificationResponse` plus pending action events.

Fix direction: capture launch details, retain the initial target until a
navigation listener is ready, and dispatch it once. Test both cold-start and
already-running notification taps.

## S9-03 — Medium: tray initialization can complete after disposal

Source: `lib/ui/shared/desktop_tray_controller.dart:47` and `:154`.

Initialization awaits native icon creation without checking disposal before
setting `_initialized = true` and attaching the window visibility listener.
Disposal sets `_disposed`, clears initialization and destroys the icon; a delayed
initialization continuation can subsequently recreate initialized state. Repeated
disposal returns early because `_disposed` is already true.

The diagnostic held the mocked `setIcon` reply, disposed the controller, then
released initialization. `canHideWindow` changed from false back to true even
though the tray listener had been removed. A second disposal performed no
additional plugin cleanup. Native icon recreation and an actually stranded
window were not tested; the inconsistent state and missing repeat cleanup were.

Fix direction: invalidate initialization with a generation, check it after
native awaits, and clean up any resource created by an obsolete attempt.

## S9-04 — Medium: stable and nightly share login-startup registration

Source-inspected finding, not a native runtime reproduction.

`lib/ui/shared/launch_at_startup_manager.dart:34` always configures
`appName: 'Sentorr'` and `packageName: 'com.sentorr.sentorr'`, regardless of
`ApplicationIdentity`. The nightly identity transformation script does not
change this Dart file. Bootstrap calls `init` with the installation's preference
on every startup, which explicitly enables or disables that registration.

The pinned launch_at_startup 0.5.1 source uses the app name as the Linux
`~/.config/autostart/Sentorr.desktop` filename and Windows Run/StartupApproved
registry value name. The two installations consequently target the same entry:
enabling one replaces its target, while launching the other with startup Off
removes it. This conclusion follows directly from the app and dependency source;
no real autostart file or registry entry was written. The macOS implementation
uses a native channel rather than these names, so this specific collision claim
is limited to Linux/Windows.

Fix direction: derive startup registration identity from the installation
channel and preserve the existing stable name. Add a stable/nightly registration
contract test and a disposable platform smoke check.

## Update protections exercised or inspected

- Signed-envelope decoding and prepared-update restoration tests check that
  stored recovery state cannot independently authorize installation.
- Artifact size and SHA-256 checks reject altered files; artifact metadata
  rejects directory traversal and unsupported URL authorities.
- Release selection respects platform/architecture/channel and version/build
  ordering. Update navigation reaches the existing Updates settings surface.
- Source inspection confirms re-verification before non-macOS installation,
  Android system installer handoff and FileProvider paths for both data roots,
  Linux replacement/backup staging and Windows installer verification.
- Sparkle has a public trust key, installer-service entitlements and explicit
  ready/install callbacks; the release workflow verifies packaged signatures
  and creates appcasts. Native signing and Sparkle callbacks were not executed.
- Release-tool tests exercise appcast preservation and nightly branding in a
  scratch checkout, without signing material or production publication.
- Existing tray tests verify normal replacement/cleanup and menu callbacks.
  Linux deliberately does not advertise tray-only hiding as safe.

## Boundaries and next step

No browser inspection, app launch, login item mutation, real notification,
installer execution, public release publication or signing-secret access was
performed. No live feed or CI run was checked. Platform conclusions come from
current local source, focused tests and mocked native boundaries, not verified
Windows/Linux/Android behavior or end-to-end macOS Sparkle installation.
The earlier shutdown/checkpoint failure remains open and is not counted again.

Unrelated concurrent work and figure directories were preserved. Next:
whole-app failure journeys (checkpoint 10).
