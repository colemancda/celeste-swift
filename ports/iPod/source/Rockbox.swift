import CRockbox

/// Swift-facing wrapper over the C shim (the `CRockbox` clang module,
/// following the C-module naming convention). Port code calls these instead
/// of the raw `rb_*` C functions, keeping the C surface in one place.
///
/// Note this is a namespace, not a separately compiled Swift module: the
/// whole port builds as one `-wmo` module (`Celeste`, see SWIFTFLAGS in
/// ports/iPod/Makefile), matching how the 3DS port structures its interop.
enum Rockbox {
    /// Fire-and-forget sound effect by Celeste sound id (mixer.c voice slot).
    static func sfx(_ id: Int) {
        rb_audio_sfx(Int32(id))
    }

    /// Play/crossfade music track `index` (multiple of 10, -1 stops) over
    /// `fadeMs`. No-op until the music phase lands (see mixer.c).
    static func music(index: Int, fadeMs: Int) {
        rb_audio_music(Int32(index), Int32(fadeMs))
    }

    /// Fixed-arity debug print (Embedded Swift can't call varargs; splash-
    /// based and compiled out unless CELESTE_DEBUG -- see rockbox_shim.c).
    static func log(_ message: StaticString) {
        rb_puts(UnsafeRawPointer(message.utf8Start).assumingMemoryBound(to: CChar.self))
    }
}
