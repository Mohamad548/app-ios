#include "sim800.h"

/* ------------------------------------------------------------------
 * SIM800L driver, USART 9600 8N1, text mode (+CMGF=1)
 * ------------------------------------------------------------------ */

#define RX_SIZE    128
#define ATBUF_SIZE 220

static volatile uint8_t rx_head, rx_tail;
static volatile char    rx_buf[RX_SIZE];
static char             atbuf[ATBUF_SIZE];

ISR(USART_RXC_vect)
{
    char c = (char)UDR;
    uint8_t n = (uint8_t)((rx_head + 1) % RX_SIZE);
    if (n != rx_tail) {
        rx_buf[rx_head] = c;
        rx_head = n;
    }
}

/* ---------------- uart ---------------- */

static void uart_init(void)
{
    UBRRH = (uint8_t)(UBRR_VAL >> 8);
    UBRRL = (uint8_t)(UBRR_VAL);
    UCSRB = (1 << RXCIE) | (1 << RXEN) | (1 << TXEN);
    UCSRC = (1 << URSEL) | (1 << UCSZ1) | (1 << UCSZ0);   /* 8N1 */
}

static void uart_putc(char c)
{
    while (!(UCSRA & (1 << UDRE))) ;
    UDR = (uint8_t)c;
}

static void uart_puts(const char *s)
{
    while (*s) uart_putc(*s++);
}

/* wait up to ms milliseconds for one byte */
static int16_t uart_getc(uint16_t ms)
{
    for (uint16_t i = 0; i < ms; i++) {
        for (uint8_t j = 0; j < 10; j++) {
            if (rx_head != rx_tail) {
                char c = rx_buf[rx_tail];
                rx_tail = (uint8_t)((rx_tail + 1) % RX_SIZE);
                return (int16_t)(uint8_t)c;
            }
            _delay_us(100);
        }
    }
    return -1;
}

static void rx_flush(void)
{
    rx_tail = rx_head;
}

/* ---------------- AT engine ---------------- */

/* returns 0 = OK, 1 = ERROR, -1 = timeout */
static int8_t sim_at(const char *cmd, uint16_t to_ms)
{
    atbuf[0] = 0;
    rx_flush();
    uart_puts(cmd);
    uart_putc('\r');

    uint16_t n = 0;
    uint32_t elapsed = 0;

    while (elapsed < to_ms) {
        int16_t c = uart_getc(5);
        if (c < 0) { elapsed += 5; continue; }
        elapsed++;

        if (n < ATBUF_SIZE - 1) {
            atbuf[n++] = (char)c;
            atbuf[n] = 0;
        }
        if (strstr(atbuf, "OK\r\n"))    return 0;
        if (strstr(atbuf, "ERROR"))     return 1;
        if (strstr(atbuf, "+CME ERROR")) return 1;
        if (strstr(atbuf, "+CMS ERROR")) return 1;
    }
    return -1;
}

/* ---------------- power ---------------- */

void sim_power_pulse(void)
{
    PWRKEY_DDR  |= _BV(PIN_PWRKEY);
    PWRKEY_PORT &= ~_BV(PIN_PWRKEY);       /* transistor off */
    _delay_ms(300);
    PWRKEY_PORT |= _BV(PIN_PWRKEY);        /* pull PWRKEY low */
    _delay_ms(1200);
    PWRKEY_PORT &= ~_BV(PIN_PWRKEY);
    _delay_ms(1500);
}

uint8_t sim_is_registered(void)
{
    if (sim_at("AT+CREG?", 1000) != 0) return 0;
    char *p = strstr(atbuf, "+CREG:");
    if (!p) return 0;
    p = strchr(p, ',');
    if (!p) return 0;
    uint8_t st = (uint8_t)atoi(p + 1);
    return (st == 1 || st == 5);
}

int8_t sim_init(void)
{
    uart_init();
    _delay_ms(300);

    uint8_t ok = 0;
    for (uint8_t attempt = 0; attempt < 3; attempt++) {
        if (sim_at("AT", 1500) == 0) { ok = 1; break; }
        sim_power_pulse();
        _delay_ms(2000);
    }
    if (!ok) return -1;

    sim_at("ATE0", 1000);
    sim_at("AT+CMGF=1", 1000);              /* text mode   */
    sim_at("AT+CNMI=2,1,0,0,0", 1000);      /* new sms -> +CMTI */
    sim_at("AT+CPMS=\"SM\",\"SM\",\"SM\"", 1000);

    /* wait for network registration (max ~15 s) */
    for (uint8_t i = 0; i < 10; i++) {
        if (sim_is_registered()) break;
        _delay_ms(1500);
    }
    return 0;
}

/* ---------------- sms ---------------- */

