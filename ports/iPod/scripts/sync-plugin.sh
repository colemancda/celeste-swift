#!/bin/sh
# Copy the celeste plugin sources + prebuilt libceleste.a into the Rockbox
# tree and (idempotently) register the plugin in SUBDIRS/CATEGORIES.
set -e

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROCKBOX="${1:-$HERE/rockbox}"
PLUGDIR="$ROCKBOX/apps/plugins/celeste"

[ -d "$ROCKBOX/apps/plugins" ] || {
    echo "error: no Rockbox tree at $ROCKBOX (run get-rockbox.sh first)" >&2
    exit 1
}

mkdir -p "$PLUGDIR"
cp "$HERE"/plugin/celeste.c \
   "$HERE"/plugin/celeste_stub.c \
   "$HERE"/plugin/rockbox_shim.c \
   "$HERE"/plugin/rockbox_shim.h \
   "$HERE"/plugin/mixer.c \
   "$HERE"/plugin/SOURCES \
   "$HERE"/plugin/celeste.make \
   "$PLUGDIR/"

if [ -f "$HERE/build/libceleste.a" ]; then
    cp "$HERE/build/libceleste.a" "$PLUGDIR/"
else
    echo "note: build/libceleste.a not present yet (fine for sim builds)"
fi

if [ -f "$HERE/build/audio_tables.h" ]; then
    cp "$HERE/build/audio_tables.h" "$PLUGDIR/"
else
    echo "note: build/audio_tables.h not present yet (run make audio first)"
fi

# Register in SUBDIRS (cpp-preprocessed) and CATEGORIES, once.
if ! grep -q '^celeste$' "$ROCKBOX/apps/plugins/SUBDIRS"; then
    cat >> "$ROCKBOX/apps/plugins/SUBDIRS" <<'EOF'

/* Celeste Classic (Embedded Swift engine; see apps/plugins/celeste) */
#if defined(HAVE_LCD_COLOR) && (LCD_DEPTH == 16) && (LCD_WIDTH >= 176) && (LCD_HEIGHT >= 132)
celeste
#endif
EOF
    echo "registered celeste in SUBDIRS"
fi

if ! grep -q '^celeste,' "$ROCKBOX/apps/plugins/CATEGORIES"; then
    echo "celeste,games" >> "$ROCKBOX/apps/plugins/CATEGORIES"
    echo "registered celeste in CATEGORIES"
fi

echo "plugin synced into $PLUGDIR"
