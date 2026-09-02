import 'dart:typed_data';

abstract final class BleChannelContract {
  static const String channelName = 'flutter_simple_ble';
}

abstract final class BleChannelMethod {
  static const String isSupported = 'isSupported';
  static const String getAdapterState = 'getAdapterState';
  static const String startScan = 'startScan';
  static const String stopScan = 'stopScan';
  static const String connect = 'connect';
  static const String disconnect = 'disconnect';
  static const String discoverServices = 'discoverServices';
  static const String requestMtu = 'requestMtu';
  static const String writeCharacteristic = 'writeCharacteristic';
}

abstract final class BleChannelEvent {
  static const String adapterStateChanged = 'OnAdapterStateChanged';
  static const String scanResponse = 'OnScanResponse';
  static const String connectionStateChanged = 'OnConnectionStateChanged';
  static const String discoveredServices = 'OnDiscoveredServices';
  static const String mtuChanged = 'OnMtuChanged';
  static const String characteristicWritten = 'OnCharacteristicWritten';
}

abstract final class BleChannelKey {
  static const String adapterState = 'adapter_state';
  static const String advertisements = 'advertisements';
  static const String remoteId = 'remote_id';
  static const String platformName = 'platform_name';
  static const String advName = 'adv_name';
  static const String rssi = 'rssi';
  static const String connectable = 'connectable';
  static const String txPowerLevel = 'tx_power_level';
  static const String connectionState = 'connection_state';
  static const String disconnectReasonCode = 'disconnect_reason_code';
  static const String disconnectReasonString = 'disconnect_reason_string';
  static const String services = 'services';
  static const String primaryServiceUuid = 'primary_service_uuid';
  static const String serviceUuid = 'service_uuid';
  static const String characteristics = 'characteristics';
  static const String characteristicUuid = 'characteristic_uuid';
  static const String instanceId = 'instance_id';
  static const String properties = 'properties';
  static const String broadcast = 'broadcast';
  static const String read = 'read';
  static const String writeWithoutResponse = 'write_without_response';
  static const String write = 'write';
  static const String notify = 'notify';
  static const String indicate = 'indicate';
  static const String authenticatedSignedWrites = 'authenticated_signed_writes';
  static const String extendedProperties = 'extended_properties';
  static const String mtu = 'mtu';
  static const String value = 'value';
  static const String writeType = 'write_type';
  static const String success = 'success';
  static const String errorCode = 'error_code';
  static const String errorString = 'error_string';
}

final class RequestMtuRequest {
  const new({required this.remoteId, required this.mtu});

  final String remoteId;
  final int mtu;

  Map<String, Object> toMap() => <String, Object>{
    BleChannelKey.remoteId: remoteId,
    BleChannelKey.mtu: mtu,
  };
}

final class WriteCharacteristicRequest {
  const new({
    required this.remoteId,
    required this.serviceUuid,
    required this.characteristicUuid,
    required this.instanceId,
    required this.value,
    required this.withoutResponse,
    this.primaryServiceUuid,
  });

  final String remoteId;
  final String? primaryServiceUuid;
  final String serviceUuid;
  final String characteristicUuid;
  final int instanceId;
  final List<int> value;
  final bool withoutResponse;

  Map<String, Object?> toMap() => <String, Object?>{
    BleChannelKey.remoteId: remoteId,
    BleChannelKey.primaryServiceUuid: primaryServiceUuid,
    BleChannelKey.serviceUuid: serviceUuid,
    BleChannelKey.characteristicUuid: characteristicUuid,
    BleChannelKey.instanceId: instanceId,
    BleChannelKey.value: Uint8List.fromList(value),
    BleChannelKey.writeType: withoutResponse ? 1 : 0,
  };
}
