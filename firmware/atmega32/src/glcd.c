#include "glcd.h"

/* ------------------------------------------------------------------
 * KS0108 128x64, write-only interface (R/W tied to GND).
 * Rendering is done one page (8 pixel rows) at a time into a 128 byte
 * buffer to keep SRAM usage low on the ATmega32.
 * ------------------------------------------------------------------ */

static uint8_t pagebuf[128];
static uint8_t cur_page;

/* 5x7 font, column major, LSB = top row.
 * Order: 0-9, A-Z, then punctuation (see glyph_index). */
static const uint8_t font5x7[][5] PROGMEM = {
    {0x3E,0x51,0x49,0x45,0x3E}, {0x00,0x42,0x7F,0x40,0x00}, /* 0 1 */
    {0x42,0x61,0x51,0x49,0x46}, {0x21,0x41,0x45,0x4B,0x31}, /* 2 3 */
    {0x18,0x14,0x12,0x7F,0x10}, {0x27,0x45,0x45,0x45,0x39}, /* 4 5 */
    {0x3C,0x4A,0x49,0x49,0x30}, {0x01,0x71,0x09,0x05,0x03}, /* 6 7 */
    {0x36,0x49,0x49,0x49,0x36}, {0x06,0x49,0x49,0x29,0x1E}, /* 8 9 */
    {0x7E,0x11,0x11,0x11,0x7E}, {0x7F,0x49,0x49,0x49,0x36}, /* A B */
    {0x3E,0x41,0x41,0x41,0x22}, {0x7F,0x41,0x41,0x22,0x1C}, /* C D */
    {0x7F,0x49,0x49,0x49,0x41}, {0x7F,0x09,0x09,0x09,0x01}, /* E F */
    {0x3E,0x41,0x49,0x49,0x7A}, {0x7F,0x08,0x08,0x08,0x7F}, /* G H */
    {0x00,0x41,0x7F,0x41,0x00}, {0x20,0x40,0x41,0x3F,0x01}, /* I J */
    {0x7F,0x08,0x14,0x22,0x41}, {0x7F,0x40,0x40,0x40,0x40}, /* K L */
    {0x7F,0x02,0x0C,0x02,0x7F}, {0x7F,0x04,0x08,0x10,0x7F}, /* M N */
    {0x3E,0x41,0x41,0x41,0x3E}, {0x7F,0x09,0x09,0x09,0x06}, /* O P */
    {0x3E,0x41,0x51,0x21,0x5E}, {0x7F,0x09,0x19,0x29,0x46}, /* Q R */
    {0x46,0x49,0x49,0x49,0x31}, {0x01,0x01,0x7F,0x01,0x01}, /* S T */
    {0x3F,0x40,0x40,0x40,0x3F}, {0x1F,0x20,0x40,0x20,0x1F}, /* U V */
    {0x3F,0x40,0x38,0x40,0x3F}, {0x63,0x14,0x08,0x14,0x63}, /* W X */
    {0x07,0x08,0x70,0x08,0x07}, {0x61,0x51,0x49,0x45,0x43}, /* Y Z */
    {0x00,0x00,0x00,0x00,0x00}, {0x00,0x36,0x36,0x00,0x00}, /* sp : */
    {0x08,0x08,0x08,0x08,0x08}, {0x00,0x60,0x60,0x00,0x00}, /* - . */
    {0x20,0x10,0x08,0x04,0x02}, {0x23,0x13,0x08,0x64,0x62}, /* / % */
    {0x00,0x1C,0x22,0x41,0x00}, {0x00,0x41,0x22,0x1C,0x00}, /* ( ) */
    {0x08,0x08,0x3E,0x08,0x08}, {0x00,0x00,0x5F,0x00,0x00}, /* + ! */
    {0x02,0x01,0x51,0x09,0x06}, {0x40,0x40,0x40,0x40,0x40}, /* ? _ */
    {0x14,0x08,0x3E,0x08,0x14}, {0x08,0x14,0x22,0x41,0x00}, /* * < */
    {0x00,0x41,0x22,0x14,0x08}, {0x14,0x7F,0x14,0x7F,0x14}, /* > # */
    {0x14,0x14,0x14,0x14,0x14}, {0x00,0x50,0x30,0x00,0x00}, /* = , */
    {0x00,0x7F,0x41,0x41,0x00}, {0x00,0x41,0x41,0x7F,0x00}  /* [ ] */
};

static uint8_t glyph_index(char c)
{
    if (c >= '0' && c <= '9') return (uint8_t)(c - '0');
    if (c >= 'A' && c <= 'Z') return (uint8_t)(10 + c - 'A');
    if (c >= 'a' && c <= 'z') return (uint8_t)(10 + c - 'a');
    switch (c) {
        case ' ': return 36; case ':': return 37; case '-': return 38;
        case '.': return 39; case '/': return 40; case '%': return 41;
        case '(': return 42; case ')': return 43; case '+': return 44;
        case '!': return 45; case '?': return 46; case '_': return 47;
        case '*': return 48; case '<': return 49; case '>': return 50;
        case '#': return 51; case '=': return 52; case ',': return 53;
        case '[': return 54; case ']': return 55;
        default:  return 46;
    }
}

/* ---------------- low level ---------------- */

static void chip_select(uint8_t chip)
{
    if (chip == 0) { GLCD_CTRL &= ~_BV(PIN_CS1); GLCD_CTRL |=  _BV(PIN_CS2); }
    else           { GLCD_CTRL |=  _BV(PIN_CS1); GLCD_CTRL &= ~_BV(PIN_CS2); }
}

