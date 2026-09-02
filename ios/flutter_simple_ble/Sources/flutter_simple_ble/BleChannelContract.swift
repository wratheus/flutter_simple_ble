// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

enum BleChannelContract {
    static let channelName = "flutter_simple_ble"

    enum Method {
        static let isSupported = "isSupported"
        static let getAdapterState = "getAdapterState"
        static let startScan = "startScan"
        static let stopScan = "stopScan"
        static let connect = "connect"
        static let disconnect = "disconnect"
        static let discoverServices = "discoverServices"
        static let requestMtu = "requestMtu"
        static let writeCharacteristic = "writeCharacteristic"
    }

    enum Event {
        static let adapterStateChanged = "OnAdapterStateChanged"
        static let scanResponse = "OnScanResponse"
        static let connectionStateChanged = "OnConnectionStateChanged"
        static let discoveredServices = "OnDiscoveredServices"
        static let mtuChanged = "OnMtuChanged"
        static let characteristicWritten = "OnCharacteristicWritten"
    }

    enum Key {
        static let adapterState = "adapter_state"
        static let advertisements = "advertisements"
        static let remoteId = "remote_id"
        static let platformName = "platform_name"
        static let advName = "adv_name"
        static let rssi = "rssi"
        static let connectable = "connectable"
        static let txPowerLevel = "tx_power_level"
        static let manufacturerData = "manufacturer_data"
        static let serviceData = "service_data"
        static let serviceUuids = "service_uuids"
        static let connectionState = "connection_state"
        static let disconnectReasonCode = "disconnect_reason_code"
        static let disconnectReasonString = "disconnect_reason_string"
        static let services = "services"
        static let primaryServiceUuid = "primary_service_uuid"
        static let serviceUuid = "service_uuid"
        static let characteristics = "characteristics"
        static let characteristicUuid = "characteristic_uuid"
        static let instanceId = "instance_id"
        static let properties = "properties"
        static let broadcast = "broadcast"
        static let read = "read"
        static let writeWithoutResponse = "write_without_response"
        static let write = "write"
        static let notify = "notify"
        static let indicate = "indicate"
        static let authenticatedSignedWrites = "authenticated_signed_writes"
        static let extendedProperties = "extended_properties"
        static let mtu = "mtu"
        static let value = "value"
        static let writeType = "write_type"
        static let success = "success"
        static let errorCode = "error_code"
        static let errorString = "error_string"
    }
}
