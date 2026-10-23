import 'package:flutter_test/flutter_test.dart';
import 'package:scada_mizan_app/models/sensor_data.dart';

void main() {
  test('connected when app, ESP32, PLC, and data are healthy', () {
    expect(
      resolveSystemConnectionState(
        applicationConnected: true,
        lruState: LinkState.normal,
        comState: LinkState.normal,
        dataStale: false,
      ),
      SystemConnectionState.connected,
    );
  });

  test('device offline when LRUFail is FAIL', () {
    expect(
      resolveSystemConnectionState(
        applicationConnected: true,
        lruState: LinkState.fail,
        comState: LinkState.normal,
        dataStale: false,
      ),
      SystemConnectionState.deviceOffline,
    );
  });

  test('waits for device status when LRUFail is unknown', () {
    expect(
      resolveSystemConnectionState(
        applicationConnected: true,
        lruState: LinkState.unknown,
        comState: LinkState.unknown,
        dataStale: false,
      ),
      SystemConnectionState.waitingDevice,
    );
  });

  test('disconnects system when application transport is down', () {
    expect(
      resolveSystemConnectionState(
        applicationConnected: false,
        lruState: LinkState.normal,
        comState: LinkState.normal,
        dataStale: false,
      ),
      SystemConnectionState.disconnected,
    );
  });

  test('treats stale sensor data as device offline', () {
    expect(
      resolveSystemConnectionState(
        applicationConnected: true,
        lruState: LinkState.normal,
        comState: LinkState.normal,
        dataStale: true,
      ),
      SystemConnectionState.deviceOffline,
    );
  });

  test('reports degraded system when COMFail is FAIL', () {
    expect(
      resolveSystemConnectionState(
        applicationConnected: true,
        lruState: LinkState.normal,
        comState: LinkState.fail,
        dataStale: false,
      ),
      SystemConnectionState.degraded,
    );
  });
}
