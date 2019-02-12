export PATH := $(PWD)/esp-open-sdk/xtensa-lx106-elf/bin:$(PWD)/micropython/tools:$(PWD)/micropython/ports/unix:$(HOME)/go/bin:$(PATH)

VERSION := 0.4.0-alpha
MICROPYVERSION := 1.10
PORT := /dev/ttyUSB0


all: copy firmware

requirements:
	mkdir -p micropython/ports/esp8266/modules/uasyncio
	curl -s -o micropython/ports/esp8266/modules/types.py https://raw.githubusercontent.com/micropython/micropython-lib/master/types/types.py
	curl -s -o micropython/ports/esp8266/modules/copy.py https://raw.githubusercontent.com/micropython/micropython-lib/master/copy/copy.py
	curl -s -o micropython/ports/esp8266/modules/uasyncio/__init__.py https://raw.githubusercontent.com/micropython/micropython-lib/master/uasyncio/uasyncio/__init__.py
	curl -s -o micropython/ports/esp8266/modules/uasyncio/core.py https://raw.githubusercontent.com/micropython/micropython-lib/master/uasyncio.core/uasyncio/core.py
	curl -s -o micropython/ports/esp8266/modules/mqtt_as.py https://raw.githubusercontent.com/kevinkk525/micropython-mqtt/master/mqtt_as_minimal.py
	curl -s -o micropython/ports/esp8266/modules/asyn.py https://raw.githubusercontent.com/peterhinch/micropython-async/master/asyn.py
	curl -s -o micropython/ports/esp8266/modules/aswitch.py https://raw.githubusercontent.com/peterhinch/micropython-async/master/aswitch.py

copy:
	mkdir -p micropython/ports/esp8266/modules/homie/node
	cp homie/*.py micropython/ports/esp8266/modules/homie
	cp homie/node/__init__.py micropython/ports/esp8266/modules/homie/node

firmware:
	cd micropython/ports/esp8266; make

copy-firmware:
	cp micropython/ports/esp8266/build/firmware-combined.bin ./microhomie-esp8266-v$(VERSION).bin

release: all copy-firmware

clean:
	cd micropython/ports/esp8266; make clean
	-rm -rf micropython/ports/esp8266/modules/homie

deploy: erase flash

erase:
	esptool.py --port $(PORT) --baud 460800 erase_flash

flash:
	esptool.py --port $(PORT) --baud 460800 write_flash  --flash_size=detect --verify -fm dio 0 micropython/ports/esp8266/build/firmware-combined.bin

espopensdk:
	-git clone --recursive https://github.com/pfalcon/esp-open-sdk.git
	cd esp-open-sdk; make

micropython:
	-git clone --recursive https://github.com/micropython/micropython.git
	cd micropython; git checkout -b $(MICROPYVERSION)
	cd micropython; make -C mpy-cross
	cd micropython/ports/unix; make axtls; make

bootstrap: espopensdk micropython requirements

# linting!
black:
	find homie -name '*.py' | grep -v with_errors  | xargs black --line-length=79 --safe $(ARGS)

isort:
	isort --recursive --apply homie

mypy:
	find homie -name '*.py' | xargs mypy --follow-imports skip --ignore-missing-imports

autoflake:
	find homie -name '*.py' | xargs autoflake --in-place --remove-unused-variables

flake8:
	flake8 homie

# isort must come first as black reformats the imports again
lint: autoflake isort black flake8 mypy