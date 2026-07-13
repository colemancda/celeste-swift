#---------------------------------------------------------------------------------
#
# Celeste Classic -> Rockbox plugin for iPod Nano 2G.
#
# Two-stage build:
#   1. `make swift`  -- host swiftc compiles CelesteCore + this port's Swift into
#      one Embedded Swift object for armv4t-none-none-eabi (the Nano 2G's
#      ARM940T), audits its undefined symbols, and archives libceleste.a.
#   2. `make rock`   -- syncs plugin/ + libceleste.a into a pinned Rockbox tree
#      and runs Rockbox's own build (configure --target=ipodnano2g) to produce
#      celeste.rock. The arm-elf-eabi-gcc cross toolchain lives in a Docker
#      volume (`make toolchain` builds it once, ~40min) because GCC 9.5 can't
#      be built with an arm64 macOS host natively.
#
#   make install IPOD=/Volumes/<name>  -- copy the .rock onto a mounted iPod.
#   make sim         -- Rockbox UI simulator build (C scaffolding + stub only).
#
#---------------------------------------------------------------------------------

ROCKBOX_SHA     := 078a506dfd0deb18165a3ed80c7fcbdb3afb0d31
SWIFT_TOOLCHAIN ?= $(HOME)/Library/Developer/Toolchains/swift-6.3.2-RELEASE.xctoolchain
SWIFTC          ?= $(SWIFT_TOOLCHAIN)/usr/bin/swiftc
NM              ?= nm
# BSD ar mangles ELF members; the Swift toolchain's llvm-ar (next to swiftc)
# emits GNU format. (:= because make predefines AR=ar, which ?= defers to.)
AR              := $(dir $(SWIFTC))llvm-ar
DOCKER          ?= docker
DOCKER_IMAGE    := debian:bookworm
DOCKER_VOLUME   := rbdev
DOCKER_APT      := build-essential texinfo flex bison wget curl xz-utils bzip2 \
                   patch file ca-certificates zip automake autoconf libtool \
                   libtool-bin perl python3

REPO_ROOT := ../..
BUILD     := build

#---------------------------------------------------------------------------------
# Embedded Swift flags: like the 3DS port's, but ARMv4T soft-float and importing
# the tiny CRockbox shim module instead of libctru.
#---------------------------------------------------------------------------------
SWIFTFLAGS := -target armv4t-none-none-eabi \
              -enable-experimental-feature Embedded \
              -wmo -Osize \
              -module-name Celeste \
              -Xcc -ffreestanding \
              -Xcc -fmodule-map-file=plugin/module.modulemap

