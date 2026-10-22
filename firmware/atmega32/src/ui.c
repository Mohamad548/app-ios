#include "ui.h"
#include "glcd.h"
#include "touch.h"
#include "app.h"

static char    status_msg[22] = "READY";
static uint8_t s_csq = 99;
static uint8_t s_reg = 0;

/* ---------------- helpers ---------------- */

static void beep(uint16_t ms)
{
    BUZZER_PORT |=  _BV(PIN_BUZZER);
    _delay_ms(ms);
    BUZZER_PORT &= ~_BV(PIN_BUZZER);
}

static void draw_header(void)
{
    glcd_fill(0, 0, 127, 11, 1);
    glcd_text(3, 2, "SMS RELAY", 1, 0);

    const char *s;
    if (!s_reg)          s = "NO NET";
    else if (s_csq < 10) s = "GSM 1";
    else if (s_csq < 15) s = "GSM 2";
    else if (s_csq < 20) s = "GSM 3";
    else                 s = "GSM OK";

    glcd_text((uint8_t)(127 - glcd_text_width(s, 1) - 3), 2, s, 1, 0);
}

static void draw_cell(uint8_t i)
{
    uint8_t on = app_relay(i);
    uint8_t x0 = (i & 1) ? 65 : 2;
    uint8_t y0 = (i & 2) ? 35 : 15;
    uint8_t x1 = (uint8_t)(x0 + 60);
    uint8_t y1 = (uint8_t)(y0 + 17);

    if (on) glcd_fill(x0, y0, x1, y1, 1);
    glcd_rect(x0, y0, x1, y1, 1);

    char lbl[3] = { 'R', (char)('1' + i), 0 };
    glcd_text((uint8_t)(x0 + 4), (uint8_t)(y0 + 5), lbl, 1, on ? 0 : 1);

    const char *st = on ? "ON" : "OFF";
    glcd_text((uint8_t)(x1 - 4 - glcd_text_width(st, 1)),
              (uint8_t)(y0 + 5), st, 1, on ? 0 : 1);
}

static void draw_footer(void)
{
    glcd_fill(0, 53, 127, 63, 0);
    glcd_text(2, 55, status_msg, 1, 1);
}

/* ---------------- public ---------------- */

void ui_splash(void)
{
    for (uint8_t p = 0; p < 8; p++) {
        glcd_page_begin(p);
        glcd_rect(0, 0, 127, 63, 1);
        glcd_rect(2, 2, 125, 61, 1);
        glcd_text(28, 12, "SIM800", 2, 1);
        glcd_text(19, 32, "4-CHANNEL RELAY", 1, 1);
        glcd_text(31, 43, "SMS CONTROL", 1, 1);
        glcd_text(52, 53, "v1.0", 1, 1);
        glcd_page_end();
    }
    _delay_ms(1400);
}

void ui_draw(void)
{
    for (uint8_t p = 0; p < 8; p++) {
        glcd_page_begin(p);
        draw_header();
        for (uint8_t i = 0; i < 4; i++) draw_cell(i);
        draw_footer();
        glcd_page_end();
    }
}

void ui_status(const char *msg)
{
    strncpy(status_msg, msg, sizeof(status_msg) - 1);
    status_msg[sizeof(status_msg) - 1] = 0;

    for (uint8_t p = 6; p < 8; p++) {
        glcd_page_begin(p);
        draw_footer();
        glcd_page_end();
    }
}

void ui_set_status(uint8_t csq, uint8_t registered)
{
    s_csq = csq;
    s_reg = registered;

    for (uint8_t p = 0; p < 2; p++) {
        glcd_page_begin(p);
        draw_header();
        glcd_page_end();
    }
}

/* ---------------- touch ---------------- */

static void handle_tap(uint16_t x, uint16_t y)
{
    uint8_t idx;

    if (y < 13) { ui_status("TAP ONE OF R1..R4"); return; }
    if (y < 34)      idx = (x < 64) ? 0 : 1;
    else if (y < 54) idx = (x < 64) ? 2 : 3;
    else             return;

    app_set_relay(idx, (uint8_t)!app_relay(idx));
    ui_draw();
    beep(25);

    char m[16];
    snprintf(m, sizeof(m), "R%u %s (LOCAL)",
             (unsigned)(idx + 1), app_relay(idx) ? "ON" : "OFF");
    ui_status(m);
}

void ui_task(void)
{
    static uint8_t was_down = 0;
    uint16_t x, y;

    if (touch_read(&x, &y)) {
        if (!was_down) {
            was_down = 1;
            _delay_ms(20);
            if (touch_read(&x, &y)) handle_tap(x, y);
        }
    } else {
        was_down = 0;
    }
}
