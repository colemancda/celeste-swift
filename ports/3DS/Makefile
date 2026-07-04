#---------------------------------------------------------------------------------
# ports/3DS -- Nintendo 3DS port of Celeste Classic, built with Embedded Swift.
#
# Same shape as junkbot-swift's ports/3DS: the ARM11 binary is CelesteCore (the
# shared engine, compiled straight from ../../Sources/CelesteCore) plus this
# port's source/, targeting armv6-none-none-eabi (the 3DS's ARM11 application
# CPU is an ARMv6K core), linked against libctru, and packaged as a homebrew
# .3dsx with 3dsxtool/smdhtool.
#
# Prerequisites:
#   - devkitPro with devkitARM and libctru (`dkp-pacman -S 3ds-dev`;
#     export DEVKITPRO=/opt/devkitpro, DEVKITARM=$DEVKITPRO/devkitARM)
#   - 3dsxtool and smdhtool (devkitPro's 3ds-tools/general-tools, normally at
#     $(DEVKITPRO)/tools/bin alongside 3ds-dev)
#   - A Swift toolchain whose Embedded stdlib ships an armv6-none-none-eabi slice
#
# Unlike junkbot-swift's 3DS port, Celeste's sprite sheet/font/tilemap are tiny
# (~8-11KB each) and already live as plain Swift array literals in
# Sources/CelesteCore/Generated/ -- they're compiled straight into the ELF like
# any other Swift constant, no bin2s blob/offset-table generation step needed.
# Only audio (tools/gen_audio.py, sndN.wav/musN.ogg -> sfx.bin/music.bin PCM16)
# needs a build-time asset step, and only music needs afconvert (macOS-only)
# since sndN.wav is already 16-bit PCM.
#---------------------------------------------------------------------------------
.SUFFIXES:

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitpro")
endif
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=$$DEVKITPRO/devkitARM")
endif

SWIFTC		?=	swiftc

TARGET		:=	Celeste
BUILD		:=	build
REPO_ROOT	:=	../..
COMMON		:=	common/

CTRULIB		?=	$(DEVKITPRO)/libctru

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
LD		:=	$(PREFIX)gcc

3DSXTOOL	?=	3dsxtool
SMDHTOOL	?=	smdhtool
ICON		:=	$(CTRULIB)/default_icon.png

#---------------------------------------------------------------------------------
# code generation -- the 3DS's ARM11 application CPU, armv6k/mpcore, hard float.
#---------------------------------------------------------------------------------
ARCH		:=	-march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CTRUDEFS	:=	-D__3DS__ -I$(COMMON) -I$(CTRULIB)/include

CFLAGS		:=	-g -Wall -O2 -mword-relocations -ffunction-sections -fdata-sections \
			$(ARCH) $(CTRUDEFS)

LDFLAGS		:=	-specs=3dsx.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(CTRULIB)/lib

LIBS		:=	-lctru -lm

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv6-none-none-eabi.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv6-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name Celeste \
			-Xcc -D__3DS__ \
			-Xcc -march=armv6k -Xcc -mtune=mpcore -Xcc -mfloat-abi=hard \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(CTRULIB)/include \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

#---------------------------------------------------------------------------------
# Sources: the shared engine + this port. Generated audio Swift (offset/length/
# sampleRate tables) is emitted into $(BUILD) by tools/gen_audio.py alongside
# the PCM blobs it describes.
#---------------------------------------------------------------------------------
CORE_SWIFT	:=	$(wildcard $(REPO_ROOT)/Sources/CelesteCore/*.swift) \
			$(wildcard $(REPO_ROOT)/Sources/CelesteCore/Generated/*.swift)
PORT_SWIFT	:=	$(wildcard source/*.swift)
GEN_SWIFT	:=	$(BUILD)/AudioAssets.swift
GEN_BINS	:=	$(BUILD)/sfx.bin $(BUILD)/music.bin

OFILES		:=	$(BUILD)/celeste.swift.o $(BUILD)/shim.o \
			$(BUILD)/sfx_bin.o $(BUILD)/music_bin.o

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).3dsx

$(BUILD):
	@mkdir -p $@

# Audio conversion: sndN.wav (already PCM16) + musN.ogg (afconvert-decoded,
# macOS-only) -> sfx.bin/music.bin PCM16 blobs + Swift offset/length/rate
# tables (see tools/gen_audio.py and source/Audio.swift).
$(BUILD)/audio.stamp: tools/gen_audio.py | $(BUILD)
	@echo generating audio assets
	python3 tools/gen_audio.py $(REPO_ROOT) $(BUILD)
	@touch $@

$(BUILD)/sfx.bin $(BUILD)/music.bin $(BUILD)/AudioAssets.swift: $(BUILD)/audio.stamp

# bin2s: asset blob -> assembly -> object.
$(BUILD)/%_bin.s: $(BUILD)/%.bin
	@echo bin2s $(notdir $<)
	bin2s -a 4 $< > $@

$(BUILD)/%_bin.o: $(BUILD)/%_bin.s
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

# All Swift (engine + port + generated) -> one object, whole-module.
$(BUILD)/celeste.swift.o: $(CORE_SWIFT) $(PORT_SWIFT) $(GEN_SWIFT) \
		$(COMMON)module.modulemap $(COMMON)ctru_umbrella.h $(COMMON)shim.h $(COMMON)assets.h | $(BUILD)
	@echo compiling Swift \(engine + port\)
	$(SWIFTC) $(SWIFTFLAGS) -c $(CORE_SWIFT) $(PORT_SWIFT) $(GEN_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(BUILD)/icon.smdh: | $(BUILD)
	@echo packaging icon
	$(SMDHTOOL) --create Celeste "Celeste Classic (swift-3ds)" "celeste-swift" $(ICON) $@

$(TARGET).3dsx: $(TARGET).elf $(BUILD)/icon.smdh
	@echo packaging $(notdir $@)
	$(3DSXTOOL) $(TARGET).elf $@ --smdh=$(BUILD)/icon.smdh

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).3dsx $(TARGET).map
