#ifndef SIM800_H
#define SIM800_H

#include "board.h"

void     sim_power_pulse(void);
int8_t   sim_init(void);

int8_t   sim_send_sms(const char *number, const char *text);
int8_t   sim_read_sms(uint16_t index, char *number, uint8_t nlen, char *body, uint8_t blen);
int8_t   sim_delete_sms(uint16_t index);
uint16_t sim_sms_used(void);
uint8_t  sim_list_unread(uint16_t *ids, uint8_t max);

int8_t   sim_csq(void);
uint8_t  sim_is_registered(void);

int8_t   sim_dial(const char *number);
void     sim_hangup(void);

uint16_t sim_poll_cmti(void);

#endif
