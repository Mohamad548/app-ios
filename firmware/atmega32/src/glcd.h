#ifndef GLCD_H
#define GLCD_H

#include "board.h"

/*
 * KS0108 128x64, write-only interface (R/W tied to GND).
 *
 * RAM is very tight on the ATmega32 (2 KB), so instead of a 1 KB shadow
 * framebuffer the display is rendered page by page into a 128 byte buffer:
 *
 *   for (p = 0; p < 8; p++) { glcd_page_begin(p); ...draw...; glcd_page_end(); }
 *
 * Every drawing primitive clips to the page being rendered, so the same
 * layout code can be called for each page.
 */

void    glcd_init(void);
void    glcd_backlight(uint8_t on);
void    glcd_page_begin(uint8_t page);   /* 0..7 */
void    glcd_page_end(void);

void    glcd_pixel(uint8_t x, uint8_t y, uint8_t on);
void    glcd_hline(uint8_t x0, uint8_t x1, uint8_t y, uint8_t on);
void    glcd_vline(uint8_t x, uint8_t y0, uint8_t y1, uint8_t on);
void    glcd_fill(uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1, uint8_t on);
void    glcd_rect(uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1, uint8_t on);

void    glcd_char(uint8_t x, uint8_t y, char c, uint8_t scale, uint8_t on);
void    glcd_text(uint8_t x, uint8_t y, const char *s, uint8_t scale, uint8_t on);
uint8_t glcd_text_width(const char *s, uint8_t scale);

#endif /* GLCD_H */
