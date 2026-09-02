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

The `example/` directory is a complete Android Flutter app. It requests the
runtime permissions and lets you verify every currently supported operation:
adapter state, scan, connect/disconnect, service discovery, MTU negotiation,
and characteristic writes.

```sh
cd example
flutter run
```

## Platform support

- Android API 24 or newer.
- iOS is not implemented yet.