int8_t sim_send_sms(const char *number, const char *text)
{
    rx_flush();
    uart_puts("AT+CMGS=\"");
    uart_puts(number);
    uart_puts("\"");
    uart_putc('\r');

    /* wait for '>' prompt */
    uint8_t prompt = 0;
    for (uint16_t i = 0; i < 500; i++) {
        int16_t c = uart_getc(10);
        if (c == '>') { prompt = 1; break; }
    }
    if (!prompt) return -1;

    uart_puts(text);
    uart_putc(0x1A);                        /* Ctrl-Z = send */

    /* wait for +CMGS: <ref> ... OK ; up to 25 s */
    atbuf[0] = 0;
    uint16_t n = 0;
    for (uint32_t elapsed = 0; elapsed < 25000; elapsed += 5) {
        int16_t c = uart_getc(5);
        if (c < 0) continue;
        if (n < ATBUF_SIZE - 1) { atbuf[n++] = (char)c; atbuf[n] = 0; }
        if (strstr(atbuf, "OK\r\n")) return 0;
        if (strstr(atbuf, "ERROR"))  return -1;
    }
    return -1;
}

int8_t sim_read_sms(uint16_t index, char *number, uint8_t nlen, char *body, uint8_t blen)
{
    char cmd[20];
    snprintf(cmd, sizeof(cmd), "AT+CMGR=%u", (unsigned)index);

    number[0] = 0;
    body[0]   = 0;

    if (sim_at(cmd, 3000) != 0) return -1;

    char *h = strstr(atbuf, "+CMGR:");
    if (!h) return -1;

    char *q1 = strchr(h, '"');
    char *q2 = q1 ? strchr(q1 + 1, '"') : 0;
    char *q3 = q2 ? strchr(q2 + 1, '"') : 0;
    char *q4 = q3 ? strchr(q3 + 1, '"') : 0;
    if (!q4) return -1;

    uint8_t n = 0;
    for (char *p = q3 + 1; p < q4 && n < (uint8_t)(nlen - 1); p++)
        number[n++] = *p;
    number[n] = 0;

    char *nl = strchr(q4, '\n');
    if (!nl) return 0;

    char *b = nl + 1;
    while (*b == '\r' || *b == '\n') b++;

    char *e = strstr(b, "\r\nOK");
    uint8_t m = 0;
    for (char *p = b; p < (e ? e : b + strlen(b)) && m < (uint8_t)(blen - 1); p++)
        body[m++] = *p;
    body[m] = 0;

    /* trim trailing whitespace */
    while (m > 0) {
        char c = body[m - 1];
        if (c == '\r' || c == '\n' || c == ' ') body[--m] = 0;
        else break;
    }
    return (number[0] != 0) ? 0 : -1;
}

int8_t sim_delete_sms(uint16_t index)
{
    char cmd[20];
    snprintf(cmd, sizeof(cmd), "AT+CMGD=%u", (unsigned)index);
    return (sim_at(cmd, 2000) == 0) ? 0 : -1;
}

uint16_t sim_sms_used(void)
{
    if (sim_at("AT+CPMS?", 1500) != 0) return 0;
    char *p = strstr(atbuf, "+CPMS:");
    if (!p) return 0;
    p = strchr(p, ',');
    if (!p) return 0;
    return (uint16_t)atoi(p + 1);
}

int8_t sim_csq(void)
{
    if (sim_at("AT+CSQ", 1000) != 0) return -1;
    char *p = strstr(atbuf, "+CSQ:");
    if (!p) return -1;
    p = strchr(p, ':');
    if (!p) return -1;
    return (int8_t)atoi(p + 1);
}

int8_t sim_dial(const char *number)
{
    char cmd[28];
    snprintf(cmd, sizeof(cmd), "ATD%s;", number);
    return (sim_at(cmd, 5000) == 0) ? 0 : -1;
}

void sim_hangup(void)
{
    sim_at("ATH", 3000);
}

/* ---------------- inbox listing ---------------- */

static uint8_t read_line(char *out, uint8_t len, uint16_t ms)
{
    uint8_t n = 0;
    out[0] = 0;
    for (;;) {
        int16_t c = uart_getc(ms);
        if (c < 0) return (n > 0) ? 1 : 0;
        if (c == '\n') {
            if (n > 0 && out[n - 1] == '\r') n--;
            out[n] = 0;
            return 1;
        }
        if (n < (uint8_t)(len - 1)) out[n++] = (char)c;
    }
}

/* Fill ids[] with the indexes of unread messages and consume the whole
 * +CMGL response, leaving the module idle for the next command. */
uint8_t sim_list_unread(uint16_t *ids, uint8_t max)
{
    uint8_t  count = 0;
    char     line[110];

    rx_flush();
    uart_puts("AT+CMGL=\"REC UNREAD\"");
    uart_putc('\r');

    for (uint16_t guard = 0; guard < 300; guard++) {
        if (!read_line(line, sizeof(line), 3000)) break;
        if (!strcmp(line, "OK")) break;
        if (!strncmp(line, "+CMGL:", 6)) {
            char *p = strchr(line, ':');
            if (p && count < max) ids[count++] = (uint16_t)atoi(p + 1);
        }
    }
    return count;
}

uint16_t sim_poll_cmti(void)
{
    char tmp[64];
    uint8_t n = 0;
    int16_t c;

    while ((c = uart_getc(2)) >= 0 && n < sizeof(tmp) - 1)
        tmp[n++] = (char)c;
    tmp[n] = 0;

    char *p = strstr(tmp, "+CMTI:");
    if (!p) return 0;
    p = strchr(p, ',');
    if (!p) return 0;
    return (uint16_t)atoi(p + 1);
}
