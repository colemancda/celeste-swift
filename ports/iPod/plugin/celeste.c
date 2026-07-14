/***************************************************************************
 *
 * Celeste Classic for Rockbox (iPod Nano 2G and other 176x132+ RGB565
 * targets) -- C host for the Embedded Swift engine in libceleste.a
 * (built from celeste-swift's CelesteCore by ports/iPod/Makefile).
 *
 * This file owns everything Rockbox-shaped: the 30Hz loop, button mapping,
 * pacing, blitting, pause/quit. The Swift side (celeste_init/frame/restart)
 * only simulates and rasterizes into `canvas`. See ports/iPod/README.md in
 * the celeste-swift repository.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 ****************************************************************************/

#include "plugin.h"

/* Embedded Swift entry points (libceleste.a; see source/Plugin.swift). The
 * simulator build substitutes celeste_stub.c for all of these. */
extern int celeste_init(unsigned short *canvas, unsigned seed);
extern int celeste_frame(unsigned char buttons);
extern void celeste_restart(void);
/* rockbox_shim.c (or celeste_stub.c on sim): allocator arena setup. */
extern int celeste_shim_init(void);
/* mixer.c: sfx.bin loading + playback (built for both device and sim --
 * it's plain C, no ARM Swift involved). */
extern int celeste_audio_init(void);
extern void celeste_audio_shutdown(void);

/* CelesteInputState bit order (Sources/CelesteCore/Input.swift). */
#define CELESTE_LEFT  (1 << 0)
#define CELESTE_RIGHT (1 << 1)
#define CELESTE_UP    (1 << 2)
#define CELESTE_DOWN  (1 << 3)
#define CELESTE_JUMP  (1 << 4)
#define CELESTE_DASH  (1 << 5)

#define GAME_W 128
#define GAME_H 128
#define GAME_X ((LCD_WIDTH - GAME_W) / 2)
#define GAME_Y ((LCD_HEIGHT - GAME_H) / 2)

/* The Swift renderer plots RGB565 into this; we blit it after each frame. */
static fb_data canvas[GAME_W * GAME_H];

/* Dash-direction assist: MENU/PLAY held within the last few frames still
 * count as up/down at the instant a wheel-flick dash fires, so diagonals
 * don't demand perfectly simultaneous holds on the click wheel. */
#define VERT_ASSIST_FRAMES 4

/*
 * Control scheme A ("buttons + wheel-flick dash"):
 *   LEFT/RIGHT  move    MENU  up      PLAY  down
 *   SELECT      jump    wheel flick   dash
 *   HOLD switch pause menu
 *
 * The scroll strip only delivers momentary BUTTON_SCROLL_FWD/BACK events
 * (they can't be held), which suits dash: the engine edge-triggers it, so a
 * single latched frame is enough. Everything hold-able sits on real buttons.
 */
static unsigned char poll_buttons(bool *usb, bool *pause)
{
    unsigned char mask = 0;
    static int up_recent, down_recent;
    bool dash = false;
    int held;
    long ev;

    /* Drain queued events: scroll ticks (dash) + system events (USB). */
    while ((ev = rb->button_get(false)) != BUTTON_NONE) {
        if (ev & (BUTTON_SCROLL_FWD | BUTTON_SCROLL_BACK))
            dash = true;
        if (rb->default_event_handler(ev) == SYS_USB_CONNECTED)
            *usb = true;
    }

    held = rb->button_status();
    if (held & BUTTON_LEFT)   mask |= CELESTE_LEFT;
    if (held & BUTTON_RIGHT)  mask |= CELESTE_RIGHT;
    if (held & BUTTON_MENU)   mask |= CELESTE_UP;
    if (held & BUTTON_PLAY)   mask |= CELESTE_DOWN;
    if (held & BUTTON_SELECT) mask |= CELESTE_JUMP;

    up_recent   = (held & BUTTON_MENU) ? VERT_ASSIST_FRAMES
                                       : (up_recent   > 0 ? up_recent   - 1 : 0);
    down_recent = (held & BUTTON_PLAY) ? VERT_ASSIST_FRAMES
                                       : (down_recent > 0 ? down_recent - 1 : 0);

    if (dash) {
        mask |= CELESTE_DASH;
        if (!(mask & (CELESTE_UP | CELESTE_DOWN))) {
            if (up_recent > 0)   mask |= CELESTE_UP;
            if (down_recent > 0) mask |= CELESTE_DOWN;
        }
    }

#ifdef HAS_BUTTON_HOLD
    *pause = rb->button_hold();
#else
    (void)pause;
#endif
    return mask;
}

/* Returns true if the user chose Quit. */
static bool pause_menu(void)
{
    MENUITEM_STRINGLIST(menu, "Celeste", NULL,
                        "Resume", "Restart", "Quit");

#ifdef HAS_BUTTON_HOLD
    /* Buttons are dead while HOLD is on; wait for it to be released. */
    if (rb->button_hold()) {
        rb->splash(0, "Paused - slide HOLD off to continue");
        while (rb->button_hold())
            rb->sleep(HZ / 10);
    }
#endif

    switch (rb->do_menu(&menu, NULL, NULL, false)) {
    case 1:
        celeste_restart();
        break;
    case 2:
        return true;
    default:
        break;
    }

    /* The menu painted over us; repaint the frame border. */
    rb->lcd_clear_display();
    rb->lcd_update();
    return false;
}

enum plugin_status plugin_start(const void *parameter)
{
    enum plugin_status status = PLUGIN_OK;
    bool quit = false;
    long target;
    int subframe = 0; /* 30Hz on a HZ=100 tick: frame lengths 3,3,4 */

    (void)parameter;

    if (celeste_shim_init() != 0) {
        rb->splash(HZ * 2, "celeste: allocator init failed");
        return PLUGIN_ERROR;
    }

#ifdef HAVE_ADJUSTABLE_CPU_FREQ
    rb->cpu_boost(true);
#endif

    rb->lcd_clear_display();
    rb->lcd_update();
    rb->srand(*rb->current_tick);

    /* Best-effort: a missing/unreadable sfx.bin just means a silent game,
     * not a failure to launch. */
    celeste_audio_init();

    if (celeste_init(canvas, (unsigned)*rb->current_tick) != 0) {
        rb->splash(HZ * 2, "celeste: engine init failed");
        status = PLUGIN_ERROR;
        goto out;
    }

    target = *rb->current_tick;
    while (!quit) {
        bool usb = false, pause = false;
        unsigned char buttons = poll_buttons(&usb, &pause);

        if (usb) {
            status = PLUGIN_USB_CONNECTED;
            break;
        }
        if (pause) {
            if (pause_menu())
                break;
            target = *rb->current_tick;
            continue;
        }

        if (celeste_frame(buttons) != 0) {
            rb->splash(HZ * 2, "celeste: frame failed");
            status = PLUGIN_ERROR;
            break;
        }

        rb->lcd_bitmap(canvas, GAME_X, GAME_Y, GAME_W, GAME_H);
        rb->lcd_update_rect(GAME_X, GAME_Y, GAME_W, GAME_H);

        target += (subframe == 2) ? 4 : 3;
        subframe = (subframe + 1) % 3;
        if (TIME_AFTER(target, *rb->current_tick))
            rb->sleep(target - *rb->current_tick);
        else {
            rb->yield();
            target = *rb->current_tick; /* dropped behind; don't spiral */
        }
    }

out:
    celeste_audio_shutdown();
#ifdef HAVE_ADJUSTABLE_CPU_FREQ
    rb->cpu_boost(false);
#endif
    return status;
}
