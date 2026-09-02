// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_simple_ble/ble_platform_interface.dart';

import 'src/ble_channel_contract.dart';

enum BleAdapterState {
  unknown,
  unavailable,
  unauthorized,
  turningOn,
  on,
  turningOff,
  off;

  static BleAdapterState fromNative(int value) => switch (value) {
    1 => BleAdapterState.unavailable,
    2 => BleAdapterState.unauthorized,
    3 => BleAdapterState.turningOn,
    4 => BleAdapterState.on,
    5 => BleAdapterState.turningOff,
    6 => BleAdapterState.off,
    _ => BleAdapterState.unknown,
  };
}

enum BleConnectionState {
  disconnected,
  connected;

  static BleConnectionState fromNative(int value) => switch (value) {
    1 => BleConnectionState.connected,
    _ => BleConnectionState.disconnected,
  };
}

@immutable
final class BleRemoteId {
  const new(this.str);

  final String str;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BleRemoteId && other.str == str;

  @override
  int get hashCode => str.hashCode;

  @override
  String toString() => str;
}

final class BleException implements Exception {
  const new({required this.operation, required this.message, this.code});

  final String operation;
  final String message;
  final int? code;

  @override
  String toString() =>
      'BleException('
      'operation: $operation, '
      'code: $code, '
      'message: $message'
      ')';
}

final class BleAdvertisementData {
  const new({
    required this.connectable,
    this.advName = '',
    this.txPowerLevel,
    this.appearance,
    this.manufacturerData = const <int, List<int>>{},
    this.serviceData = const <String, List<int>>{},
    this.serviceUuids = const <String>[],
  });

  final bool connectable;
  final String advName;
  final int? txPowerLevel;
  final int? appearance;
  final Map<int, List<int>> manufacturerData;
  final Map<String, List<int>> serviceData;
  final List<String> serviceUuids;

  factory fromMap(Map<dynamic, dynamic> map) {
    return BleAdvertisementData(
      connectable:
          map[BleChannelKey.connectable] == 1 ||
          map[BleChannelKey.connectable] == true,
      advName: map[BleChannelKey.advName] as String? ?? '',
      txPowerLevel: map[BleChannelKey.txPowerLevel] as int?,
      appearance: map[BleChannelKey.appearance] as int?,
      manufacturerData: _intByteMap(map[BleChannelKey.manufacturerData]),
      serviceData: _stringByteMap(map[BleChannelKey.serviceData]),
      serviceUuids: _stringList(map[BleChannelKey.serviceUuids]),
    );
  }

  static Map<int, List<int>> _intByteMap(Object? value) {
    if (value is! Map) return const <int, List<int>>{};

    final Map<int, List<int>> result = <int, List<int>>{};
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      if (entry.key is int && entry.value is List<int>) {
        result[entry.key as int] = List<int>.unmodifiable(
          entry.value as List<int>,
        );
      }
    }
    return Map<int, List<int>>.unmodifiable(result);
  }

  static Map<String, List<int>> _stringByteMap(Object? value) {
    if (value is! Map) return const <String, List<int>>{};

    final Map<String, List<int>> result = <String, List<int>>{};
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      if (entry.key is String && entry.value is List<int>) {
        result[entry.key as String] = List<int>.unmodifiable(
          entry.value as List<int>,
        );
      }
    }
    return Map<String, List<int>>.unmodifiable(result);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const <String>[];
    return List<String>.unmodifiable(value.whereType<String>());
  }
}

@immutable
final class BleScanResult {
  const new({
    required this.device,
    required this.advertisementData,
    required this.rssi,
  });

  final BleDevice device;
  final BleAdvertisementData advertisementData;
  final int rssi;

