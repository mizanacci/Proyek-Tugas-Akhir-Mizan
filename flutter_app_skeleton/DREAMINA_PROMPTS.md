# Prompt Dreamina - Aset Visual SCADA Distribusi Listrik

Gunakan satu gaya visual yang konsisten untuk semua aset: industrial modern, teknis, rapi, tepercaya, cocok untuk aplikasi SCADA distribusi listrik berbasis PLC OMRON dan IoT. Palet utama navy gelap, biru elektrik, cyan, putih, dan aksen amber keselamatan. Hindari tampilan game, cyberpunk berlebihan, neon ungu, kabel acak, percikan listrik, logo perusahaan nyata, dan teks yang salah eja.

## 1. Logo utama aplikasi

**Prompt:**

> Professional vector logo for a mobile SCADA electrical distribution monitoring application named "SCADA Mizan". Abstract geometric symbol combining an electrical lightning pulse, a simplified power grid node, and a subtle monitoring waveform. Precise clean lines, balanced proportions, industrial engineering identity, navy blue and electric cyan with a small amber accent, flat vector style, high contrast, memorable at small size, centered composition, transparent background, no mockup, no device frame, no extra symbols, no decorative text.

**Negative prompt:**

> photorealistic, 3D render, complex circuit board, tangled wires, lightning storm, fire, cyberpunk, purple gradient, excessive glow, watermark, misspelled words, random letters, low resolution, background, frame.

**Output:** PNG transparan, 2048 x 2048, logo terpusat.

## 2. Ikon aplikasi Android

**Prompt:**

> Premium Android app icon for "SCADA Mizan", square canvas with rounded-corner safe area. A bold geometric power-grid monitoring emblem, electric cyan waveform crossing a dark navy relay node, amber status light accent, clean flat vector design, strong silhouette, readable at 48 pixels, centered, no words, no letters, no thin details, no border outside the safe area.

**Negative prompt:**

> text, letters, tiny details, photorealism, 3D device, metallic bevel, purple, red danger theme, clutter, watermark, cropped symbol.

**Output:** PNG, 1024 x 1024, include a version with background and a version with transparent background.

## 3. Splash screen Android

**Prompt:**

> Minimal professional splash screen artwork for a SCADA electrical distribution mobile app. Deep navy background, a clean abstract power-grid and monitoring waveform symbol in electric cyan, one small amber indicator light, generous empty space in the center for the app logo, calm technical atmosphere, flat vector style, premium industrial software identity, vertical mobile composition, no text, no UI controls, no device mockup.

**Negative prompt:**

> large text, slogan, buttons, login form, photorealistic power station, dramatic storm, excessive glow, purple, clutter, watermark.

**Output:** PNG 1080 x 1920, keep central logo area clear.

## 4. Latar belakang layar login

**Prompt:**

> Subtle vertical mobile background for a professional electrical SCADA login screen. Soft navy-to-slate blue atmosphere with a very faint abstract power distribution topology: thin grid lines, small node points, and a restrained cyan waveform flowing diagonally. Elegant, low contrast, large clean negative space in the center and lower half for readable login controls, modern industrial dashboard aesthetic, no text, no buttons, no logos, no photorealistic equipment.

**Negative prompt:**

> busy circuit board, strong geometric clutter, high contrast behind text, purple, neon cyberpunk, orange overload, 3D render, watermark, words, letters.

**Output:** PNG 1080 x 1920, portrait, dark enough for white text but not black.

## 5. Ilustrasi kosong saat menunggu data sensor

**Prompt:**

> Friendly but professional empty-state illustration for an electrical SCADA monitoring app: a simple substation and sensor gateway connected by three clean signal lines to a monitoring panel, one pulsing cyan indicator suggesting "waiting for sensor data", flat vector illustration, navy, cyan, white and amber palette, lots of transparent or plain background space, technically credible, no text, no UI screenshot.

**Negative prompt:**

> sad character, cartoon mascot, fantasy, broken equipment, fire, danger, random labels, fake numbers, watermark, purple, photorealistic.

**Output:** PNG with transparent background, 1600 x 1000.

## 6. Ilustrasi koneksi MQTT gagal

**Prompt:**

> Professional empty-state illustration for MQTT connection failure in an industrial SCADA app: a clean monitoring gateway icon with a disconnected signal link and a small amber warning indicator, calm troubleshooting mood, flat vector style, navy blue, cyan, white and amber, simple shapes, clear silhouette, no text, transparent background.

**Negative prompt:**

> red alarm explosion, panic, hacker imagery, server room photo, cyberpunk, complex details, words, letters, watermark.

**Output:** PNG transparent, 1200 x 900.

## 7. Ikon status LRUFail dan COMFail

**Prompt:**

> Two matching professional vector status icons for an electrical SCADA application: icon one represents a healthy communication link between PLC and ESP32, icon two represents a monitored link warning. Use the same visual family, rounded geometric engineering lines, cyan for normal communication and amber for warning, navy outline, no words, no letters, no red panic symbol, transparent background, designed for small dashboard cards.

**Negative prompt:**

> inconsistent icon styles, photorealism, text, letters, complex circuit, purple, skull, fire, watermark.

**Output:** Two separate PNG files, 512 x 512 each, transparent background.

## 8. Ilustrasi kontrol LBS

**Prompt:**

> Clean technical vector illustration of a medium-voltage distribution line switch controlled by a PLC and mobile SCADA system, shown as a simplified safe schematic: utility pole, LBS switch, relay control signal, and monitoring tablet silhouette connected with clean lines. Industrial engineering style, navy blue, electric cyan, white and amber, no realistic hazardous high-voltage sparks, no text, no brand logos, transparent background.

**Negative prompt:**

> exposed dangerous wires, sparks, fire, accident, photorealistic person, brand logo, unreadable labels, cyberpunk, purple, watermark.

**Output:** PNG transparent, 1600 x 1000.

## 9. Background banner monitoring

**Prompt:**

> Wide subtle header background for a professional SCADA monitoring dashboard: abstract electrical distribution network lines, three measured signal traces, small circular grid nodes, deep navy background with restrained electric cyan and amber accents, low contrast and large empty space for title and live values, clean flat vector engineering style, no text, no numbers, no UI controls.

**Negative prompt:**

> busy dashboard screenshot, fake readings, text, letters, excessive glow, purple gradient, photorealistic power plant, watermark.

**Output:** PNG 1600 x 500, wide landscape.

## 10. Aturan ekspor dan penamaan file

Simpan aset dengan nama berikut agar mudah dipasang ke Flutter:

- `scada_mizan_logo.png`
- `scada_mizan_app_icon.png`
- `scada_mizan_splash.png`
- `scada_mizan_login_background.png`
- `empty_sensor_waiting.png`
- `empty_mqtt_disconnected.png`
- `status_link_normal.png`
- `status_link_warning.png`
- `lbs_control_illustration.png`
- `monitoring_header_background.png`

Utamakan PNG transparan untuk logo, ikon, empty state, dan ilustrasi. Jangan masukkan tulisan ke dalam gambar kecuali logo final memang sudah diuji ejaannya. Teks seperti "SCADA Distribusi Listrik", "Monitoring", "NORMAL", dan "FAIL" sebaiknya tetap dibuat oleh Flutter agar tajam, mudah diterjemahkan, dan aksesibel.
