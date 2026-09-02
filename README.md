# flutter_simple_ble

Flutter plugin for Android and iOS Bluetooth Low Energy (BLE). It provides adapter
state, scanning, connections, service discovery, MTU negotiation, and
characteristic writes.

## Installation

```dart
import 'package:flutter_simple_ble/flutter_simple_ble.dart';
```

## Android permissions

The plugin declares and requests the required runtime permissions on Android
when a BLE operation first needs them. No Flutter-side permission package is
required:

- Android 12 and newer: `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`.
- Android 11 and older: location permission is required for scanning.

The system dialog is shown only while the plugin has a foreground Android
activity. Calls made while a permission dialog is open wait for its result.

## Usage

```dart
import 'package:flutter_simple_ble/flutter_simple_ble.dart';

Future<void> connectToFirstDevice() async {
  final BleScanResult result = await Ble.scan(
    timeout: const Duration(seconds: 10),
  ).first;

  final BleDevice device = result.device;
  await device.connect();
  final List<BleService> services = await device.discoverServices();
  // Select a writable characteristic from services, then write to it.
  // await characteristic.write(<int>[0x01]);
}
```

`Ble.scan()` starts scanning when it is listened to and stops when its last
listener is cancelled, or when its timeout elapses. Each event is one current
advertisement, so callers can use standard stream operators such as `first`,
`where`, and `takeWhile`.

## Example app

The `example/` directory is a complete Android and iOS Flutter app. It lets you
verify every currently supported operation: adapter state, scan,
connect/disconnect, service discovery, MTU reporting, and characteristic writes.

```sh
cd example
flutter run
```

## Platform support

- Android API 24 or newer.
- iOS 15 or newer. Add `NSBluetoothAlwaysUsageDescription` to the host app's
  `Info.plist` before using Bluetooth.

## License

Copyright 2026 Aleksandr ([Wratheus](https://github.com/Wratheus)).

Licensed under the [BSD 3-Clause License](LICENSE). You may use, modify, and
redistribute this project, provided that you retain its copyright, license, and
disclaimer notices. The attribution is also recorded in [NOTICE](NOTICE).
