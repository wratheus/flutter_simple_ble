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

  static BleAdapterState get adapterStateNow =>
      _platform.adapterStateNow;

  static Stream<bool> get isScanning => _platform.isScanning;

  static bool get isScanningNow => _platform.isScanningNow;

  static Stream<List<BleScanResult>> get scanResults =>
      _platform.scanResults;

  static List<BleScanResult> get lastScanResults =>
      _platform.lastScanResults;

  static List<BleDevice> get connectedDevices =>
      _platform.connectedDevices;

  static Stream<List<BleDevice>> get connectedDevicesChanged async* {
    yield connectedDevices;
    yield* _platform.connectionState.map((_) => connectedDevices);
  }

  /// Starts a BLE scan.
  ///
  /// Request the required Android runtime permissions before calling this.
  static Future<void> startScan({Duration? timeout}) async {
    final bool started = await _platform.startScan(timeout: timeout);
    if (!started) {
      throw const BleException(
        operation: 'startScan',
        message: 'native startScan returned false',
      );
    }
  }

  static Future<void> stopScan() async {
    await _platform.stopScan();
  }
}
