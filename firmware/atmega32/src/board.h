#ifndef BOARD_H
#define BOARD_H

#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/eeprom.h>
#include <avr/pgmspace.h>
#include <util/delay.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>

#ifndef F_CPU
#  define F_CPU 16000000UL
#endif

/* ================= GLCD data bus : PORTB ================= */
#define GLCD_DDR        DDRB
#define GLCD_PORT       PORTB

/* ================= GLCD control : PORTC ================== */
#define GLCD_CTRL       PORTC
#define GLCD_CTRL_DDR   DDRC
#define PIN_CS1         PC0
#define PIN_CS2         PC1
#define PIN_RS          PC2
#define PIN_EN          PC3
#define PIN_RST         PC4
#define PIN_BL          PC5
#define PIN_NET         PC7

/* ================= Touch 4-wire : PORTA =================== */
#define TOUCH_DDR       DDRA
#define TOUCH_PORT      PORTA
#define TOUCH_PIN       PINA
#define TP_XP           0
#define TP_XM           1
#define TP_YP           2
#define TP_YM           3

/* ================= Relays : PORTD ========================= */
#define RELAY_PORT      PORTD
#define RELAY_DDR       DDRD
#define RELAY_MASK      0x3C            /* PD2..PD5 */
#define RELAY_COUNT     4

#define PIN_PWRKEY      PD6
#define PIN_BUZZER      PD7

#define PWRKEY_DDR      DDRD
#define PWRKEY_PORT     PORTD
#define BUZZER_DDR      DDRD
#define BUZZER_PORT     PORTD

/* ================= UART =================================== */
#define BAUD            9600UL
#define UBRR_VAL        ((F_CPU / (16UL * BAUD)) - 1UL)

#define FW_NAME         "SIM800-4CH"
#define FW_VERSION      "1.0"

#endif /* BOARD_H */
