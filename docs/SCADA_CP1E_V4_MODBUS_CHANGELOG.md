# SCADA CP1E Modbus CXT V4 Change Log

## Source and Backup

The available source project was `review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Rev.cxt`. The requested `SCADA_CP1E_Mizan_Modbus_Revision_V3_SingleCoil.cxt` was not present. The source CXT is preserved unchanged; the revised copy is `review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Modbus_Revision_V4_InternalADC.cxt`.

## Register Map

| ESP32 register | PLC destination | Meaning | Scale |
|---|---|---|---|
| IREG 0 | D110 | Source voltage | x100 |
| IREG 1 | D111 | Load voltage | x100 |
| IREG 2 | D112 | Source current | x1000 |
| IREG 3 | D113 | Load current | x1000 |
| IREG 4 | D114 | Sensor quality/status bitmask | bits |
| IREG 5 | D115 | LRUFail, 0 normal / 1 fail | bool |
| HREG 6 | D116 | Remote request, 1 NO/open / 2 NC/close; acknowledge by writing 0 | enum |
| HREG 7 | D117 | PLC heartbeat/status; current ladder sends 0 UNKNOWN | enum |

## Transaction and Ladder Changes

- The existing D1200-D1204 Easy Master transaction parameter layout is retained.
- Step 0 uses FC04, start address 0, quantity 6; received IREG data is copied to D110-D115.
- Step 1 uses FC03, start address 6, quantity 1; HREG6 is copied to D116.
- For a nonzero HREG6 request, step 2 uses FC06 to write 0 to address 6. Mapping remains 1=NO/open and 2=NC/close.
- When HREG6 is zero, step 2 instead uses FC06 to write D117 (initialized to 0/UNKNOWN) to address 7. A successful write refreshes the ESP32 HREG7 callback/watchdog. The ladder does not claim a PLC RUN/STANDBY state.
- R00 initializes D120/D121/D122/D123 to 20000/23000/1800/5000.
- R60 uses strict greater-than for load-current fault; 1.80 A is not a fault and 1.801 A is.
- R63 remains a source-voltage out-of-range comparison; with the new D120/D121 values, below 200 V or above 230 V is abnormal.
- R66 now treats 0 A and all values at or below D122 as normal/standby.
- R22 schedules the HREG7 heartbeat when HREG6 is zero; R70 sends the FC06 write.
- Sequencer state, A640.00 busy handling, transaction timeout, error recovery, COMFail watchdog, and HREG6 command gates remain in place.

## Serial Configuration

The CXT does not contain a verifiable serial configuration. In CX-Programmer, manually set the CP1E built-in RS-232C port to Modbus-RTU Easy Master, 9600 baud, 8 data bits, no parity, and 1 stop bit; transfer the configuration and power-cycle the PLC. Confirm the selected port and options against the exact CPU variant.

## Validation Boundary

The software ladder interpreter passed 36/36 checks against this CXT. This is not the official CX-Programmer Program Check and does not prove Easy Master behavior, RS-232C/MAX3232 wiring, communication with a real CP1E, or physical LBS/relay position. Those require the actual equipment and must be recorded separately.
