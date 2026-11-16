# CXT Status and Program Check

## Baseline yang dipertahankan

User baseline yang dipilih adalah V3 SingleCoil, bukan V4. V4 yang ada di workspace adalah alat simulasi dan revisi tertentu, bukan baseline resmi.

## File CXT yang saat ini benar-benar ada

- review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Modbus_Revision_V4_InternalADC.cxt
- review_claude_modbus/uji_modbus_simulasi/SCADA_CP1E_Mizan_Rev.cxt

`SCADA_LBS_PLC_V3_2.cxt` sempat terdeteksi di Downloads pada pemeriksaan terdahulu, tetapi tidak lagi ada saat pemeriksaan akhir packaging. File tersebut tidak disalin ke handoff dan tidak dimasukkan ke ZIP.

## File yang tidak tersedia secara fisik

- SCADA_CP1E_Mizan_Modbus_Revision_V2_Minimal.cxt
- SCADA_CP1E_Mizan_Modbus_Revision_V3_SingleCoil.cxt
- SCADA_CP1E_Mizan_Modbus_Revision_V3_1_SingleCoil.cxt
- SCADA_LBS_PLC_V3_3_SingleCoil.cxt

Karena file-file ini tidak tersedia, tidak dibuat salinan palsu dan tidak dinyatakan lolos Program Check.

## Program Check V3.2 terakhir yang dilaporkan

Gambaran error yang dilaporkan pengguna:

MAIN - 6 errors, 0 warnings.

ERROR: Operand 1 Memory area not valid at rung 23 ( 0, 2 ).
ERROR: Operand 1 Memory area not valid at rung 24 ( 0, 4 ).
ERROR: Operand 1 Memory area not valid at rung 24 ( 0, 1 ).
ERROR: Operand 1 Memory area not valid at rung 40 ( 0, 5 ).
ERROR: Operand 1 Memory area not valid at rung 42 ( 0, 12 ).
ERROR: Operand 1 Memory area not valid at rung 43 ( 0, 3 ).

Catatan:
- error ini berasal dari V3.2, bukan V3.3.
- tidak ada bukti bahwa V3.3 telah lolos Program Check.
- alamat W/D tidak boleh diubah secara membabi buta.

## Status yang masih pending

- Final baseline V3 SingleCoil belum ditemukan di workspace.
- Program check resmi V3.2 belum disertakan dalam bentuk laporan lengkap.
- V3.3 belum tersedia sebagai file real.
- Validasi hardware PLC belum dilakukan.

## Saran lanjut

1. Cari file asli V3/V3.1/V3.3 di folder proyek, repository, cloud drive, atau machine backup.
2. Jika file asli hadir, salin ke folder handoff/plc_cxt dan buat checksum.
3. Jangan mengklaim sukses tanpa output Program Check resmi dari CX-Programmer.
4. Pakai V3 SingleCoil sebagai baseline, bukan V4 untuk final release.
