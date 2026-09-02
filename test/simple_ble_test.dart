// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_simple_ble/flutter_simple_ble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_simple_ble');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('scan starts on listen and stops after timeout', () async {
    final List<String> methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          methods.add(call.method);
          return true;
        });

    await Ble.scan(timeout: Duration.zero).drain<void>();

    expect(methods, <String>['startScan', 'stopScan']);
  });

  test('scan result retains native advertisement fields and names', () {
    final BleScanResult result = BleScanResult.fromMap(<String, Object>{
      'remote_id': 'AA:BB:CC:DD:EE:FF',
      'platform_name': 'Cached name',
      'connectable': 1,
      'adv_name': 'BLE sensor',
      'tx_power_level': -12,
      'appearance': 768,
      'manufacturer_data': <int, List<int>>{
        76: <int>[1, 2, 3],
      },
      'service_data': <String, List<int>>{
        '180f': <int>[86],
      },
      'service_uuids': <String>['180f', '180a'],
    });
    final BleAdvertisementData data = result.advertisementData;

    expect(result.device.platformName, 'Cached name');
    expect(result.device.advName, 'BLE sensor');
    expect(data.connectable, isTrue);
    expect(data.advName, 'BLE sensor');
    expect(data.txPowerLevel, -12);
    expect(data.appearance, 768);
    expect(data.manufacturerData, <int, List<int>>{
      76: <int>[1, 2, 3],
    });
    expect(data.serviceData, <String, List<int>>{
      '180f': <int>[86],
    });
    expect(data.serviceUuids, <String>['180f', '180a']);
  });

  test(
    'disconnect reaches native side while device is not connected',
    () async {
      final List<String> methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            methods.add(call.method);
            return false;
          });

      await BleDevice.fromId('AA:BB:CC:DD:EE:FF').disconnect();

      expect(methods, <String>['disconnect']);
    },
  );
}
