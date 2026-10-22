#include "app.h"
#include "sim800.h"
#include "ui.h"
#include "touch.h"

settings_t cfg;
uint8_t    g_csq = 99;

static uint8_t  relay_state;
static uint8_t  fail_cnt;
static uint32_t lock_until;

#define EEPROM_MAGIC1 0x5A
#define EEPROM_MAGIC2 0xA5

/* ---------------- settings ---------------- */

static void settings_defaults(void)
{
    memset(&cfg, 0, sizeof(cfg));
    cfg.magic1 = EEPROM_MAGIC1;
    cfg.magic2 = EEPROM_MAGIC2;
    strcpy(cfg.pass, "0000");
    cfg.phone[0] = 0;
    cfg.cx0 = 200; cfg.cx1 = 830;
    cfg.cy0 = 200; cfg.cy1 = 830;
}

static void settings_load(void)
{
    eeprom_read_block((void *)&cfg, (const void *)0, sizeof(cfg));
    if (cfg.magic1 != EEPROM_MAGIC1 || cfg.magic2 != EEPROM_MAGIC2) {
        settings_defaults();
        eeprom_update_block((const void *)&cfg, (void *)0, sizeof(cfg));
    }
    cfg.pass[4] = 0;
    cfg.phone[15] = 0;
}

static void settings_save(void)
{
    eeprom_update_block((const void *)&cfg, (void *)0, sizeof(cfg));
}

/* ---------------- relays ---------------- */

uint8_t app_relay(uint8_t idx)
{
    return (uint8_t)((relay_state >> idx) & 1);
}

void app_set_relay(uint8_t idx, uint8_t on)
{
    if (idx > 3) return;
    if (on) relay_state |=  (uint8_t)(1 << idx);
    else    relay_state &= (uint8_t)~(1 << idx);

    uint8_t out = (uint8_t)((relay_state & 0x0F) << 2);   /* bit0..3 -> PD2..PD5 */
    RELAY_PORT = (uint8_t)((RELAY_PORT & ~RELAY_MASK) | (out & RELAY_MASK));
}

void app_all_off(void)
{
    relay_state = 0;
    RELAY_PORT &= (uint8_t)~RELAY_MASK;
}

void app_state_str(char *out, uint8_t len)
{
    snprintf(out, len, "R1=%d R2=%d R3=%d R4=%d",
             app_relay(0), app_relay(1), app_relay(2), app_relay(3));
}

/* ---------------- helpers ---------------- */

/* keep the last 10 digits so +98912..., 0098912..., 0912... all match */
static void tail10(const char *s, char *out, uint8_t outlen)
{
    char d[24];
    uint8_t n = 0;
    for (; *s && n < sizeof(d) - 1; s++)
        if (*s >= '0' && *s <= '9') d[n++] = *s;
    d[n] = 0;
    if (n > 10) memmove(d, d + (n - 10), 11);
    strncpy(out, d, outlen - 1);
    out[outlen - 1] = 0;
}

static uint8_t authorized(const char *number)
{
    if (cfg.phone[0] == 0) return 1;          /* no filter */
    char a[12], b[12];
    tail10(cfg.phone, a, sizeof(a));
    tail10(number, b, sizeof(b));
    return (strcmp(a, b) == 0);
}

static uint8_t pass_ok(const char *p)
{
    return (strncmp(p, cfg.pass, 4) == 0);
}

static void reply(const char *to, const char *msg)
{
    ui_status("SENDING...");
    sim_send_sms(to, msg);
}

static void deny(const char *to, const char *msg)
{
    fail_cnt++;
    if (fail_cnt >= 3) {
        fail_cnt = 0;
        lock_until = millis() + 300000UL;     /* 5 min */
    }
    reply(to, msg);
}
/* ---------------- command parser ---------------- */

