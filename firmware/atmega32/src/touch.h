#ifndef TOUCH_H
#define TOUCH_H

#include "board.h"

void    touch_init(void);
void    touch_set_cal(uint16_t x0, uint16_t x1, uint16_t y0, uint16_t y1);
uint8_t touch_read(uint16_t *x, uint16_t *y);   /* 1 = touched, x:0..127 y:0..63 */
uint8_t touch_wait_release(uint16_t timeout_ms);

#endif
