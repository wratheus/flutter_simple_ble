// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_simple_ble/ble_models.dart';

import 'src/ble_channel_contract.dart';
import 'ble_platform_interface.dart';

final class BleMethodChannel extends BlePlatform {
  new() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    BleChannelContract.channelName,
  );

  final _BleReplayValue<BleAdapterState> _adapterState = _BleReplayValue(
    BleAdapterState.unknown,
  );

  final StreamController<BleScanResult> _scanResults =
      StreamController<BleScanResult>.broadcast();

  final StreamController<BleConnectionEvent> _connectionStateController =
      StreamController<BleConnectionEvent>.broadcast();

  final StreamController<BleDiscoveredServicesEvent>
  _discoveredServicesController =
      StreamController<BleDiscoveredServicesEvent>.broadcast();

  final StreamController<BleMtuEvent> _mtuChangedController =
      StreamController<BleMtuEvent>.broadcast();

  final StreamController<BleCharacteristicWriteEvent>
  _characteristicWrittenController =
      StreamController<BleCharacteristicWriteEvent>.broadcast();

  final Map<BleRemoteId, BleConnectionEvent> _connectionStates = {};

  final Map<BleRemoteId, BleDiscoveredServicesEvent> _knownServices = {};

  final Map<BleRemoteId, BleMtuEvent> _mtuValues = {};

  final Map<BleRemoteId, String> _platformNames = {};

  final Map<BleRemoteId, String> _advNames = {};

  Future<void>? _activeScan;
  int _scanListeners = 0;
  bool _isScanning = false;

  @override
  Stream<BleAdapterState> get adapterStateChanged => _adapterState.stream;

  @override
  BleAdapterState get adapterStateNow => _adapterState.latestValue;

  @override
  Stream<BleConnectionEvent> get connectionState =>
      _connectionStateController.stream;

  @override
  Stream<BleDiscoveredServicesEvent> get discoveredServices =>
      _discoveredServicesController.stream;

  @override
  Stream<BleMtuEvent> get mtuChanged => _mtuChangedController.stream;

  @override
  Stream<BleCharacteristicWriteEvent> get characteristicWritten =>
      _characteristicWrittenController.stream;

  @override
  List<BleDevice> get connectedDevices {
    final List<BleDevice> result = [];

    for (final MapEntry<BleRemoteId, BleConnectionEvent> entry
        in _connectionStates.entries) {
      if (entry.value.connectionState == BleConnectionState.connected) {
        result.add(BleDevice(remoteId: entry.key));
      }
    }

    return List<BleDevice>.unmodifiable(result);
  }

  @override
  String platformName(BleRemoteId remoteId) => _platformNames[remoteId] ?? '';

  @override
  String advName(BleRemoteId remoteId) => _advNames[remoteId] ?? '';

  @override
  bool isDeviceConnected(BleRemoteId remoteId) =>
      _connectionStates[remoteId]?.connectionState ==
      BleConnectionState.connected;

  @override
  int mtuNow(BleRemoteId remoteId) => _mtuValues[remoteId]?.mtu ?? 23;

  @override
  List<BleService> servicesForDevice(BleRemoteId remoteId) {
    final BleDiscoveredServicesEvent? result = _knownServices[remoteId];

    if (result == null) {
      return const <BleService>[];
    }

    return result.services
        .where((service) => service.isPrimary)
        .toList(growable: false);
  }

  @override
  BleCharacteristicProperties? characteristicProperties(
    BleCharacteristic characteristic,
  ) {
    final BleDiscoveredServicesEvent? result =
        _knownServices[characteristic.remoteId];

    if (result == null) {
      return null;
    }

    for (final BleService service in result.services) {
      if (service.primaryServiceUuid != characteristic.primaryServiceUuid ||
          service.serviceUuid != characteristic.serviceUuid) {
        continue;
      }

      for (final BleCharacteristic item in service.characteristics) {
        if (item.characteristicUuid == characteristic.characteristicUuid &&
            item.instanceId == characteristic.instanceId) {
          return item.discoveredProperties;
        }
      }
    }

    return null;
  }

  @override
  Future<bool> isSupported() async =>
      await methodChannel.invokeMethod<bool>(BleChannelMethod.isSupported) ??
      false;

  @override
  Future<BleAdapterState> getAdapterState() async {
    final Map<dynamic, dynamic>? response = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>(BleChannelMethod.getAdapterState);

    final BleAdapterState state = BleAdapterState.fromNative(
      response?[BleChannelKey.adapterState] as int? ?? 0,
    );

    _adapterState.add(state);

    return state;
  }

  @override
  Stream<BleScanResult> scan({Duration? timeout}) async* {
    _scanListeners++;
    _activeScan ??= _startScan();

    try {
      await _activeScan;

      if (timeout == null) {
        yield* _scanResults.stream;
      } else {
        yield* _scanResults.stream.timeout(
          timeout,
          onTimeout: (EventSink<BleScanResult> sink) => sink.close(),
        );
      }
    } finally {
      _scanListeners--;
      if (_scanListeners == 0) {
        _activeScan = null;
        await _stopScan();
      }
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) {
      return;
    }

    final bool started =
        await methodChannel.invokeMethod<bool>(BleChannelMethod.startScan) ??
        false;
    if (!started) {
      throw const BleException(
        operation: 'startScan',
        message: 'native startScan returned false',
      );
    }
    _isScanning = true;
  }

  Future<void> _stopScan() async {
    if (!_isScanning) {
      return;
    }

    try {
      await methodChannel.invokeMethod<bool>(BleChannelMethod.stopScan);
    } finally {
      _isScanning = false;
    }
  }

  @override
  Future<bool> connect(String remoteId) async =>
      await methodChannel.invokeMethod<bool>(
        BleChannelMethod.connect,
        remoteId,
      ) ??
      false;

  @override
  Future<bool> disconnect(String remoteId) async =>
      await methodChannel.invokeMethod<bool>(
        BleChannelMethod.disconnect,
        remoteId,
      ) ??
      false;

  @override
  Future<bool> discoverServices(String remoteId) async =>
      await methodChannel.invokeMethod<bool>(
        BleChannelMethod.discoverServices,
        remoteId,
      ) ??
      false;

  @override
  Future<bool> requestMtu({required String remoteId, required int mtu}) async =>
      await methodChannel.invokeMethod<bool>(
        BleChannelMethod.requestMtu,
        RequestMtuRequest(remoteId: remoteId, mtu: mtu).toMap(),
      ) ??
      false;

  @override
  Future<bool> writeCharacteristic({
    required String remoteId,
    required String serviceUuid,
    required String characteristicUuid,
    required int instanceId,
    required List<int> value,
    String? primaryServiceUuid,
    bool withoutResponse = false,
  }) async =>
      await methodChannel.invokeMethod<bool>(
        BleChannelMethod.writeCharacteristic,
        WriteCharacteristicRequest(
          remoteId: remoteId,
          primaryServiceUuid: primaryServiceUuid,
          serviceUuid: serviceUuid,
          characteristicUuid: characteristicUuid,
          instanceId: instanceId,
          value: value,
          withoutResponse: withoutResponse,
        ).toMap(),
      ) ??
      false;

  Future<void> _handleMethodCall(MethodCall call) async {
    final Map<dynamic, dynamic> map = _asMap(call.arguments);

    switch (call.method) {
      case BleChannelEvent.adapterStateChanged:
        final BleAdapterState state = BleAdapterState.fromNative(
          map[BleChannelKey.adapterState] as int? ?? 0,
        );

        _adapterState.add(state);

        if (state == BleAdapterState.off ||
            state == BleAdapterState.turningOff) {
          _isScanning = false;

          _connectionStates.clear();
          _knownServices.clear();
          _mtuValues.clear();
        }

        return;

      case BleChannelEvent.scanResponse:
        if (map[BleChannelKey.success] == 0) {
          _isScanning = false;

          _scanResults.addError(
            BleException(
              operation: 'scan',
              code: map[BleChannelKey.errorCode] as int?,
              message:
                  map[BleChannelKey.errorString] as String? ?? 'scan failed',
            ),
          );

          return;
        }

        final List<dynamic> advertisements =
            map[BleChannelKey.advertisements] as List<dynamic>? ??
            const <dynamic>[];

        for (final dynamic raw in advertisements) {
          if (raw is! Map) {
            continue;
          }

          final BleRemoteId remoteId = BleRemoteId(
            raw[BleChannelKey.remoteId] as String? ?? '',
          );

          if (remoteId.str.isEmpty) {
            continue;
          }

          final String? platformName =
              raw[BleChannelKey.platformName] as String?;

          if (platformName != null) {
            _platformNames[remoteId] = platformName;
          }

          final String? advName = raw[BleChannelKey.advName] as String?;

          if (advName != null) {
            _advNames[remoteId] = advName;
          }

          final BleScanResult result = BleScanResult.fromMap(raw);

          _scanResults.add(result);
        }

        return;

      case BleChannelEvent.connectionStateChanged:
        final BleConnectionEvent event = BleConnectionEvent.fromMap(map);

        _connectionStates[event.remoteId] = event;

        if (event.connectionState == BleConnectionState.disconnected) {
          _knownServices.remove(event.remoteId);

          _mtuValues.remove(event.remoteId);
        }

        _connectionStateController.add(event);

        return;

      case BleChannelEvent.discoveredServices:
        final BleDiscoveredServicesEvent event =
            BleDiscoveredServicesEvent.fromMap(map);

        if (event.success) {
          _knownServices[event.remoteId] = event;
        }

        _discoveredServicesController.add(event);

        return;

      case BleChannelEvent.mtuChanged:
        final BleMtuEvent event = BleMtuEvent.fromMap(map);

        if (event.success) {
          _mtuValues[event.remoteId] = event;
        }

        _mtuChangedController.add(event);

        return;

      case BleChannelEvent.characteristicWritten:
        _characteristicWrittenController.add(
          BleCharacteristicWriteEvent.fromMap(map),
        );

        return;
    }
  }

  Map<dynamic, dynamic> _asMap(Object? value) {
    if (value is Map) {
      return value;
    }

    return const <dynamic, dynamic>{};
  }
}

final class _BleReplayValue<T> {
  new(this.latestValue);

  final StreamController<T> _controller = StreamController<T>.broadcast();

  T latestValue;

  Stream<T> get stream =>
      _controller.stream.transform(_BleReplayTransformer<T>(latestValue));

  void add(T value) {
    latestValue = value;
    _controller.add(value);
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    _controller.addError(error, stackTrace);
  }
}

final class _BleReplayTransformer<T> extends StreamTransformerBase<T, T> {
  const new(this.initialValue);

  final T initialValue;

  @override
  Stream<T> bind(Stream<T> stream) async* {
    yield initialValue;
    yield* stream;
  }
}
