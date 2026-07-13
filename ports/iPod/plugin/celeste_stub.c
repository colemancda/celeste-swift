/***************************************************************************
 *
 * celeste_stub.c -- SIMULATOR-only stand-ins for the Embedded Swift entry
 * points, so the C scaffolding (loop, pacing, blit, buttons, pause menu)
 * can be exercised in the Rockbox UI simulator on the host, where the
 * armv4t libceleste.a can't link. Draws a moving test pattern that reacts
 * to the input mask.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 ****************************************************************************/

#include "plugin.h"

#define GAME_W 128
#define GAME_H 128

static unsigned short *fb;
static unsigned frame_no;
static int px = GAME_W / 2, py = GAME_H / 2;

int celeste_shim_init(void)
{
    return 0;
}

int celeste_init(unsigned short *canvas, unsigned seed)
{
    fb = canvas;
    frame_no = seed;
    return 0;
}

int celeste_frame(unsigned char buttons)
{
    int x, y;

    if (fb == NULL)
        return -1;

    frame_no++;
    if (buttons & (1 << 0)) px--;
    if (buttons & (1 << 1)) px++;
    if (buttons & (1 << 2)) py--;
    if (buttons & (1 << 3)) py++;
    px = (px + GAME_W) % GAME_W;
    py = (py + GAME_H) % GAME_H;

    for (y = 0; y < GAME_H; y++)
        for (x = 0; x < GAME_W; x++)
            fb[y * GAME_W + x] = (unsigned short)
                ((((x + frame_no) & 0x1f) << 11) | (((y + frame_no) & 0x3f) << 5));

    /* cursor square; flashes white while jump/dash are held */
    for (y = py - 3; y <= py + 3; y++)
        for (x = px - 3; x <= px + 3; x++)
            if (x >= 0 && x < GAME_W && y >= 0 && y < GAME_H)
                fb[y * GAME_W + x] =
                    (buttons & ((1 << 4) | (1 << 5))) ? 0xffff : 0x0000;

    return 0;
}

void celeste_restart(void)
{
    px = GAME_W / 2;
    py = GAME_H / 2;
}