static void en_pulse(void)
{
    GLCD_CTRL |= _BV(PIN_EN);
    _delay_us(2);
    GLCD_CTRL &= ~_BV(PIN_EN);
    _delay_us(2);
}

static void glcd_cmd(uint8_t chip, uint8_t cmd)
{
    chip_select(chip);
    GLCD_CTRL &= ~_BV(PIN_RS);
    GLCD_PORT  = cmd;
    en_pulse();
}

static void glcd_write(uint8_t chip, uint8_t data)
{
    chip_select(chip);
    GLCD_CTRL |= _BV(PIN_RS);
    GLCD_PORT  = data;
    en_pulse();
}

void glcd_init(void)
{
    GLCD_DDR       = 0xFF;
    GLCD_PORT      = 0x00;
    GLCD_CTRL_DDR |= _BV(PIN_CS1) | _BV(PIN_CS2) | _BV(PIN_RS) |
                     _BV(PIN_EN)  | _BV(PIN_RST) | _BV(PIN_BL);
    GLCD_CTRL     &= ~(_BV(PIN_CS1) | _BV(PIN_CS2) | _BV(PIN_RS) | _BV(PIN_EN));

    _delay_ms(20);
    GLCD_CTRL &= ~_BV(PIN_RST);
    _delay_ms(20);
    GLCD_CTRL |=  _BV(PIN_RST);
    _delay_ms(50);

    for (uint8_t c = 0; c < 2; c++) {
        glcd_cmd(c, 0x3F);                 /* display on   */
        glcd_cmd(c, 0xC0);                 /* start line 0 */
    }

    for (uint8_t p = 0; p < 8; p++) {      /* clear the panel */
        glcd_page_begin(p);
        glcd_page_end();
    }
}

void glcd_backlight(uint8_t on)
{
    if (on) GLCD_CTRL |=  _BV(PIN_BL);
    else    GLCD_CTRL &= ~_BV(PIN_BL);
}

/* ---------------- page buffer ---------------- */

void glcd_page_begin(uint8_t page)
{
    cur_page = (uint8_t)(page & 0x07);
    memset(pagebuf, 0x00, sizeof(pagebuf));
}

void glcd_page_end(void)
{
    glcd_cmd(0, (uint8_t)(0xB8 | cur_page));
    glcd_cmd(0, 0x40);
    for (uint8_t i = 0; i < 64; i++) glcd_write(0, pagebuf[i]);

    glcd_cmd(1, (uint8_t)(0xB8 | cur_page));
    glcd_cmd(1, 0x40);
    for (uint8_t i = 0; i < 64; i++) glcd_write(1, pagebuf[64 + i]);
}

/* ---------------- primitives (clipped to current page) ---------------- */

void glcd_pixel(uint8_t x, uint8_t y, uint8_t on)
{
    if (x > 127 || y > 63) return;
    if ((uint8_t)(y >> 3) != cur_page) return;

    uint8_t mask = (uint8_t)(1 << (y & 7));
    if (on) pagebuf[x] |=  mask;
    else    pagebuf[x] &= (uint8_t)~mask;
}

void glcd_hline(uint8_t x0, uint8_t x1, uint8_t y, uint8_t on)
{
    for (uint8_t x = x0; x <= x1 && x < 128; x++) glcd_pixel(x, y, on);
}

void glcd_vline(uint8_t x, uint8_t y0, uint8_t y1, uint8_t on)
{
    for (uint8_t y = y0; y <= y1 && y < 64; y++) glcd_pixel(x, y, on);
}

void glcd_fill(uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1, uint8_t on)
{
    for (uint8_t y = y0; y <= y1 && y < 64; y++)
        for (uint8_t x = x0; x <= x1 && x < 128; x++)
            glcd_pixel(x, y, on);
}

void glcd_rect(uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1, uint8_t on)
{
    glcd_hline(x0, x1, y0, on);
    glcd_hline(x0, x1, y1, on);
    glcd_vline(x0, y0, y1, on);
    glcd_vline(x1, y0, y1, on);
}

/* ---------------- text ---------------- */

void glcd_char(uint8_t x, uint8_t y, char c, uint8_t scale, uint8_t on)
{
    uint8_t idx = glyph_index(c);
    for (uint8_t col = 0; col < 5; col++) {
        uint8_t bits = pgm_read_byte(&font5x7[idx][col]);
        for (uint8_t row = 0; row < 7; row++) {
            if (bits & (uint8_t)(1 << row)) {
                if (scale <= 1) {
                    glcd_pixel((uint8_t)(x + col), (uint8_t)(y + row), on);
                } else {
                    uint8_t px = (uint8_t)(x + col * scale);
                    uint8_t py = (uint8_t)(y + row * scale);
                    glcd_fill(px, py, (uint8_t)(px + scale - 1), (uint8_t)(py + scale - 1), on);
                }
            }
        }
    }
}

void glcd_text(uint8_t x, uint8_t y, const char *s, uint8_t scale, uint8_t on)
{
    while (*s) {
        glcd_char(x, y, *s++, scale, on);
        x = (uint8_t)(x + 6 * scale);
        if (x > 126) break;
    }
}

uint8_t glcd_text_width(const char *s, uint8_t scale)
{
    return (uint8_t)(strlen(s) * 6 * scale);
}
