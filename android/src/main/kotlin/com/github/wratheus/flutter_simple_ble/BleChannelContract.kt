// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

package com.github.wratheus.flutter_simple_ble

internal object BleChannelContract {
    const val CHANNEL_NAME = "flutter_simple_ble"

    object Method {
        const val IS_SUPPORTED = "isSupported"
        const val GET_ADAPTER_STATE = "getAdapterState"
        const val START_SCAN = "startScan"
        const val STOP_SCAN = "stopScan"
        const val CONNECT = "connect"
        const val DISCONNECT = "disconnect"
        const val DISCOVER_SERVICES = "discoverServices"
        const val REQUEST_MTU = "requestMtu"
        const val WRITE_CHARACTERISTIC = "writeCharacteristic"
    }

    object Event {
        const val ADAPTER_STATE_CHANGED = "OnAdapterStateChanged"
        const val SCAN_RESPONSE = "OnScanResponse"
        const val CONNECTION_STATE_CHANGED = "OnConnectionStateChanged"
        const val DISCOVERED_SERVICES = "OnDiscoveredServices"
        const val MTU_CHANGED = "OnMtuChanged"
        const val CHARACTERISTIC_WRITTEN = "OnCharacteristicWritten"
    }

    object Key {
        const val ADAPTER_STATE = "adapter_state"
        const val ADVERTISEMENTS = "advertisements"
        const val REMOTE_ID = "remote_id"
        const val PLATFORM_NAME = "platform_name"
        const val ADV_NAME = "adv_name"
        const val RSSI = "rssi"
        const val CONNECTABLE = "connectable"
        const val TX_POWER_LEVEL = "tx_power_level"
        const val APPEARANCE = "appearance"
        const val MANUFACTURER_DATA = "manufacturer_data"
        const val SERVICE_DATA = "service_data"
        const val SERVICE_UUIDS = "service_uuids"
        const val CONNECTION_STATE = "connection_state"
        const val DISCONNECT_REASON_CODE = "disconnect_reason_code"
        const val DISCONNECT_REASON_STRING = "disconnect_reason_string"
        const val SERVICES = "services"
        const val PRIMARY_SERVICE_UUID = "primary_service_uuid"
        const val SERVICE_UUID = "service_uuid"
        const val CHARACTERISTICS = "characteristics"
        const val CHARACTERISTIC_UUID = "characteristic_uuid"
        const val INSTANCE_ID = "instance_id"
        const val PROPERTIES = "properties"
        const val BROADCAST = "broadcast"
        const val READ = "read"
        const val WRITE_WITHOUT_RESPONSE = "write_without_response"
        const val WRITE = "write"
        const val NOTIFY = "notify"
        const val INDICATE = "indicate"
        const val AUTHENTICATED_SIGNED_WRITES = "authenticated_signed_writes"
        const val EXTENDED_PROPERTIES = "extended_properties"
        const val MTU = "mtu"
        const val VALUE = "value"
        const val WRITE_TYPE = "write_type"
        const val SUCCESS = "success"
        const val ERROR_CODE = "error_code"
        const val ERROR_STRING = "error_string"
    }
}
