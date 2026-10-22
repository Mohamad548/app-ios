MCU     = atmega32
F_CPU   = 16000000UL
TARGET  = sim800_relay

CC      = avr-gcc
OBJCOPY = avr-objcopy
SIZE    = avr-size
AVRDUDE = avrdude

SRCS = src/main.c src/glcd.c src/touch.c src/sim800.c src/app.c src/ui.c
OBJS = $(SRCS:.c=.o)

CFLAGS  = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -std=gnu99 -Wall -Wextra \
          -funsigned-char -funsigned-bitfields -fpack-struct -fshort-enums \
          -ffunction-sections -fdata-sections
LDFLAGS = -mmcu=$(MCU) -Wl,--gc-sections

all: $(TARGET).hex

$(TARGET).elf: $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^
	$(SIZE) --mcu=$(MCU) --format=avr $@

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex -R .eeprom $< $@

flash: $(TARGET).hex
	$(AVRDUDE) -c usbasp -p m32 -U flash:w:$(TARGET).hex:i

fuses:
	$(AVRDUDE) -c usbasp -p m32 -U lfuse:w:0xFF:m -U hfuse:w:0x89:m

clean:
	rm -f src/*.o $(TARGET).elf $(TARGET).hex

.PHONY: all flash fuses clean
