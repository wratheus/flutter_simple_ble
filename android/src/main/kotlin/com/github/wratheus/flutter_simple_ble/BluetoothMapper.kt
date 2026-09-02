// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

package com.github.wratheus.flutter_simple_ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanRecord
import android.bluetooth.le.ScanResult
import android.os.Build
import android.util.Log
import java.util.Locale
import java.util.UUID

internal object BluetoothMapper {
    fun unauthorizedAdapterState(): AdapterStateMessage = AdapterStateMessage(2)

    fun adapterState(state: Int): AdapterStateMessage {
        val mapped = when (state) {
            BluetoothAdapter.STATE_TURNING_ON -> 3
            BluetoothAdapter.STATE_ON -> 4
            BluetoothAdapter.STATE_TURNING_OFF -> 5
            BluetoothAdapter.STATE_OFF -> 6
            else -> if (state == BluetoothAdapter.ERROR) 1 else 0
        }
        return AdapterStateMessage(mapped)
    }

    @SuppressLint("MissingPermission")
    fun advertisement(result: ScanResult): Map<String, Any> {
        val device = result.device
        val record = result.scanRecord
        val connectable = Build.VERSION.SDK_INT < Build.VERSION_CODES.O || result.isConnectable
        val platformName = safeDeviceName(device)
        val advName = record?.deviceName
        val txPowerLevel = record?.txPowerLevel?.takeUnless { it == Int.MIN_VALUE }
        val appearance = appearance(record)
        val manufacturerData = manufacturerData(record)
        val serviceData = serviceData(record)
        val serviceUuids = record?.serviceUuids?.map { uuid(it.uuid) }.orEmpty()

        return buildMap {
            put(BleChannelContract.Key.REMOTE_ID, device.address)
            platformName?.let { put(BleChannelContract.Key.PLATFORM_NAME, it) }
            if (connectable) put(BleChannelContract.Key.CONNECTABLE, 1)
            advName?.let { put(BleChannelContract.Key.ADV_NAME, it) }
            txPowerLevel?.let { put(BleChannelContract.Key.TX_POWER_LEVEL, it) }
            appearance?.let { put(BleChannelContract.Key.APPEARANCE, it) }
            if (manufacturerData.isNotEmpty()) {
                put(BleChannelContract.Key.MANUFACTURER_DATA, manufacturerData)
            }
            if (serviceData.isNotEmpty()) put(BleChannelContract.Key.SERVICE_DATA, serviceData)
            if (serviceUuids.isNotEmpty()) put(BleChannelContract.Key.SERVICE_UUIDS, serviceUuids)
            if (result.rssi != 0) put(BleChannelContract.Key.RSSI, result.rssi)
        }
    }

    fun connectionState(remoteId: String, state: Int, status: Int): ConnectionMessage =
        ConnectionMessage(
            remoteId = remoteId,
            connectionState = if (state == BluetoothProfile.STATE_CONNECTED) 1 else 0,
            disconnectReasonCode = status,
            disconnectReasonString = statusText(status),
        )

    @SuppressLint("MissingPermission")
    fun discoveredServices(gatt: BluetoothGatt, status: Int): DiscoveredServicesMessage {
        val services = mutableListOf<ServiceMessage>()
        if (status == BluetoothGatt.GATT_SUCCESS) {
            for (service in gatt.services) {
                services += service(gatt, service, null)
                for (included in service.includedServices) {
                    services += service(gatt, included, service)
                }
            }
        }
        return DiscoveredServicesMessage(
            remoteId = gatt.device.address,
            services = services,
            success = status == BluetoothGatt.GATT_SUCCESS,
            errorCode = status,
            errorString = statusText(status),
        )
    }

    fun mtu(remoteId: String, mtu: Int, status: Int): MtuMessage = MtuMessage(
        remoteId = remoteId,
        mtu = mtu,
        success = status == BluetoothGatt.GATT_SUCCESS,
        errorCode = status,
        errorString = statusText(status),
    )

    fun characteristicWritten(
        remoteId: String,
        write: GattConnectionManager.PendingWrite,
        status: Int,
    ): CharacteristicWrittenMessage = CharacteristicWrittenMessage(
        remoteId = remoteId,
        primaryServiceUuid = write.primaryServiceUuid,
        serviceUuid = write.serviceUuid,
        characteristicUuid = write.characteristicUuid,
        instanceId = write.instanceId,
        success = status == BluetoothGatt.GATT_SUCCESS,
        errorCode = status,
        errorString = statusText(status),
    )