void app_on_sms(uint16_t index, const char *from, const char *body)
{
    char cmd[72];
    uint8_t n = 0;
    char msg[64];

    (void)index;

    for (const char *p = body; *p && n < sizeof(cmd) - 1; p++) {
        char c = *p;
        if (c == '\r' || c == '\n') break;
        if (c == ' ') continue;
        if (c >= 'a' && c <= 'z') c = (char)(c - 32);
        cmd[n++] = c;
    }
    cmd[n] = 0;

    if (n == 0) return;

    if (!authorized(from)) {
        reply(from, "ACCESS DENIED");
        return;
    }

    if (millis() < lock_until) {
        reply(from, "LOCKED 5MIN");
        return;
    }
    fail_cnt = 0;

    /* ---- relay on/off : R1EN0000 / R1DS0000 ---- */
    if (n >= 8 && cmd[0] == 'R' && cmd[1] >= '1' && cmd[1] <= '4') {
        uint8_t idx = (uint8_t)(cmd[1] - '1');
        uint8_t on;

        if (cmd[2] == 'E' && cmd[3] == 'N')      on = 1;
        else if (cmd[2] == 'D' && cmd[3] == 'S') on = 0;
        else goto unknown;

        if (!pass_ok(cmd + 4)) { deny(from, "PASS ERROR"); return; }

        app_set_relay(idx, on);
        app_state_str(msg, sizeof(msg));
        {
            char out[48];
            snprintf(out, sizeof(out), "R%u %s OK\n%s",
                     (unsigned)(idx + 1), on ? "ON" : "OFF", msg);
            reply(from, out);
        }
        ui_draw();
        ui_status(on ? "RELAY ON (SMS)" : "RELAY OFF (SMS)");
        return;
    }

    /* ---- save / clear authorized number : TEL1 0000 0912... ---- */
    if (n >= 8 && !strncmp(cmd, "TEL1", 4)) {
        if (!pass_ok(cmd + 4)) { deny(from, "PASS ERROR"); return; }

        if (cmd[8] == 0) {
            cfg.phone[0] = 0;
            settings_save();
            reply(from, "TEL CLEARED");
        } else {
            strncpy(cfg.phone, cmd + 8, sizeof(cfg.phone) - 1);
            cfg.phone[sizeof(cfg.phone) - 1] = 0;
            settings_save();
            reply(from, "TEL SAVED");
        }
        ui_draw();
        return;
    }

    /* ---- call back and listen : MIC1 0000 ---- */
    if (n >= 8 && !strncmp(cmd, "MIC1", 4)) {
        if (!pass_ok(cmd + 4)) { deny(from, "PASS ERROR"); return; }
        if (cfg.phone[0] == 0) { reply(from, "NO TEL"); return; }

        reply(from, "CALLBACK");
        if (sim_dial(cfg.phone) == 0) {
            for (uint8_t i = 0; i < 20; i++) {     /* ~20 s listen */
                _delay_ms(1000);
            }
            sim_hangup();
        }
        return;
    }

    /* ---- change password : PASS 0000 1234 ---- */
    if (n >= 12 && !strncmp(cmd, "PASS", 4)) {
        if (!pass_ok(cmd + 4)) { deny(from, "PASS ERROR"); return; }
        memcpy(cfg.pass, cmd + 8, 4);
        cfg.pass[4] = 0;
        settings_save();
        reply(from, "PASS CHANGED");
        ui_draw();
        return;
    }

    /* ---- extension: STATUS0000 ---- */
    if (n >= 10 && !strncmp(cmd, "STATUS", 6)) {
        if (!pass_ok(cmd + 6)) { deny(from, "PASS ERROR"); return; }
        app_state_str(msg, sizeof(msg));
        reply(from, msg);
        return;
    }

unknown:
    reply(from, "UNKNOWN CMD");
}

/* ---------------- boot ---------------- */

void app_init(void)
{
    settings_load();
    touch_set_cal(cfg.cx0, cfg.cx1, cfg.cy0, cfg.cy1);
    app_all_off();
    fail_cnt = 0;
    lock_until = 0;
}

void app_scan_inbox(void)
{
    uint16_t ids[8];
    uint8_t  n = sim_list_unread(ids, 8);

    for (uint8_t i = 0; i < n; i++) {
        char from[20];
        char body[74];

        if (sim_read_sms(ids[i], from, sizeof(from), body, sizeof(body)) == 0)
            app_on_sms(ids[i], from, body);

        sim_delete_sms(ids[i]);
    }
}
