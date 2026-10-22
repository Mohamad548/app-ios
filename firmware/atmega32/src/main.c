#include "board.h"
#include "glcd.h"
#include "touch.h"
#include "sim800.h"
#include "app.h"
#include "ui.h"

static volatile uint32_t g_ms;

ISR(TIMER0_COMP_vect)
{
    g_ms++;
}

uint32_t millis(void)
{
    uint32_t v;
    uint8_t  sreg = SREG;
    cli();
    v = g_ms;
    SREG = sreg;
    return v;
}

static void io_init(void)
{
    /* relays: outputs, all off */
    RELAY_DDR  |= RELAY_MASK;
    RELAY_PORT &= (uint8_t)~RELAY_MASK;

    /* buzzer + sim power key */
    DDRD  |= _BV(PIN_BUZZER) | _BV(PIN_PWRKEY);
    PORTD &= ~(_BV(PIN_BUZZER) | _BV(PIN_PWRKEY));

    /* network status input */
    DDRC &= ~_BV(PIN_NET);

    _delay_ms(200);
}

static void timer_init(void)
{
    TCCR0 = (1 << WGM01) | (1 << CS01) | (1 << CS00);   /* CTC, clk/64 */
    OCR0  = 249;                                        /* 1 ms tick     */
    TIMSK |= (1 << OCIE0);
}

int main(void)
{
    uint32_t t_touch = 0, t_scan = 0, t_csq = 0;

    io_init();
    timer_init();
    sei();

    glcd_init();
    glcd_backlight(1);
    touch_init();

    ui_splash();

    app_init();
    ui_draw();

    ui_status("GSM INIT...");
    if (sim_init() != 0) {
        ui_status("SIM800 NO ANSWER");
    } else {
        ui_status("READY");
    }

    app_scan_inbox();

    {
        int8_t q = sim_csq();
        g_csq = (q < 0 || q > 31) ? 99 : (uint8_t)q;
        ui_set_status(g_csq, sim_is_registered());
    }

    for (;;) {
        uint32_t now = millis();

        if ((uint32_t)(now - t_touch) >= 20) {
            t_touch = now;
            ui_task();
        }

        /* poll inbox: also catches messages whose +CMTI was lost */
        if ((uint32_t)(now - t_scan) >= 5000) {
            t_scan = now;
            app_scan_inbox();
        }

        if ((uint32_t)(now - t_csq) >= 60000) {
            t_csq = now;
            int8_t q = sim_csq();
            g_csq = (q < 0 || q > 31) ? 99 : (uint8_t)q;
            ui_set_status(g_csq, sim_is_registered());
        }
    }
}
