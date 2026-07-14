#!/bin/sh
# rockbox/tools/{bmp2rb,convbdf,...} are tiny host-native helper binaries,
# shared by relative path (../tools) between build-nano2g (built inside the
# Linux/Docker cross container) and build-sim (built natively on macOS).
# Whichever build ran last leaves binaries in the format the other host
# can't execute -- "make rock" after "make sim" fails with a cryptic
# "Syntax error" from the shell trying to interpret a Mach-O as a script,
# and vice versa. Remove them before each build; they're cheap to remake.
set -e

TOOLS="$(cd "$(dirname "$0")/../rockbox/tools" && pwd)"
cd "$TOOLS"
rm -f bmp2rb codepages convbdf mkboot rdf2binary scramble uclpack
