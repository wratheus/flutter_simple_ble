// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import 'package:flutter_simple_ble/ble_models.dart';

import 'ble_platform_interface.dart';

final class Ble {
  new _();

  static BlePlatform get _platform => BlePlatform.instance;

  static Future<bool> get isSupported => _platform.isSupported();

  static Future<BleAdapterState> refreshAdapterState() =>
      _platform.getAdapterState();

  static Stream<BleAdapterState> get adapterState async* {
    if (_platform.adapterStateNow == BleAdapterState.unknown) {
      await _platform.getAdapterState();
    }

    yield* _platform.adapterStateChanged;
  }

  static BleAdapterState get adapterStateNow => _platform.adapterStateNow;

  /// Scans for nearby BLE devices until the listener cancels the stream.
  ///
  /// When [timeout] elapses, the stream closes and scanning stops if it has no
  /// remaining listeners. On Android, the plugin requests runtime permissions
  /// before scanning when they have not yet been granted.
  static Stream<BleScanResult> scan({Duration? timeout}) =>
      _platform.scan(timeout: timeout);

  static List<BleDevice> get connectedDevices => _platform.connectedDevices;

  static Stream<List<BleDevice>> get connectedDevicesChanged async* {
    yield connectedDevices;
    yield* _platform.connectionState.map((_) => connectedDevices);
  }
}
