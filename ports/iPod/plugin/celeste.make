#             __________               __   ___.
#   Open      \______   \ ____   ____ |  | _\_ |__   _______  ___
#   Source     |       _//  _ \_/ ___\|  |/ /| __ \ /  _ \  \/  /
#   Jukebox    |    |   (  <_> )  \___|    < | \_\ (  <_> > <  <
#   Firmware   |____|_  /\____/ \___  >__|_ \|___  /\____/__/\_ \
#                     \/            \/     \/    \/            \/
#
# Celeste Classic: C plugin scaffolding + prebuilt Embedded Swift engine.
# libceleste.a is produced OUTSIDE this tree (armv4t-none-none-eabi, see
# ports/iPod/Makefile in the celeste-swift repo) and copied here by its
# sync-plugin.sh. Listing a .a as a prerequisite of the .rock links it via
# the generic rule in plugins.make (same mechanic as wav2wv/libwavpack and
# mikmod/$(TLSFLIB)).

CELESTESRCDIR := $(APPSDIR)/plugins/celeste
CELESTEBUILDDIR := $(BUILDDIR)/apps/plugins/celeste

ROCKS += $(CELESTEBUILDDIR)/celeste.rock

CELESTE_SRC := $(call preprocess, $(CELESTESRCDIR)/SOURCES)
CELESTE_OBJ := $(call c2obj, $(CELESTE_SRC))

# add source files to OTHER_SRC to get automatic dependencies
OTHER_SRC += $(CELESTE_SRC)

ifndef APP_TYPE
# Device build: link the Swift engine and the TLSF allocator backing its heap.
$(CELESTEBUILDDIR)/celeste.rock: $(CELESTE_OBJ) $(CELESTESRCDIR)/libceleste.a $(TLSFLIB)
else
# Simulator: celeste_stub.c stands in for the ARM-only Swift objects.
$(CELESTEBUILDDIR)/celeste.rock: $(CELESTE_OBJ)
endif
