#include "touch.h"

/* raw ADC limits: readings outside this window mean "not touched" */
#define RAW_MIN   45
#define RAW_MAX   1000

static uint16_t cal_x0 = 200, cal_x1 = 830;
static uint16_t cal_y0 = 200, cal_y1 = 830;

void touch_init(void)
{
    TOUCH_DDR  &= ~((1 << TP_XP) | (1 << TP_XM) | (1 << TP_YP) | (1 << TP_YM));
    TOUCH_PORT &= ~((1 << TP_XP) | (1 << TP_XM) | (1 << TP_YP) | (1 << TP_YM));
    ADMUX  = (1 << REFS0);                       /* AVCC reference */
    ADCSRA = (1 << ADEN) | (1 << ADPS2) | (1 << ADPS1) | (1 << ADPS0);  /* /128 */
}

void touch_set_cal(uint16_t x0, uint16_t x1, uint16_t y0, uint16_t y1)
{
    if (x1 > x0 + 100) { cal_x0 = x0; cal_x1 = x1; }
    if (y1 > y0 + 100) { cal_y0 = y0; cal_y1 = y1; }
}

static uint16_t adc_read(uint8_t ch)
{
    ADMUX  = (uint8_t)((1 << REFS0) | (ch & 0x07));
    ADCSRA |= (1 << ADSC);
    while (ADCSRA & (1 << ADSC)) ;
    return ADC;
}

static void release_all(void)
{
    TOUCH_DDR  &= ~((1 << TP_XP) | (1 << TP_XM) | (1 << TP_YP) | (1 << TP_YM));
    TOUCH_PORT &= ~((1 << TP_XP) | (1 << TP_XM) | (1 << TP_YP) | (1 << TP_YM));
}

/* drive X plate: XP = 5V, XM = GND, Y pins floating */
static void drive_x(void)
{
    TOUCH_PORT &= ~((1 << TP_XM) | (1 << TP_YP) | (1 << TP_YM));
    TOUCH_PORT |=  (1 << TP_XP);
    TOUCH_DDR  |=  (1 << TP_XP) | (1 << TP_XM);
    TOUCH_DDR  &= ~((1 << TP_YP) | (1 << TP_YM));
}

/* drive Y plate: YP = 5V, YM = GND, X pins floating */
static void drive_y(void)
{
    TOUCH_PORT &= ~((1 << TP_YM) | (1 << TP_XP) | (1 << TP_XM));
    TOUCH_PORT |=  (1 << TP_YP);
    TOUCH_DDR  |=  (1 << TP_YP) | (1 << TP_YM);
    TOUCH_DDR  &= ~((1 << TP_XP) | (1 << TP_XM));
}

static int16_t scale(uint16_t raw, uint16_t lo, uint16_t hi, int16_t max)
{
    int32_t v = ((int32_t)raw - (int32_t)lo) * max / ((int32_t)hi - (int32_t)lo);
    if (v < 0)   v = 0;
    if (v > max) v = max;
    return (int16_t)v;
}

uint8_t touch_read(uint16_t *x, uint16_t *y)
{
    drive_x();
    _delay_us(300);
    uint16_t ry = adc_read(TP_YP);

    drive_y();
    _delay_us(300);
    uint16_t rx = adc_read(TP_XP);

    release_all();

    if (ry < RAW_MIN || ry > RAW_MAX) return 0;
    if (rx < RAW_MIN || rx > RAW_MAX) return 0;

    *x = (uint16_t)scale(rx, cal_x0, cal_x1, 127);
    *y = (uint16_t)scale(ry, cal_y0, cal_y1, 63);
    return 1;
}

uint8_t touch_wait_release(uint16_t timeout_ms)
{
    uint16_t x, y;
    for (uint16_t i = 0; i < timeout_ms; i++) {
        if (!touch_read(&x, &y)) return 1;
        _delay_ms(1);
    }
    return 0;
}
