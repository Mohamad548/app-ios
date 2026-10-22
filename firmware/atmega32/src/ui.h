#ifndef UI_H
#define UI_H

#include "board.h"

void ui_splash(void);
void ui_draw(void);
void ui_task(void);
void ui_status(const char *msg);
void ui_set_status(uint8_t csq, uint8_t registered);

#endif
