import 'package:flutter_test/flutter_test.dart';
import 'package:scada_mizan_app/services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MQTT client ID is stable per installation and differs across installs',
      () async {
    SharedPreferences.setMockInitialValues({});
    final firstInstall = MqttService();
    final firstId = await firstInstall.clientIdUntukInstalasi();
    expect(await firstInstall.clientIdUntukInstalasi(), firstId);

    SharedPreferences.setMockInitialValues({});
    final secondInstall = MqttService();
    final secondId = await secondInstall.clientIdUntukInstalasi();
    expect(secondId, isNot(firstId));
    expect(firstId, isNot(contains('same-user')));

    firstInstall.dispose();
    secondInstall.dispose();
  });
}
