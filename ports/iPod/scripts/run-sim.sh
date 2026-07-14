#!/bin/sh
# Build (if needed) and launch the Rockbox UI simulator with celeste.rock
# already installed. Exists because rockboxui resolves its virtual disk as
# ./simdisk relative to the *launch* directory (SIMULATOR_DEFAULT_ROOT), not
# to the binary's own location -- running it from anywhere else silently
# shows an empty plugin list.
set -e

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SIMDIR="$HERE/rockbox/build-sim"

if [ ! -x "$SIMDIR/rockboxui" ] || [ "$1" = "--rebuild" ]; then
    make -C "$HERE" sim
fi

cd "$SIMDIR"
exec ./rockboxui
