// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_simple_ble/ble_method_channel.dart';
import 'package:flutter_simple_ble/ble_models.dart';

abstract class BlePlatform extends PlatformInterface {
  new() : super(token: _token);

  static final Object _token = Object();

  static BlePlatform _instance = BleMethodChannel();

  static BlePlatform get instance => _instance;

  static set instance(BlePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);

    _instance = instance;
  }

  Stream<BleAdapterState> get adapterStateChanged;

  Stream<BleConnectionEvent> get connectionState;

  Stream<BleDiscoveredServicesEvent> get discoveredServices;

  Stream<BleMtuEvent> get mtuChanged;

  Stream<BleCharacteristicWriteEvent> get characteristicWritten;

  BleAdapterState get adapterStateNow;

  List<BleDevice> get connectedDevices;

  String platformName(BleRemoteId remoteId);

  String advName(BleRemoteId remoteId);

  bool isDeviceConnected(BleRemoteId remoteId);

  int mtuNow(BleRemoteId remoteId);

  List<BleService> servicesForDevice(BleRemoteId remoteId);

  BleCharacteristicProperties? characteristicProperties(
    BleCharacteristic characteristic,
  );

  Future<bool> isSupported();

  Future<BleAdapterState> getAdapterState();

  Stream<BleScanResult> scan({Duration? timeout});

  Future<bool> connect(String remoteId);

  Future<bool> disconnect(String remoteId);

  Future<bool> discoverServices(String remoteId);

  Future<bool> requestMtu({required String remoteId, required int mtu});

  Future<bool> writeCharacteristic({
    required String remoteId,
    required String serviceUuid,
    required String characteristicUuid,
    required int instanceId,
    required List<int> value,
    String? primaryServiceUuid,
    bool withoutResponse,
  });
}
