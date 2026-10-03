#!/bin/sh
# Flutter may refresh native frameworks during incremental builds. Seal the
# containing bundle after all embedding has completed, then verify the result.
set -eu
if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo "Usage: $0 /path/to/Sentorr.app" >&2
  exit 64
fi
codesign --force --sign - --preserve-metadata=entitlements,requirements,flags,runtime "$1"
codesign --verify --deep --strict "$1"
