# flutter_simple_ble

Flutter plugin for Android Bluetooth Low Energy (BLE). It provides adapter
state, scanning, connections, service discovery, MTU negotiation, and
characteristic writes.

## Installation

```dart
import 'package:flutter_simple_ble/flutter_simple_ble.dart';
```

## Android permissions

The plugin declares the required permissions in its Android manifest, but an
application must request runtime permissions before using BLE:

- Android 12 and newer: `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`.
- Android 11 and older: location permission is required for scanning.

The plugin does not depend on a particular permission package. Request these
permissions with the solution used by the host application, then check
`await Ble.isSupported` and listen to `Ble.adapterState`.

## Usage

```dart
import 'dart:async';

import 'package:flutter_simple_ble/flutter_simple_ble.dart';

Future<void> connectToFirstDevice() async {
  final Completer<BleDevice> firstDevice = Completer<BleDevice>();
  late final StreamSubscription<List<BleScanResult>> subscription;

  subscription = Ble.scanResults.listen((List<BleScanResult> results) {
    if (results.isNotEmpty && !firstDevice.isCompleted) {
      firstDevice.complete(results.first.device);
    }
  });

  try {
    await Ble.startScan(timeout: const Duration(seconds: 10));
    final BleDevice device = await firstDevice.future.timeout(
      const Duration(seconds: 10),
    );

    await Ble.stopScan();
    await device.connect();
    final List<BleService> services = await device.discoverServices();
    // Select a characteristic from services, then write to it.
    // await characteristic.write(<int>[0x01]);
  } finally {
    await Ble.stopScan();
    await subscription.cancel();
  }
}
```

`Ble.scanResults` contains the accumulated latest result for each device.
Use `Ble.connectedDevices` or `device.connectionState` to observe connections.

## Platform support

- Android API 24 or newer.
- iOS is not implemented yet.
