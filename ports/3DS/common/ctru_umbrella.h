//---------------------------------------------------------------------------------
// ctru_umbrella.h -- single header exposed to Swift as the `CTRU` module.
//
// Celeste only needs core libctru (gfx/hid/apt/ndsp/console) -- no romfs, soc,
// or GPU (citro2d/citro3d) headers, since both screens are hand-rolled software
// rasterizers straight into the LCD framebuffers (see source/Renderer.swift).
//
// <math.h> is included explicitly so newlib's fmodf/sinf/floorf prototypes are
// visible to Swift through this module -- CelesteCore's PicoMath.swift imports
// CTRU (instead of Foundation) for exactly those three functions when built for
// this Embedded Swift target (see that file's `#if canImport(CTRU)` guard).
//---------------------------------------------------------------------------------
#ifndef SWIFT_3DS_UMBRELLA_H
#define SWIFT_3DS_UMBRELLA_H

#include <3ds.h>
#include <math.h>
#include <stdlib.h>
#include "shim.h"
#include "assets.h"

#endif // SWIFT_3DS_UMBRELLA_H