    fun uuid(uuid: UUID): String {
        val value = uuid.toString().lowercase(Locale.ROOT)
        return when {
            value.startsWith("0000") && value.endsWith(BASE_UUID_SUFFIX) -> value.substring(4, 8)
            value.endsWith(BASE_UUID_SUFFIX) -> value.substring(0, 8)
            else -> value
        }
    }

    fun parseUuid(value: String): UUID {
        val normalized = when (value.length) {
            4 -> "0000$value$BASE_UUID_SUFFIX"
            8 -> "$value$BASE_UUID_SUFFIX"
            else -> value
        }
        return UUID.fromString(normalized)
    }

    fun statusText(status: Int): String =
        when (status) {
            BluetoothGatt.GATT_SUCCESS -> ""
            GattConnectionManager.USER_CANCELED_ERROR_CODE -> "connection canceled"
            else -> "GATT error $status"
        }

    @SuppressLint("MissingPermission")
    private fun service(
        gatt: BluetoothGatt,
        service: BluetoothGattService,
        primaryService: BluetoothGattService?,
    ): ServiceMessage = ServiceMessage(
        remoteId = gatt.device.address,
        primaryServiceUuid = primaryService?.let { uuid(it.uuid) },
        serviceUuid = uuid(service.uuid),
        characteristics = service.characteristics.map {
            characteristic(gatt, it, primaryService)
        },
    )

    @SuppressLint("MissingPermission")
    private fun characteristic(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        primaryService: BluetoothGattService?,
    ): CharacteristicMessage = CharacteristicMessage(
        remoteId = gatt.device.address,
        primaryServiceUuid = primaryService?.let { uuid(it.uuid) },
        serviceUuid = uuid(characteristic.service.uuid),
        characteristicUuid = uuid(characteristic.uuid),
        instanceId = characteristic.instanceId,
        properties = properties(characteristic.properties),
    )

    private fun properties(value: Int): CharacteristicPropertiesMessage =
        CharacteristicPropertiesMessage(
            broadcast = flag(value, BluetoothGattCharacteristic.PROPERTY_BROADCAST),
            read = flag(value, BluetoothGattCharacteristic.PROPERTY_READ),
            writeWithoutResponse = flag(
                value,
                BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            ),
            write = flag(value, BluetoothGattCharacteristic.PROPERTY_WRITE),
            notify = flag(value, BluetoothGattCharacteristic.PROPERTY_NOTIFY),
            indicate = flag(value, BluetoothGattCharacteristic.PROPERTY_INDICATE),
            authenticatedSignedWrites = flag(
                value,
                BluetoothGattCharacteristic.PROPERTY_SIGNED_WRITE,
            ),
            extendedProperties = flag(
                value,
                BluetoothGattCharacteristic.PROPERTY_EXTENDED_PROPS,
            ),
        )

    private fun appearance(record: ScanRecord?): Int? {
        val bytes = record?.bytes ?: return null

        var index = 0
        while (index < bytes.size) {
            val length = bytes[index].toInt() and 0xff
            if (length == 0) break

            val entryEnd = index + length + 1
            if (entryEnd > bytes.size) break

            val type = bytes[index + 1].toInt() and 0xff
            if (type == APPEARANCE_DATA_TYPE && length == 3) {
                val low = bytes[index + 2].toInt() and 0xff
                val high = bytes[index + 3].toInt() and 0xff
                return high shl 8 or low
            }
            index = entryEnd
        }

        return null
    }

    @SuppressLint("MissingPermission")
    private fun safeDeviceName(device: BluetoothDevice): String? = try {
        device.name
    } catch (exception: SecurityException) {
        Log.w(TAG, "No permission to read the remote device name", exception)
        null
    }

    private fun manufacturerData(record: ScanRecord?): Map<Int, ByteArray> {
        val data = record?.manufacturerSpecificData ?: return emptyMap()
        return buildMap {
            for (index in 0 until data.size()) {
                put(data.keyAt(index), data.valueAt(index))
            }
        }
    }

    private fun serviceData(record: ScanRecord?): Map<String, ByteArray> {
        val data = record?.serviceData ?: return emptyMap()
        return buildMap {
            for ((serviceUuid, value) in data) {
                put(uuid(serviceUuid.uuid), value)
            }
        }
    }

    private fun flag(properties: Int, flag: Int): Int = if (properties and flag == 0) 0 else 1

    private const val APPEARANCE_DATA_TYPE = 0x19
    private const val BASE_UUID_SUFFIX = "-0000-1000-8000-00805f9b34fb"
    private const val TAG = "FlutterSimpleBle"
}
