#!/bin/sh
# Run from any directory with this checkout's local build-time configuration.
set -eu
cd "$(dirname "$0")/.."
exec flutter run --dart-define-from-file=dart_defines.local.json "$@"