CORE_SWIFT := $(wildcard $(REPO_ROOT)/Sources/CelesteCore/*.swift) \
              $(wildcard $(REPO_ROOT)/Sources/CelesteCore/Generated/*.swift)
PORT_SWIFT := $(wildcard source/*.swift)

SFX_WAV := $(wildcard $(REPO_ROOT)/ports/SDL2/Sources/CelesteSDL2/Resources/data/snd*.wav)

.PHONY: all swift audio toolchain rockbox-tree sync rock sim run-sim install clean distclean

all: swift

$(BUILD):
	@mkdir -p $@

#---------------------------------------------------------------------------------
# Stage 1: Swift -> armv4t object -> audited static archive.
# The archive is created with `ar` in GNU format so Rockbox's GNU ld accepts it.
#---------------------------------------------------------------------------------
$(BUILD)/celeste.swift.o: $(CORE_SWIFT) $(PORT_SWIFT) \
		plugin/module.modulemap plugin/rockbox_shim.h | $(BUILD)
	@echo compiling Swift \(engine + port, armv4t\)
	$(SWIFTC) $(SWIFTFLAGS) -c $(CORE_SWIFT) $(PORT_SWIFT) -o $@

$(BUILD)/libceleste.a: $(BUILD)/celeste.swift.o scripts/check-undefined.sh
	sh scripts/check-undefined.sh $< $(NM)
	rm -f $@
	$(AR) crs $@ $<

swift: $(BUILD)/libceleste.a

#---------------------------------------------------------------------------------
# SFX assets: sfx.bin (installed to device/sim disk, not linked into the
# .rock) + audio_tables.h (tiny, linked into mixer.c). See tools/gen_audio.py
# and ports/iPod/README.md's phased audio plan.
#---------------------------------------------------------------------------------
$(BUILD)/audio_tables.h $(BUILD)/sfx.bin: tools/gen_audio.py $(SFX_WAV) | $(BUILD)
	python3 tools/gen_audio.py $(REPO_ROOT) $(BUILD)

audio: $(BUILD)/audio_tables.h $(BUILD)/sfx.bin

#---------------------------------------------------------------------------------
# Stage 2: Rockbox. GCC 9.5 (what Rockbox pins for arm-elf-eabi) can't be
# built natively on arm64 macOS, so there the toolchain and .rock build both
# run inside a Linux container (the toolchain persists in a Docker volume,
# reused across builds). On a native Linux host -- including CI -- neither
# needs Docker at all; rockboxdev.sh and Rockbox's own build run directly,
# which is also what makes `make rock` cheap to run in GitHub Actions with
# $(RBDEV_PREFIX) cached between runs.
#---------------------------------------------------------------------------------
HOST_OS      := $(shell uname -s)
RBDEV_PREFIX ?= $(HOME)/rbdev

rockbox-tree:
	sh scripts/get-rockbox.sh $(ROCKBOX_SHA)

ifeq ($(HOST_OS),Linux)

toolchain: rockbox-tree
	@# rockboxdev.sh resolves its dirs with `readlink -f`, which fails --
	@# silently, thanks to the script's set -e -- when more than the final
	@# path component is missing (i.e. on any machine where RBDEV_PREFIX
	@# doesn't exist yet, like a fresh CI runner on a cache miss).
	mkdir -p $(RBDEV_PREFIX)/dl
	export MAKEFLAGS=-j$$(nproc); \
	yes "" | rockbox/tools/rockboxdev.sh --target=a --prefix=$(RBDEV_PREFIX) \
	    --dlwhere=$(RBDEV_PREFIX)/dl --builddir=/tmp/rbbuild

sync: rockbox-tree audio
	sh scripts/sync-plugin.sh $(abspath rockbox)

rock: swift sync
	PATH="$(RBDEV_PREFIX)/bin:$$PATH" sh -c '\
	    mkdir -p rockbox/build-nano2g && cd rockbox/build-nano2g && \
	    { [ -f Makefile ] || ../tools/configure --target=ipodnano2g --type=n; } && \
	    make -j$$(nproc) rocks && \
	    arm-elf-eabi-size apps/plugins/celeste/celeste.elf 2>/dev/null'
	cp rockbox/build-nano2g/apps/plugins/celeste/celeste.rock $(BUILD)/
	@echo "built $(BUILD)/celeste.rock"

else

toolchain: rockbox-tree
	$(DOCKER) volume create $(DOCKER_VOLUME)
	$(DOCKER) run --rm -v $(DOCKER_VOLUME):/opt/rbdev \
	    -v $(abspath rockbox):/rockbox:ro $(DOCKER_IMAGE) bash -c '\
	    set -e; apt-get update -qq; \
	    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $(DOCKER_APT) >/dev/null; \
	    export MAKEFLAGS=-j$$(nproc); \
	    yes "" | /rockbox/tools/rockboxdev.sh --target=a --prefix=/opt/rbdev \
	        --dlwhere=/opt/rbdev/dl --builddir=/tmp/rbbuild'

sync: rockbox-tree audio
	sh scripts/sync-plugin.sh $(abspath rockbox)

rock: swift sync
	sh scripts/clean-host-tools.sh
	$(DOCKER) run --rm -v $(DOCKER_VOLUME):/opt/rbdev \
	    -v $(abspath rockbox):/rockbox $(DOCKER_IMAGE) bash -c '\
	    set -e; apt-get update -qq; \
	    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
	        build-essential perl zip unzip wget ca-certificates python3 >/dev/null; \
	    export PATH=/opt/rbdev/bin:$$PATH; \
	    mkdir -p /rockbox/build-nano2g; cd /rockbox/build-nano2g; \
	    [ -f Makefile ] || ../tools/configure --target=ipodnano2g --type=n; \
	    make -j$$(nproc) rocks; \
	    arm-elf-eabi-size apps/plugins/celeste.elf 2>/dev/null || true'
	cp rockbox/build-nano2g/apps/plugins/celeste/celeste.rock $(BUILD)/
	@echo "built $(BUILD)/celeste.rock"

endif

# UI simulator (host build; uses celeste_stub.c, needs SDL on the host).
# Rockbox's configure hardcodes gcc-16/gcc-ar-16/cpp-16 on Darwin whenever it
# detects Clang, assuming Homebrew GCC (`brew install gcc`) is on PATH.
sim: sync
	sh scripts/clean-host-tools.sh
	mkdir -p rockbox/build-sim
	PATH="/opt/homebrew/bin:$$PATH" sh -c ' \
	    cd rockbox/build-sim && { [ -f Makefile ] || \
	        ../tools/configure --target=ipodnano2g --type=s; } && $(MAKE)'
	@# rockboxui reads plugins from simdisk/.rockbox/rocks (its simulated
	@# device root), which the plugin build alone doesn't populate.
	mkdir -p rockbox/build-sim/simdisk/.rockbox/rocks/games
	cp rockbox/build-sim/apps/plugins/celeste/celeste.rock \
	    rockbox/build-sim/simdisk/.rockbox/rocks/games/
	mkdir -p rockbox/build-sim/simdisk/.rockbox/celeste
	cp $(BUILD)/sfx.bin rockbox/build-sim/simdisk/.rockbox/celeste/

# Build (if needed) and launch rockboxui from the right directory --
# scripts/run-sim.sh exists because rockboxui's virtual disk path is
# relative to its launch cwd, not its own location.
run-sim: sim
	sh scripts/run-sim.sh

install: $(BUILD)/celeste.rock $(BUILD)/sfx.bin
	@test -n "$(IPOD)" || { echo "usage: make install IPOD=/Volumes/<ipod>"; exit 1; }
	cp $(BUILD)/celeste.rock "$(IPOD)/.rockbox/rocks/games/"
	mkdir -p "$(IPOD)/.rockbox/celeste"
	cp $(BUILD)/sfx.bin "$(IPOD)/.rockbox/celeste/"
	@echo "installed to $(IPOD)/.rockbox/rocks/games/celeste.rock + $(IPOD)/.rockbox/celeste/sfx.bin"

clean:
	rm -rf $(BUILD)

distclean: clean
	rm -rf rockbox
