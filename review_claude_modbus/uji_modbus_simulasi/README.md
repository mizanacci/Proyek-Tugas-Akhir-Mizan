# Uji komunikasi Modbus ESP32-S3 dan PLC (simulasi di komputer)

Menjalankan `modbus_slave.cpp` ASLI dari repo (library modbus-esp8266 4.1.1, UART tiruan 9600 8N1 dengan waktu byte nyata)
bersama program ladder ASLI (`SCADA_CP1E_Mizan.cxt`) lewat interpreter mnemonic. Frame dibentuk seperti Modbus-RTU Easy Master
dari D1200-D1204, dan ESP32-S3 dibuat tidak menjawab 0,42 detik tiap detik (pembacaan ADC).

Kebutuhan: g++ (C++17), python3, git.

    git clone https://github.com/emelianov/modbus-esp8266 --branch 4.1.1 ../modbus-esp8266
    ./build.sh ../Proyek-Tugas-Akhir-Mizan ../modbus-esp8266     # membuat ./mbslave
    python3 e2e.py                                               # skenario komunikasi (E2-E5)
    python3 scen_ladder.py                                       # 35 pemeriksaan logika ladder

Yang TIDAK diuji: lapisan fisik (kabel RS-232C, pinout DB9, modul MAX3232), urutan byte pada kata respons di PLC,
dan perilaku Easy Master pada unit asli. Uji ESP32 dari PC (QModMaster atau Modbus Poll, 9600 8N1, slave 1) sebelum PLC disambungkan.

Catatan: skenario E2 mensimulasikan firmware apa adanya (parameter lru_bug=True: IREG 5 = 1 saat MQTT terhubung)
dan firmware yang diperbaiki (lru_bug=False: modbusUpdateLRUFail(!statusMqttTerhubung)).