  factory fromMap(Map<dynamic, dynamic> map) {
    final String remoteId = map[BleChannelKey.remoteId] as String? ?? '';

    return BleScanResult(
      device: BleDevice.fromId(
        remoteId,
        platformName: map[BleChannelKey.platformName] as String?,
        advName: map[BleChannelKey.advName] as String?,
      ),
      advertisementData: BleAdvertisementData.fromMap(map),
      rssi: map[BleChannelKey.rssi] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleScanResult && other.device == device;

  @override
  int get hashCode => device.hashCode;
}

final class BleConnectionEvent {
  const new({
    required this.remoteId,
    required this.connectionState,
    this.disconnectReasonCode,
    this.disconnectReasonString,
  });

  final BleRemoteId remoteId;
  final BleConnectionState connectionState;

  final int? disconnectReasonCode;
  final String? disconnectReasonString;

  factory fromMap(Map<dynamic, dynamic> map) => BleConnectionEvent(
    remoteId: BleRemoteId(map[BleChannelKey.remoteId] as String? ?? ''),
    connectionState: BleConnectionState.fromNative(
      map[BleChannelKey.connectionState] as int? ?? 0,
    ),
    disconnectReasonCode: map[BleChannelKey.disconnectReasonCode] as int?,
    disconnectReasonString:
        map[BleChannelKey.disconnectReasonString] as String?,
  );
}

final class BleMtuEvent {
  const new({
    required this.remoteId,
    required this.mtu,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  final BleRemoteId remoteId;
  final int mtu;
  final bool success;
  final int errorCode;
  final String errorString;

  factory fromMap(Map<dynamic, dynamic> map) => BleMtuEvent(
    remoteId: BleRemoteId(map[BleChannelKey.remoteId] as String? ?? ''),
    mtu: map[BleChannelKey.mtu] as int? ?? 23,
    success:
        map[BleChannelKey.success] == 1 || map[BleChannelKey.success] == true,
    errorCode: map[BleChannelKey.errorCode] as int? ?? 0,
    errorString: map[BleChannelKey.errorString] as String? ?? '',
  );
}

final class BleCharacteristicProperties {
  const new({
    this.broadcast = false,
    this.read = false,
    this.writeWithoutResponse = false,
    this.write = false,
    this.notify = false,
    this.indicate = false,
    this.authenticatedSignedWrites = false,
    this.extendedProperties = false,
  });

  final bool broadcast;
  final bool read;
  final bool writeWithoutResponse;
  final bool write;
  final bool notify;
  final bool indicate;
  final bool authenticatedSignedWrites;
  final bool extendedProperties;

  factory fromMap(Map<dynamic, dynamic> map) {
    bool flag(String key) => map[key] == 1 || map[key] == true;

    return BleCharacteristicProperties(
      broadcast: flag(BleChannelKey.broadcast),
      read: flag(BleChannelKey.read),
      writeWithoutResponse: flag(BleChannelKey.writeWithoutResponse),
      write: flag(BleChannelKey.write),
      notify: flag(BleChannelKey.notify),
      indicate: flag(BleChannelKey.indicate),
      authenticatedSignedWrites: flag(BleChannelKey.authenticatedSignedWrites),
      extendedProperties: flag(BleChannelKey.extendedProperties),
    );
  }
}

@immutable
final class BleCharacteristic {
  const new({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.instanceId,
    required this.discoveredProperties,
    this.primaryServiceUuid,
  });

  final BleRemoteId remoteId;

  final String? primaryServiceUuid;
  final String serviceUuid;
  final String characteristicUuid;

  final int instanceId;

  /// Properties received during discoverServices.
  ///
  /// Usually use [properties], which resolves against the
  /// latest known services cache.
  final BleCharacteristicProperties discoveredProperties;

  String get uuid => characteristicUuid;

  BleDevice get device => BleDevice(remoteId: remoteId);

  BleCharacteristicProperties get properties =>
      BlePlatform.instance.characteristicProperties(this) ??
      discoveredProperties;

  factory fromMap(Map<dynamic, dynamic> map) {
    final Map<dynamic, dynamic> properties =
        map[BleChannelKey.properties] is Map
        ? map[BleChannelKey.properties] as Map
        : const <dynamic, dynamic>{};

    return BleCharacteristic(
      remoteId: BleRemoteId(map[BleChannelKey.remoteId] as String? ?? ''),
      primaryServiceUuid: map[BleChannelKey.primaryServiceUuid] as String?,
      serviceUuid: map[BleChannelKey.serviceUuid] as String? ?? '',
      characteristicUuid:
          map[BleChannelKey.characteristicUuid] as String? ?? '',
      instanceId: map[BleChannelKey.instanceId] as int? ?? 0,
      discoveredProperties: BleCharacteristicProperties.fromMap(properties),
    );
  }

  Future<void> write(
    List<int> value, {
    bool withoutResponse = false,
    int timeout = 15,
  }) async {
    if (device.isDisconnected) {
      throw const BleException(
        operation: 'writeCharacteristic',
        message: 'device is not connected',
      );
    }

    final Future<BleCharacteristicWriteEvent> responseFuture = BlePlatform
        .instance
        .characteristicWritten
        .firstWhere(
          (event) =>
              event.remoteId == remoteId &&
              event.primaryServiceUuid == primaryServiceUuid &&
              event.serviceUuid == serviceUuid &&
              event.characteristicUuid == characteristicUuid &&
              event.instanceId == instanceId,
        );

    final bool started = await BlePlatform.instance.writeCharacteristic(
      remoteId: remoteId.str,
      primaryServiceUuid: primaryServiceUuid,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      instanceId: instanceId,
      value: value,
      withoutResponse: withoutResponse,
    );

    if (!started) {
      throw const BleException(
        operation: 'writeCharacteristic',
        message: 'native writeCharacteristic returned false',
      );
    }

    final BleCharacteristicWriteEvent response = await responseFuture.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        throw BleException(
          operation: 'writeCharacteristic',
          message: 'Timed out after ${timeout}s',
        );
      },
    );

    if (!response.success) {
      throw BleException(
        operation: 'writeCharacteristic',
        code: response.errorCode,
        message: response.errorString,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleCharacteristic &&
          other.remoteId == remoteId &&
          other.primaryServiceUuid == primaryServiceUuid &&
          other.serviceUuid == serviceUuid &&
          other.characteristicUuid == characteristicUuid &&
          other.instanceId == instanceId;

  @override
  int get hashCode => Object.hash(
    remoteId,
    primaryServiceUuid,
    serviceUuid,
    characteristicUuid,
    instanceId,
  );
}

@immutable
final class BleService {
  const new({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristics,
    this.primaryServiceUuid,
  });

  final BleRemoteId remoteId;
  final String? primaryServiceUuid;
  final String serviceUuid;

  final List<BleCharacteristic> characteristics;

  String get uuid => serviceUuid;

  bool get isPrimary => primaryServiceUuid == null;

  bool get isSecondary => primaryServiceUuid != null;

  factory fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> characteristics =
        map[BleChannelKey.characteristics] as List<dynamic>? ??
        const <dynamic>[];

    return BleService(
      remoteId: BleRemoteId(map[BleChannelKey.remoteId] as String? ?? ''),
      primaryServiceUuid: map[BleChannelKey.primaryServiceUuid] as String?,
      serviceUuid: map[BleChannelKey.serviceUuid] as String? ?? '',
      characteristics: characteristics
          .whereType<Map<String, dynamic>>()
          .map(BleCharacteristic.fromMap)
          .toList(growable: false),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleService &&
          other.remoteId == remoteId &&
          other.primaryServiceUuid == primaryServiceUuid &&
          other.serviceUuid == serviceUuid;

  @override
  int get hashCode => Object.hash(remoteId, primaryServiceUuid, serviceUuid);
}

final class BleDiscoveredServicesEvent {
  const new({
    required this.remoteId,
    required this.services,
    required this.success,
    required this.errorCode,
    required this.errorString,
  });

  final BleRemoteId remoteId;
  final List<BleService> services;

  final bool success;
  final int errorCode;
  final String errorString;

  factory fromMap(Map<dynamic, dynamic> map) {
    final List<dynamic> services =
        map[BleChannelKey.services] as List<dynamic>? ?? const <dynamic>[];

    return BleDiscoveredServicesEvent(
      remoteId: BleRemoteId(map[BleChannelKey.remoteId] as String? ?? ''),
      services: services
          .whereType<Map<String, dynamic>>()
          .map(BleService.fromMap)
          .toList(growable: false),
      success:
          map[BleChannelKey.success] == 1 || map[BleChannelKey.success] == true,
      errorCode: map[BleChannelKey.errorCode] as int? ?? 0,
      errorString: map[BleChannelKey.errorString] as String? ?? '',
    );
  }
}

final class BleCharacteristicWriteEvent {
  const new({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.instanceId,
    required this.success,
    required this.errorCode,
    required this.errorString,
    this.primaryServiceUuid,
  });

  final BleRemoteId remoteId;

  final String? primaryServiceUuid;
  final String serviceUuid;
  final String characteristicUuid;

  final int instanceId;

  final bool success;
  final int errorCode;
  final String errorString;

  factory fromMap(Map<dynamic, dynamic> map) => BleCharacteristicWriteEvent(
    remoteId: BleRemoteId(map[BleChannelKey.remoteId] as String? ?? ''),
    primaryServiceUuid: map[BleChannelKey.primaryServiceUuid] as String?,
    serviceUuid: map[BleChannelKey.serviceUuid] as String? ?? '',
    characteristicUuid: map[BleChannelKey.characteristicUuid] as String? ?? '',
    instanceId: map[BleChannelKey.instanceId] as int? ?? 0,
    success:
        map[BleChannelKey.success] == 1 || map[BleChannelKey.success] == true,
    errorCode: map[BleChannelKey.errorCode] as int? ?? 0,
    errorString: map[BleChannelKey.errorString] as String? ?? '',
  );
}

@immutable
final class BleDevice {
  const new({required this.remoteId, String? platformName, String? advName})
    : _platformName = platformName,
      _advName = advName;

  new fromId(String remoteId, {String? platformName, String? advName})
    : this(
        remoteId: BleRemoteId(remoteId),
        platformName: platformName,
        advName: advName,
      );

  final BleRemoteId remoteId;
  final String? _platformName;
  final String? _advName;

  String get platformName =>
      _platformName ?? BlePlatform.instance.platformName(remoteId);

  String get advName => _advName ?? BlePlatform.instance.advName(remoteId);

  bool get isConnected => BlePlatform.instance.isDeviceConnected(remoteId);

  bool get isDisconnected => !isConnected;

  int get mtuNow => BlePlatform.instance.mtuNow(remoteId);

  List<BleService> get servicesList =>
      BlePlatform.instance.servicesForDevice(remoteId);

  Stream<BleConnectionState> get connectionState {
    final BleConnectionState initial = isConnected
        ? BleConnectionState.connected
        : BleConnectionState.disconnected;

    return BlePlatform.instance.connectionState
        .where((event) => event.remoteId == remoteId)
        .map((event) => event.connectionState)
        .transform(_BleInitialValueTransformer<BleConnectionState>(initial));
  }

  Stream<int> get mtu {
    final int initial = mtuNow;

    return BlePlatform.instance.mtuChanged
        .where((event) => event.remoteId == remoteId)
        .map((event) => event.mtu)
        .transform(_BleInitialValueTransformer<int>(initial));
  }

  Future<void> connect({
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
  }) async {
    if (isConnected) {
      if (mtu != null) {
        await requestMtu(mtu);
      }
      return;
    }

    final Future<BleConnectionEvent> stateFuture = BlePlatform
        .instance
        .connectionState
        .firstWhere((event) => event.remoteId == remoteId);

    final bool changed = await BlePlatform.instance.connect(remoteId.str);

    if (changed) {
      final BleConnectionEvent response = await stateFuture.timeout(
        timeout,
        onTimeout: () {
          throw BleException(
            operation: 'connect',
            message: 'Timed out after ${timeout.inSeconds}s',
          );
        },
      );

      if (response.connectionState == BleConnectionState.disconnected) {
        throw BleException(
          operation: 'connect',
          code: response.disconnectReasonCode,
          message: response.disconnectReasonString ?? 'connection failed',
        );
      }
    }

    if (isConnected && mtu != null) {
      await requestMtu(mtu);
    }
  }

  Future<void> disconnect({int timeout = 35}) async {
    final Future<BleConnectionEvent> responseFuture = BlePlatform
        .instance
        .connectionState
        .firstWhere(
          (event) =>
              event.remoteId == remoteId &&
              event.connectionState == BleConnectionState.disconnected,
        );

    final bool changed = await BlePlatform.instance.disconnect(remoteId.str);

    if (changed) {
      await responseFuture.timeout(
        Duration(seconds: timeout),
        onTimeout: () {
          throw BleException(
            operation: 'disconnect',
            message: 'Timed out after ${timeout}s',
          );
        },
      );
    }
  }

  Future<List<BleService>> discoverServices({int timeout = 15}) async {
    if (isDisconnected) {
      throw const BleException(
        operation: 'discoverServices',
        message: 'device is not connected',
      );
    }

    final Future<BleDiscoveredServicesEvent> responseFuture = BlePlatform
        .instance
        .discoveredServices
        .firstWhere((event) => event.remoteId == remoteId);

    final bool started = await BlePlatform.instance.discoverServices(
      remoteId.str,
    );

    if (!started) {
      throw const BleException(
        operation: 'discoverServices',
        message: 'native discoverServices returned false',
      );
    }

    final BleDiscoveredServicesEvent response = await responseFuture.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        throw BleException(
          operation: 'discoverServices',
          message: 'Timed out after ${timeout}s',
        );
      },
    );

    if (!response.success) {
      throw BleException(
        operation: 'discoverServices',
        code: response.errorCode,
        message: response.errorString,
      );
    }

    return response.services
        .where((service) => service.isPrimary)
        .toList(growable: false);
  }

  Future<int> requestMtu(int desiredMtu, {int timeout = 15}) async {
    if (isDisconnected) {
      throw const BleException(
        operation: 'requestMtu',
        message: 'device is not connected',
      );
    }

    final Future<BleMtuEvent> responseFuture = BlePlatform.instance.mtuChanged
        .firstWhere((event) => event.remoteId == remoteId);

    final bool started = await BlePlatform.instance.requestMtu(
      remoteId: remoteId.str,
      mtu: desiredMtu,
    );

    if (!started) {
      throw const BleException(
        operation: 'requestMtu',
        message: 'native requestMtu returned false',
      );
    }

    final BleMtuEvent response = await responseFuture.timeout(
      Duration(seconds: timeout),
      onTimeout: () {
        throw BleException(
          operation: 'requestMtu',
          message: 'Timed out after ${timeout}s',
        );
      },
    );

    if (!response.success) {
      throw BleException(
        operation: 'requestMtu',
        code: response.errorCode,
        message: response.errorString,
      );
    }

    return response.mtu;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDevice && other.remoteId == remoteId;

  @override
  int get hashCode => remoteId.hashCode;

  @override
  String toString() =>
      'BleDevice{'
      'remoteId: $remoteId, '
      'platformName: $platformName'
      '}';
}

final class _BleInitialValueTransformer<T> extends StreamTransformerBase<T, T> {
  const new(this.initialValue);

  final T initialValue;

  @override
  Stream<T> bind(Stream<T> stream) async* {
    yield initialValue;
    yield* stream;
  }
}
