/**
 * mqtt_handler.cpp — Implementasi WiFi + MQTT client (HiveMQ Cloud)
 * Tugas Akhir SCADA Distribusi Listrik — Almar'u Zaim Mizan (04231006)
 *
 * Library: WiFiClientSecure (bawaan core ESP32) + PubSubClient (lib_deps).
 * Berjalan di Core 0 — lihat shared_state.h untuk mekanisme komunikasi
 * aman ke/dari Core 1 (task ADC+Modbus).
 */

#include "mqtt_handler.h"
#include "config.h"
#include "shared_state.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

static WiFiClientSecure wifiClientSecure;
static PubSubClient mqttClient(wifiClientSecure);

// === Sertifikat CA root (Let's Encrypt) — [DRAF, PERLU DIISI] ===
// HiveMQ Cloud memakai sertifikat TLS yang diterbitkan Let's Encrypt.
// Unduh root CA resmi (ISRG Root X1) dari https://letsencrypt.org/certificates/
// dan tempelkan isi file .pem di antara tanda kutip di bawah, ATAU — khusus
// untuk tahap pengembangan/prototipe di laboratorium, boleh sementara
// memakai wifiClientSecure.setInsecure() (melewati verifikasi sertifikat)
// sebagai pengganti setCACert() di bawah; TIDAK direkomendasikan untuk
// penggunaan di luar tahap uji coba karena tidak memvalidasi identitas
// broker. Tandai eksplisit di BAB 4 opsi mana yang dipakai pada
// implementasi akhir dan alasannya.
static const char* CA_CERT_LETSENCRYPT = R"EOF(
-----BEGIN CERTIFICATE-----
ISI_DENGAN_ISRG_ROOT_X1_DARI_LETSENCRYPT_ORG
-----END CERTIFICATE-----
)EOF";

static unsigned long waktuReconnectTerakhir = 0;
#define INTERVAL_RECONNECT_MS 5000

// --- Callback dipanggil PubSubClient saat pesan masuk dari topic yang di-subscribe ---
static void mqttCallback(char* topic, byte* payload, unsigned int length) {
  // Hanya TOPIC_CMD_REMOTE yang di-subscribe firmware ini, tapi tetap
  // diperiksa agar aman bila topic subscribe bertambah di masa depan.
  if (strcmp(topic, TOPIC_CMD_REMOTE) != 0) return;

  StaticJsonDocument<128> doc;
  DeserializationError err = deserializeJson(doc, payload, length);
  if (err) {
    Serial.print("[MQTT] Gagal parse JSON perintah: ");
    Serial.println(err.c_str());
    return;
  }

  // Format payload yang diharapkan dari aplikasi Flutter: {"command":"NO"}
  // atau {"command":"NC"} — lihat dokumen 04_Konfigurasi_HiveMQ.md dan
  // service MQTT pada struktur workspace Flutter (dokumen 05) untuk
  // kesepakatan format ini.
  const char* cmd = doc["command"];
  uint16_t nilai = 0;
  if (cmd && strcmp(cmd, "NO") == 0) nilai = 1;
  else if (cmd && strcmp(cmd, "NC") == 0) nilai = 2;
  else {
    Serial.println("[MQTT] Nilai command tidak dikenali, diabaikan.");
    return;
  }

  // Kirim ke Core 1 melalui queue — JANGAN memanggil fungsi modul Modbus
  // secara langsung dari sini (callback ini berjalan di konteks Core 0).
  xQueueOverwrite(queuePerintahRemote, &nilai);
}

static void wifiConnect() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("[WiFi] Menghubungkan");
  unsigned long mulai = millis();
  while (WiFi.status() != WL_CONNECTED && (millis() - mulai) < 15000) {
    delay(300);
    Serial.print(".");
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("[WiFi] Terhubung, IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("[WiFi] Gagal terhubung dalam batas waktu — akan dicoba ulang otomatis.");
  }
}

