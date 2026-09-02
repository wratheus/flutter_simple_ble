package com.github.wratheus.flutter_simple_ble

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanResult
import android.os.Build
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
    fun advertisement(result: ScanResult): AdvertisementMessage {
        val record = result.scanRecord
        val advertisedName = record?.deviceName
        return AdvertisementMessage(
            remoteId = result.device.address,
            rssi = result.rssi,
            connectable = if (
                Build.VERSION.SDK_INT < Build.VERSION_CODES.O || result.isConnectable
            ) 1 else 0,
            advName = advertisedName,
            platformName = advertisedName ?: result.device.name,
            txPowerLevel = record?.txPowerLevel?.takeUnless { it == Int.MIN_VALUE },
        )
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
        if (status == BluetoothGatt.GATT_SUCCESS) "" else "GATT error $status"

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

    private fun flag(properties: Int, flag: Int): Int = if (properties and flag == 0) 0 else 1

    private const val BASE_UUID_SUFFIX = "-0000-1000-8000-00805f9b34fb"
}
