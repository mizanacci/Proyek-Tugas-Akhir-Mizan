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

// ISRG Root X1 from Let's Encrypt, used to validate HiveMQ Cloud TLS.
static const char* CA_CERT_LETSENCRYPT = R"EOF(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
)EOF";

static unsigned long waktuReconnectTerakhir = 0;
#define INTERVAL_RECONNECT_MS 5000
#define INTERVAL_HEARTBEAT_COMFAIL_MS 5000

static bool comFailTerakhir = false;
static bool comFailPernahKirim = false;
static unsigned long waktuKirimComFail = 0;
static unsigned long waktuPublishSensorTerakhir = 0;
static uint32_t jumlahPublishGagal = 0;

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
  // pesan ini ke TOPIC_STATUS_LRUF jika koneksi client ini terputus tanpa
  // proses disconnect yang bersih — inilah mekanisme deteksi LRUFail.
  const char* pesanLWT = "{\"status\":\"FAIL\",\"source\":\"lwt\"}";
  bool ok = mqttClient.connect(
      MQTT_CLIENT_ID,
      MQTT_USERNAME,
      MQTT_PASSWORD,
      TOPIC_STATUS_LRUF,  // willTopic
      1,                  // willQos (1 = at-least-once, sesuai kebutuhan status kritikal)
      true,               // willRetain — agar subscriber baru langsung tahu status terakhir
      pesanLWT
  );

  if (ok) {
    Serial.println("[MQTT] Terhubung ke HiveMQ Cloud.");
    mqttClient.subscribe(TOPIC_CMD_REMOTE);
    // Publikasikan status NORMAL segera setelah tersambung, menimpa
    // kemungkinan pesan LWT lama yang masih ter-retain dari sesi sebelumnya.
    mqttClient.publish(TOPIC_STATUS_LRUF, "{\"status\":\"NORMAL\",\"source\":\"connect\"}", true);
    // hapus sisa pesan retained di topic lama (aman dibiarkan; boleh dihapus kelak)
    mqttClient.publish("scada/mizan/status/lwt", (const uint8_t*)"", 0, true);
    comFailPernahKirim = false;
    statusMqttTerhubung = true;
  } else {
    Serial.print("[MQTT] Gagal terhubung, kode state PubSubClient: ");
    Serial.println(mqttClient.state());
    statusMqttTerhubung = false;
  }
}

void mqttHandlerInit() {
  statusMqttTerhubung = false;

  wifiClientSecure.setCACert(CA_CERT_LETSENCRYPT);

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
  if (xQueueReceive(queueDataSensor, &hasil, 0) == pdTRUE &&
      (waktuPublishSensorTerakhir == 0 ||
       millis() - waktuPublishSensorTerakhir >= INTERVAL_PUBLISH_SENSOR_MS)) {
    mqttPublishDataSensor(hasil);
    waktuPublishSensorTerakhir = millis();
  }

  // Publikasikan estimasi COMFail sisi ESP32 saat berubah atau heartbeat.
  mqttPublishComFailEstimasi(statusComFailEstimasiLokal);
}

void mqttPublishDataSensor(const HasilSensor& hasil) {
  if (!mqttClient.connected()) {
    ++jumlahPublishGagal;
    Serial.printf("[MQTT] PUBLISH SENSOR FAILED disconnected (count=%lu)\n",
                  static_cast<unsigned long>(jumlahPublishGagal));
    return;
  }

  StaticJsonDocument<256> doc;
  doc["v_sumber"] = hasil.tegangan_sumber;
  doc["v_beban"]  = hasil.tegangan_beban;
  doc["i_sumber"] = hasil.arus_sumber;
  doc["i_beban"]  = hasil.arus_beban;
  doc["kualitas"] = hasil.bitmask_kualitas;  // bitmask GOOD(0)/SUSPECT(1), lihat config.h
  doc["ts"]       = millis();  // [DRAF] pertimbangkan NTP/epoch time asli untuk BAB 4 bila diperlukan timestamp absolut

  char buffer[256];
  size_t n = serializeJson(doc, buffer);
  if (doc.overflowed() || n == 0 || n >= sizeof(buffer)) {
    ++jumlahPublishGagal;
    Serial.printf("[MQTT] PUBLISH SENSOR FAILED invalid JSON (count=%lu)\n",
                  static_cast<unsigned long>(jumlahPublishGagal));
    return;
  }

  if (mqttClient.publish(TOPIC_DATA_SENSOR,
                         reinterpret_cast<const uint8_t*>(buffer), n, false)) {
    Serial.println("[MQTT] PUBLISH SENSOR ACCEPTED (QoS 0)");
  } else {
    ++jumlahPublishGagal;
    Serial.printf("[MQTT] PUBLISH SENSOR FAILED (count=%lu)\n",
                  static_cast<unsigned long>(jumlahPublishGagal));
  }
}

void mqttPublishComFailEstimasi(bool statusFail) {
  if (!mqttClient.connected()) return;
  unsigned long now = millis();
  bool berubah = (!comFailPernahKirim) || (statusFail != comFailTerakhir);
  bool heartbeat = (now - waktuKirimComFail) >= INTERVAL_HEARTBEAT_COMFAIL_MS;
  if (!berubah && !heartbeat) return;

  const char* payload = statusFail
      ? "{\"status\":\"FAIL\",\"source\":\"esp32_watchdog_estimate\"}"
      : "{\"status\":\"NORMAL\",\"source\":\"esp32_watchdog_estimate\"}";
  if (!mqttClient.publish(TOPIC_STATUS_COMF, payload, true)) {
    ++jumlahPublishGagal;
    Serial.printf("[MQTT] PUBLISH COMFAIL FAILED (count=%lu)\n",
                  static_cast<unsigned long>(jumlahPublishGagal));
    return;
  }
  comFailTerakhir = statusFail;
  comFailPernahKirim = true;
  waktuKirimComFail = now;
}

bool mqttTerhubung() {
  return mqttClient.connected();
}
