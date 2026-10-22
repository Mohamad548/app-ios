#ifndef APP_H
#define APP_H

#include "board.h"

typedef struct {
    uint8_t  magic1, magic2;
    char     pass[5];          /* 4 digits + NUL */
    char     phone[16];        /* authorized number, empty = any */
    uint16_t cx0, cx1;         /* touch calibration raw X */
    uint16_t cy0, cy1;         /* touch calibration raw Y */
} settings_t;

extern settings_t cfg;
extern uint8_t    g_csq;          /* 0..31, 99 = unknown */

uint32_t millis(void);

void    app_init(void);
void    app_all_off(void);
void    app_set_relay(uint8_t idx, uint8_t on);
uint8_t app_relay(uint8_t idx);
void    app_state_str(char *out, uint8_t len);

void    app_scan_inbox(void);
void    app_on_sms(uint16_t index, const char *from, const char *body);

#endif
