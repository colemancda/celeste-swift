#!/bin/sh
# Shallow-fetch the Rockbox source tree at a pinned SHA into ports/iPod/rockbox
# (gitignored -- it's a build input, not part of this repo).
set -e

SHA="${1:?usage: get-rockbox.sh <sha> [dest]}"
DEST="${2:-$(dirname "$0")/../rockbox}"
REMOTE="https://github.com/Rockbox/rockbox.git"

mkdir -p "$DEST"
cd "$DEST"

if [ -d .git ] && [ "$(git rev-parse HEAD 2>/dev/null)" = "$SHA" ]; then
    echo "rockbox already at $SHA"
    exit 0
fi

[ -d .git ] || git init -q .
git remote add origin "$REMOTE" 2>/dev/null || git remote set-url origin "$REMOTE"
git fetch --depth 1 origin "$SHA"
git checkout -q "$SHA"
echo "rockbox checked out at $SHA"
