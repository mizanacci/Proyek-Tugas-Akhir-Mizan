#!/bin/sh
# Pemakaian: ./build.sh <folder repo Proyek-Tugas-Akhir-Mizan> <folder library modbus-esp8266 (tag 4.1.1)>
set -e
REPO="${1:?folder repo proyek}"; LIB="${2:?folder modbus-esp8266}"
mkdir -p build && cp "$REPO/firmware_esp32/src/config.h.example" build/config.h
g++ -std=c++17 -O1 -w -DESP32=1 -I stub -I build -I "$LIB/src" -I "$REPO/firmware_esp32/src" \
    harness.cpp stub/arduino_stub.cpp "$LIB/src/ModbusRTU.cpp" "$LIB/src/Modbus.cpp" -o mbslave
echo "OK: ./mbslave dibuat dari modbus_slave.cpp milik repo + library 4.1.1"