static void mqttReconnect() {
  if (WiFi.status() != WL_CONNECTED) {
    wifiConnect();
    return;
  }
  if (mqttClient.connected()) return;
  if (millis() - waktuReconnectTerakhir < INTERVAL_RECONNECT_MS) return;
  waktuReconnectTerakhir = millis();

  Serial.println("[MQTT] Mencoba menghubungkan ke broker...");

  // LWT (Last Will and Testament): didaftarkan SAAT connect(), bukan
  // dipublikasikan manual. Broker HiveMQ akan otomatis mempublikasikan
  // pesan ini ke TOPIC_STATUS_LWT jika koneksi client ini terputus tanpa
  // proses disconnect yang bersih — inilah mekanisme deteksi LRUFail.
  const char* pesanLWT = "{\"status\":\"FAIL\",\"source\":\"lwt\"}";
  bool ok = mqttClient.connect(
      MQTT_CLIENT_ID,
      MQTT_USERNAME,
      MQTT_PASSWORD,
      TOPIC_STATUS_LWT,   // willTopic
      1,                  // willQos (1 = at-least-once, sesuai kebutuhan status kritikal)
      true,               // willRetain — agar subscriber baru langsung tahu status terakhir
      pesanLWT
  );

  if (ok) {
    Serial.println("[MQTT] Terhubung ke HiveMQ Cloud.");
    mqttClient.subscribe(TOPIC_CMD_REMOTE);
    // Publikasikan status NORMAL segera setelah tersambung, menimpa
    // kemungkinan pesan LWT lama yang masih ter-retain dari sesi sebelumnya.
    mqttClient.publish(TOPIC_STATUS_LWT, "{\"status\":\"NORMAL\",\"source\":\"connect\"}", true);
    statusMqttTerhubung = true;
  } else {
    Serial.print("[MQTT] Gagal terhubung, kode state PubSubClient: ");
    Serial.println(mqttClient.state());
    statusMqttTerhubung = false;
  }
}

void mqttHandlerInit() {
  statusMqttTerhubung = false;

  // Tahap uji coba lab: ini melewati validasi sertifikat. Sebelum penggunaan
  // di luar lab, nonaktifkan setInsecure() dan gunakan setCACert() dengan
  // root CA Let's Encrypt asli.
  // wifiClientSecure.setCACert(CA_CERT_LETSENCRYPT);
  wifiClientSecure.setInsecure();

  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  // Buffer default PubSubClient (256 byte) bisa terlalu kecil untuk payload
  // JSON gabungan 4 nilai RMS + metadata; dinaikkan agar aman.
  mqttClient.setBufferSize(512);

  wifiConnect();
  mqttReconnect();
}

void mqttHandlerTask() {
  if (!mqttClient.connected()) {
    statusMqttTerhubung = false;
    mqttReconnect();
  }
  mqttClient.loop();  // memproses pesan masuk (memicu mqttCallback) + kirim PINGREQ berkala

  // Ambil data sensor terbaru dari Core 1 (non-blocking, xQueueReceive
  // dengan timeout 0 — jika belum ada data baru, lewati publish siklus ini)
  HasilSensor hasil;
  if (xQueueReceive(queueDataSensor, &hasil, 0) == pdTRUE) {
    mqttPublishDataSensor(hasil);
  }

  // Publikasikan estimasi COMFail sisi ESP32 setiap siklus (nilai dibaca
  // dari variabel shared, ditulis Core 1 — lihat shared_state.h)
  mqttPublishComFailEstimasi(statusComFailEstimasiLokal);
}

void mqttPublishDataSensor(const HasilSensor& hasil) {
  if (!mqttClient.connected()) return;

  StaticJsonDocument<256> doc;
  doc["v_sumber"] = hasil.tegangan_sumber;
  doc["v_beban"]  = hasil.tegangan_beban;
  doc["i_sumber"] = hasil.arus_sumber;
  doc["i_beban"]  = hasil.arus_beban;
  doc["kualitas"] = hasil.bitmask_kualitas;  // bitmask GOOD(0)/SUSPECT(1), lihat config.h
  doc["ts"]       = millis();  // [DRAF] pertimbangkan NTP/epoch time asli untuk BAB 4 bila diperlukan timestamp absolut

  char buffer[256];
  size_t n = serializeJson(doc, buffer);
  mqttClient.publish(TOPIC_DATA_SENSOR, (uint8_t*)buffer, n, false);
}

void mqttPublishComFailEstimasi(bool statusFail) {
  if (!mqttClient.connected()) return;
  const char* payload = statusFail
      ? "{\"status\":\"FAIL\",\"source\":\"esp32_watchdog_estimate\"}"
      : "{\"status\":\"NORMAL\",\"source\":\"esp32_watchdog_estimate\"}";
  mqttClient.publish(TOPIC_STATUS_COMF, payload);
}

bool mqttTerhubung() {
  return mqttClient.connected();
}
