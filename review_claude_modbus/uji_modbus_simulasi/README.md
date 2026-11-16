# Uji komunikasi Modbus ESP32-S3 dan PLC (simulasi di komputer)

Menjalankan `firmware_esp32/src/modbus_slave.cpp` dari workspace (library
modbus-esp8266 4.1.1, UART tiruan 9600 8N1 dengan waktu byte) bersama
`SCADA_CP1E_Mizan_Modbus_Revision_V4_InternalADC.cxt`. Ladder dieksekusi oleh
interpreter mnemonic dan transaksi byte-level dibentuk dari D1200-D1204.
Harness tidak menjalankan task ADC atau menguji konverter RS-232C secara fisik.

Kebutuhan: g++ (C++17), python3, git.

    git clone https://github.com/emelianov/modbus-esp8266 --branch 4.1.1 ../modbus-esp8266
    ./build.sh ../Proyek-Tugas-Akhir-Mizan ../modbus-esp8266     # membuat ./mbslave
    python3 e2e.py                                               # skenario firmware + CXT (E1-E5)
    python3 scen_ladder.py                                       # pemeriksaan logika ladder dan ambang

Yang TIDAK diuji: lapisan fisik (kabel RS-232C, pinout DB9, modul MAX3232), urutan byte pada kata respons di PLC,
dan perilaku Easy Master pada unit asli. Uji ESP32 dari PC (QModMaster atau Modbus Poll, 9600 8N1, slave 1) sebelum PLC disambungkan.

E1 memeriksa write HREG7 pada callback firmware dan validitas heartbeat. E2
membandingkan polaritas LRUFail yang lama dengan source aktif
(`modbusUpdateLRUFail(!statusMqttTerhubung)`). Semua hasil merupakan simulasi
software, bukan uji PLC fisik.
