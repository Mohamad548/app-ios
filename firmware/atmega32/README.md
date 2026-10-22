# فریمور ATmega32 — کیت ۴ رله پیامکی

## ساختار

```
firmware/atmega32/
├── Makefile
└── src/
    ├── board.h      نقشه پایه‌ها و تنظیمات برد
    ├── glcd.c/.h    درایور KS0108 128x64 + فونت 5x7 + فریم‌بافر
    ├── touch.c/.h   تاچ ۴ سیمه مقاومتی با ADC
    ├── sim800.c/.h  درایور SIM800L (AT، پیامک، تماس)
    ├── app.c/.h     تنظیمات EEPROM، رله‌ها، پارس دستورها
    ├── ui.c/.h      صفحه‌ها، دکمه‌ها، تاچ
    └── main.c       راه‌اندازی و حلقه اصلی
```

## پیش‌نیاز

- `avr-gcc` و `avr-libc` (مثلاً `sudo apt install gcc-avr avr-libc avrdude` یا نسخه ویندوزی Zak Kemble / Microchip AVR toolchain)
- پروگرامر USBASP (یا USBtiny)

## بیلد

```bash
cd firmware/atmega32
make            # خروجی: sim800_relay.hex
```

اگر خطای `avr-gcc: command not found` داد، مسیر باین‌های toolchain را به PATH اضافه کن.

## پروگرام

```bash
make fuses      # فقط بار اول: LFUSE=0xFF و HFUSE=0x89 (JTAG خاموش)
make flash
```

یا دستی:

```bash
avrdude -c usbasp -p m32 -U lfuse:w:0xFF:m -U hfuse:w:0x89:m
avrdude -c usbasp -p m32 -U flash:w:sim800_relay.hex:i
```

> HFUSE = 0x89 یعنی JTAG خاموش تا PC2…PC5 برای GLCD آزاد شوند. اگر قبلاً فیوز دیگری زده‌ای، همین مقدار را دوباره بنویس.

## رفتار دستگاه

| رویداد | واکنش |
|---|---|
| روشن شدن | اسپلش، راه‌اندازی SIM800L، پالس PWRKEY، جست‌وجوی شبکه |
| پیامک دستور | اجرا + پیامک تأیید + به‌روزرسانی نمایشگر |
| لمس کادر رله | تغییر وضعیت محلی + بوق کوتاه |
| هر ۵ ثانیه | بررسی صندوق پیامک (`CMGL` + `CMGR` + `CMGD`) |
| هر ۶۰ ثانیه | به‌روزرسانی آنتن (`AT+CSQ`) و وضعیت شبکه (`AT+CREG?`) |

رمز پیش‌فرض: `0000` / شماره مجاز: خالی (هر شماره‌ای با رمز صحیح).

## کالیبراسیون تاچ

مقادیر خام در `settings_t` (EEPROM) ذخیره می‌شوند و پیش‌فرض `200…830` است.
اگر لمس در گوشه‌ها دقیق نبود:

1. مقادیر خام را با یک تست ساده (نمایش `rx`/`ry` روی GLCD) بخوان.
2. `cfg.cx0/cx1/cy0/cy1` را عوض کن و یک‌بار `settings_save()` را صدا بزن
   (مثلاً در `app_init` قبل از `touch_set_cal`).

## مصرف حافظه (اندازه‌گیری‌شده با avr-gcc 7.3، `-Os`)

| | استفاده‌شده | ظرفیت |
|---|---|---|
| Flash | 9,562 بایت (29.2%) | 32 KB |
| SRAM | 1,180 بایت (57.6%) | 2 KB |

یعنی حدود ۸۶۰ بایت برای استک آزاد می‌ماند.

> اگر بازهم RAM کم آوردی: `ATBUF_SIZE` (۲۲۰) و `RX_SIZE` (۱۲۸) را کم کن.
> برای فضای بیشتر، `status_msg` و بافرهای محلی `app_scan_inbox` را کوچک‌تر کن.

## نکات مهم

- **بدون فریم‌بافر کامل:** ATmega32 فقط ۲KB SRAM دارد؛ به‌جای بافر ۱KB،
  نمایشگر **صفحه‌به‌صفحه** (۸ صفحه × ۱۲۸ بایت) رندر می‌شود:
  ```c
  for (p = 0; p < 8; p++) { glcd_page_begin(p); ...draw...; glcd_page_end(); }
  ```
  همه توابع رسم خودشان را به صفحه جاری محدود می‌کنند، پس یک کد UI برای هر ۸ صفحه اجرا می‌شود.
- **بدون watchog:** نسخه ۱ ندارد. اگر اضافه کردی، داخل `sim_send_sms` (که تا ۲۵ ثانیه
  بلوکه می‌شود) `wdt_reset()` بگذار.
- **پیامک باید انگلیسی/ASCII باشد.** پیامک فارسی در حالت UCS2 می‌آید و پارسر آن را
  نمی‌شناسد (پاسخ `UNKNOWN CMD`).
- **حذف پیامک:** هر پیامک پردازش‌شده با `AT+CMGD` پاک می‌شود تا حافظه SIM پر نشود.
- **تماس برگشتی (`MIC1`)** به میکروفن/اسپیکر وصل‌شده به SIM800L نیاز دارد.
- **هشدار RAM:** رشته‌های ثابت در AVR به‌طور پیش‌فرض در RAM قرار می‌گیرند؛ اگر متن‌ها را
  زیاد کردی، از `PSTR()` و `pgm_read_byte()` استفاده کن.

## بیلد با ابزار ویندوزی

اگر toolchain در `E:\dev\avr8` نصب است:

```powershell
$bin = "E:\dev\avr8\avr8-gnu-toolchain-win32_x86_64\bin"
Get-ChildItem src\*.c | ForEach-Object {
  & "$bin\avr-gcc.exe" -mmcu=atmega32 -DF_CPU=16000000UL -Os -std=gnu99 -Wall -Wextra `
      -funsigned-char -ffunction-sections -fdata-sections -c $_.FullName -o ($_.FullName -replace '\.c$','.o')
}
& "$bin\avr-gcc.exe" -mmcu=atmega32 "-Wl,--gc-sections" -o sim800_relay.elf src\*.o
& "$bin\avr-objcopy.exe" -O ihex -R .eeprom sim800_relay.elf sim800_relay.hex
```

