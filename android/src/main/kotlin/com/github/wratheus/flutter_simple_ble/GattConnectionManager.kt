package com.github.wratheus.flutter_simple_ble

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothStatusCodes
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat

internal class GattConnectionManager(
    private val context: Context,
    private val emitter: BluetoothEventEmitter,
) {
    data class PendingWrite(
        val primaryServiceUuid: String?,
        val serviceUuid: String,
        val characteristicUuid: String,
        val instanceId: Int,
    )

    private enum class Operation {
        DISCOVER_SERVICES,
        REQUEST_MTU,
        WRITE_CHARACTERISTIC,
    }

    private class Connection(val gatt: BluetoothGatt) {
        var connected = false
        var mtu = 23
        var operation: Operation? = null
        var operationToken = 0L
        var pendingWrite: PendingWrite? = null
    }

    private val handler = Handler(Looper.getMainLooper())
    private val connections = mutableMapOf<String, Connection>()

    private val callback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (!hasConnectPermission()) {
                closeAfterPermissionRevoked(gatt)
                return
            }
            val remoteId = gatt.device.address
            var emittedState = newState
            synchronized(this@GattConnectionManager) {
                val connection = connections[remoteId]
                if (connection == null || connection.gatt !== gatt) {
                    gatt.close()
                    return
                }
                if (status == BluetoothGatt.GATT_SUCCESS &&
                    newState == BluetoothProfile.STATE_CONNECTED
                ) {
                    connection.connected = true
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED ||
                    status != BluetoothGatt.GATT_SUCCESS
                ) {
                    connections.remove(remoteId)
                    gatt.close()
                    emittedState = BluetoothProfile.STATE_DISCONNECTED
                } else {
                    return
                }
            }
            emitter.emit(BluetoothMapper.connectionState(remoteId, emittedState, status))
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (!hasConnectPermission()) {
                closeAfterPermissionRevoked(gatt)
                return
            }
            if (!release(gatt, Operation.DISCOVER_SERVICES)) return
            emitter.emit(BluetoothMapper.discoveredServices(gatt, status))
        }

        @SuppressLint("MissingPermission")
        override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
            if (!hasConnectPermission()) {
                closeAfterPermissionRevoked(gatt)
                return
            }
            val remoteId = gatt.device.address
            synchronized(this@GattConnectionManager) {
                val connection = matchingConnection(gatt)
                if (connection == null || connection.operation != Operation.REQUEST_MTU) return
                if (status == BluetoothGatt.GATT_SUCCESS) connection.mtu = mtu
                connection.operation = null
            }
            emitter.emit(BluetoothMapper.mtu(remoteId, mtu, status))
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicWrite(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            if (!hasConnectPermission()) {
                closeAfterPermissionRevoked(gatt)
                return
            }
            val remoteId = gatt.device.address
            val write: PendingWrite
            synchronized(this@GattConnectionManager) {
                val connection = matchingConnection(gatt)
                val pendingWrite = connection?.pendingWrite
                if (connection?.operation != Operation.WRITE_CHARACTERISTIC || pendingWrite == null) {
                    return
                }
                write = pendingWrite
                connection.pendingWrite = null
                connection.operation = null
            }
            emitter.emit(BluetoothMapper.characteristicWritten(remoteId, write, status))
        }
    }

    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    @Synchronized
    fun connect(adapter: BluetoothAdapter, remoteId: String): Boolean {
        connections[remoteId]?.let { return !it.connected }
        require(BluetoothAdapter.checkBluetoothAddress(remoteId)) {
            "${BleChannelContract.Key.REMOTE_ID} must be a valid Bluetooth address"
        }
        val device = adapter.getRemoteDevice(remoteId)
        // This overload keeps explicit LE transport on every supported API level.
        val gatt = device.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
            ?: throw IllegalArgumentException("connectGatt returned null")
        connections[remoteId] = Connection(gatt)
        return true
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun disconnect(remoteId: String): Boolean {
        val connection = connections[remoteId] ?: return false
        connection.gatt.disconnect()
        if (!connection.connected) {
            connections.remove(remoteId)
            connection.gatt.close()
            emitter.emit(
                BluetoothMapper.connectionState(
                    remoteId,
                    BluetoothProfile.STATE_DISCONNECTED,
                    BluetoothGatt.GATT_SUCCESS,
                ),
            )
        }
        return true
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun discoverServices(remoteId: String): String? {
        val connection = connected(remoteId)
        begin(connection, Operation.DISCOVER_SERVICES)?.let { return it }
        if (!connection.gatt.discoverServices()) {
            connection.operation = null
            return "discoverServices returned false"
        }
        return null
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun requestMtu(remoteId: String, mtu: Int): String? {
        if (mtu !in 23..517) return "mtu must be between 23 and 517"
        val connection = connected(remoteId)
        begin(connection, Operation.REQUEST_MTU)?.let { return it }
        if (!connection.gatt.requestMtu(mtu)) {
            connection.operation = null
            return "requestMtu returned false"
        }
        return null
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun writeCharacteristic(
        remoteId: String,
        primaryServiceUuid: String?,
        serviceUuid: String,
        characteristicUuid: String,
        instanceId: Int,
        value: ByteArray,
        withoutResponse: Boolean,
    ): String? {
        val connection = connected(remoteId)
        begin(connection, Operation.WRITE_CHARACTERISTIC)?.let { return it }

        val characteristic = try {
            findCharacteristic(
                connection.gatt,
                primaryServiceUuid,
                serviceUuid,
                characteristicUuid,
                instanceId,
            )
        } catch (exception: IllegalArgumentException) {
            connection.operation = null
            return exception.message
        }

        val writeType = if (withoutResponse) {
            BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        }
        val requiredProperty = if (withoutResponse) {
            BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE
        } else {
            BluetoothGattCharacteristic.PROPERTY_WRITE
        }
        if (characteristic.properties and requiredProperty == 0) {
            connection.operation = null
            return if (withoutResponse) {
                "characteristic does not support write without response"
            } else {
                "characteristic does not support write"
            }
        }
        val maxLength = connection.mtu - 3
        if (value.size > maxLength) {
            connection.operation = null
            return "value length ${value.size} exceeds maximum $maxLength"
        }

        connection.pendingWrite = PendingWrite(
            primaryServiceUuid,
            serviceUuid,
            characteristicUuid,
            instanceId,
        )
        val startError = startWrite(connection.gatt, characteristic, value, writeType)
        if (startError != null) {
            connection.pendingWrite = null
            connection.operation = null
        }
        return startError
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun closeAll() {
        for (connection in connections.values) {
            try {
                if (hasConnectPermission()) connection.gatt.disconnect()
            } catch (_: SecurityException) {
                // Closing still releases native GATT resources after permission revocation.
            }
            connection.gatt.close()
        }
        connections.clear()
    }

    private fun hasConnectPermission(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED

    @Synchronized
    private fun closeAfterPermissionRevoked(gatt: BluetoothGatt) {
        val iterator = connections.values.iterator()
        while (iterator.hasNext()) {
            if (iterator.next().gatt === gatt) iterator.remove()
        }
        try {
            gatt.close()
        } catch (_: SecurityException) {
            // Permission was already revoked; the connection is no longer retained.
        }
    }

    private fun connected(remoteId: String): Connection {
        val connection = connections[remoteId]
        if (connection == null || !connection.connected) {
            throw IllegalArgumentException("device is disconnected")
        }
        return connection
    }

    private fun begin(connection: Connection, operation: Operation): String? {
        if (connection.operation != null) return BUSY_ERROR
        connection.operation = operation
        val token = ++connection.operationToken
        handler.postDelayed(
            { clearTimedOutOperation(connection, operation, token) },
            OPERATION_TIMEOUT_MILLIS,
        )
        return null
    }

    @Synchronized
    private fun clearTimedOutOperation(
        connection: Connection,
        operation: Operation,
        token: Long,
    ) {
        if (connection.operation == operation && connection.operationToken == token) {
            connection.operation = null
            connection.pendingWrite = null
        }
    }

    @Synchronized
    private fun release(gatt: BluetoothGatt, operation: Operation): Boolean {
        val connection = matchingConnection(gatt)
        if (connection == null || connection.operation != operation) return false
        connection.operation = null
        return true
    }

    @SuppressLint("MissingPermission")
    private fun matchingConnection(gatt: BluetoothGatt): Connection? {
        val connection = connections[gatt.device.address]
        return connection?.takeIf { it.gatt === gatt }
    }

    @SuppressLint("MissingPermission")
    private fun findCharacteristic(
        gatt: BluetoothGatt,
        primaryServiceUuid: String?,
        serviceUuid: String,
        characteristicUuid: String,
        instanceId: Int,
    ): BluetoothGattCharacteristic {
        val service = if (primaryServiceUuid == null) {
            gatt.getService(BluetoothMapper.parseUuid(serviceUuid))
        } else {
            gatt.getService(BluetoothMapper.parseUuid(primaryServiceUuid))
                ?.includedServices
                ?.firstOrNull { it.uuid == BluetoothMapper.parseUuid(serviceUuid) }
        } ?: throw IllegalArgumentException("service not found")

        return service.characteristics.firstOrNull {
            it.uuid == BluetoothMapper.parseUuid(characteristicUuid) && it.instanceId == instanceId
        } ?: throw IllegalArgumentException("characteristic not found")
    }

    @SuppressLint("MissingPermission")
    private fun startWrite(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        writeType: Int,
    ): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val status = gatt.writeCharacteristic(characteristic, value, writeType)
            return if (status == BluetoothStatusCodes.SUCCESS) {
                null
            } else {
                "writeCharacteristic returned $status"
            }
        }
        return startLegacyWrite(gatt, characteristic, value, writeType)
    }

    @Suppress("DEPRECATION")
    @SuppressLint("MissingPermission")
    private fun startLegacyWrite(
        gatt: BluetoothGatt,
        characteristic: BluetoothGattCharacteristic,
        value: ByteArray,
        writeType: Int,
    ): String? {
        if (!characteristic.setValue(value)) return "setValue returned false"
        characteristic.writeType = writeType
        return if (gatt.writeCharacteristic(characteristic)) {
            null
        } else {
            "writeCharacteristic returned false"
        }
    }

    companion object {
        const val BUSY_ERROR = "another GATT operation is in progress"
        private const val OPERATION_TIMEOUT_MILLIS = 20_000L
    }
}
