#!/bin/sh
# Build with the release Nightly identity and icons, without modifying sources.
set -eu
cd "$(dirname "$0")/.."
source_root="$PWD"
nightly_root="$source_root/.dart_tool/nightly-run"
nightly_python="$source_root/.dart_tool/nightly-python/bin/python"

# Branding needs Pillow. Keep its environment local to this checkout.
if [ ! -x "$nightly_python" ]; then
  python3 -m venv "$source_root/.dart_tool/nightly-python"
fi
if ! "$nightly_python" -c 'import PIL' 2>/dev/null; then
  "$nightly_python" -m pip install 'Pillow>=10,<13'
fi

mkdir -p "$nightly_root/tool/release"
# Preserve the mirror's build caches, but refresh source and original artwork
# on every run so the crescent is never applied twice.
for directory in android assets linux macos windows scripts; do
  rsync -a --delete \
    --exclude=build --exclude=.gradle --exclude=Pods --exclude=ephemeral \
    "$source_root/$directory/" "$nightly_root/$directory/"
done
# Dart edits in the real checkout remain visible to Flutter hot reload.
for directory in lib packages; do
  if [ ! -L "$nightly_root/$directory" ]; then
    ln -s "$source_root/$directory" "$nightly_root/$directory"
  fi
done
for file in pubspec.yaml pubspec.lock pubspec_overrides.yaml dart_defines.local.json; do
  if [ -f "$source_root/$file" ]; then
    cp "$source_root/$file" "$nightly_root/$file"
  else
    rm -f "$nightly_root/$file"
  fi
done
cp tool/run.sh tool/generate_icons.py "$nightly_root/tool/"
cp tool/release/nightly_branding.py tool/release/nightly_identity.py "$nightly_root/tool/release/"
"$nightly_python" "$nightly_root/tool/release/nightly_branding.py"
exec sh "$nightly_root/tool/run.sh" --debug --dart-define=UPDATE_CHANNEL=nightly "$@"
