// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

package com.github.wratheus.flutter_simple_ble

internal data class RequestMtuArgs(
    val remoteId: String,
    val mtu: Int,
) {
    companion object {
        fun fromMap(value: Any?): RequestMtuArgs {
            val map = requireMap(value)
            return RequestMtuArgs(
                remoteId = requireString(map, BleChannelContract.Key.REMOTE_ID),
                mtu = requireInt(map, BleChannelContract.Key.MTU),
            )
        }
    }
}

internal data class WriteCharacteristicArgs(
    val remoteId: String,
    val primaryServiceUuid: String?,
    val serviceUuid: String,
    val characteristicUuid: String,
    val instanceId: Int,
    val value: ByteArray,
    val withoutResponse: Boolean,
) {
    companion object {
        fun fromMap(value: Any?): WriteCharacteristicArgs {
            val map = requireMap(value)
            val primaryServiceUuid = map[BleChannelContract.Key.PRIMARY_SERVICE_UUID]
            require(primaryServiceUuid == null || primaryServiceUuid is String) {
                "${BleChannelContract.Key.PRIMARY_SERVICE_UUID} must be a string or null"
            }
            if (primaryServiceUuid is String) {
                require(primaryServiceUuid.isNotBlank()) {
                    "${BleChannelContract.Key.PRIMARY_SERVICE_UUID} must not be blank"
                }
            }
            val bytes = map[BleChannelContract.Key.VALUE]
            require(bytes is ByteArray) {
                "${BleChannelContract.Key.VALUE} must be a byte array"
            }
            val writeType = requireInt(map, BleChannelContract.Key.WRITE_TYPE)
            require(writeType == 0 || writeType == 1) {
                "${BleChannelContract.Key.WRITE_TYPE} must be 0 or 1"
            }

            return WriteCharacteristicArgs(
                remoteId = requireString(map, BleChannelContract.Key.REMOTE_ID),
                primaryServiceUuid = primaryServiceUuid,
                serviceUuid = requireString(map, BleChannelContract.Key.SERVICE_UUID),
                characteristicUuid = requireString(
                    map,
                    BleChannelContract.Key.CHARACTERISTIC_UUID,
                ),
                instanceId = requireInt(map, BleChannelContract.Key.INSTANCE_ID),
                value = bytes,
                withoutResponse = writeType != 0,
            )
        }
    }
}

internal interface BleChannelMessage {
    fun toMap(): Map<String, Any>
}

internal interface BleChannelEventMessage : BleChannelMessage {
    val event: String
}

internal data class AdapterStateMessage(val adapterState: Int) : BleChannelEventMessage {
    override val event: String = BleChannelContract.Event.ADAPTER_STATE_CHANGED

    override fun toMap(): Map<String, Any> = mapOf(
        BleChannelContract.Key.ADAPTER_STATE to adapterState,
    )
}

internal data class ScanResponseMessage(
    val success: Boolean,
    val advertisements: List<Map<String, Any>>,
    val errorCode: Int? = null,
    val errorString: String? = null,
) : BleChannelEventMessage {
    override val event: String = BleChannelContract.Event.SCAN_RESPONSE

    override fun toMap(): Map<String, Any> = buildMap {
        put(BleChannelContract.Key.SUCCESS, if (success) 1 else 0)
        put(BleChannelContract.Key.ADVERTISEMENTS, advertisements)
        errorCode?.let { put(BleChannelContract.Key.ERROR_CODE, it) }
        errorString?.let { put(BleChannelContract.Key.ERROR_STRING, it) }
    }
}

internal data class ConnectionMessage(
    val remoteId: String,
    val connectionState: Int,
    val disconnectReasonCode: Int,
    val disconnectReasonString: String,
) : BleChannelEventMessage {
    override val event: String = BleChannelContract.Event.CONNECTION_STATE_CHANGED

    override fun toMap(): Map<String, Any> = mapOf(
        BleChannelContract.Key.REMOTE_ID to remoteId,
        BleChannelContract.Key.CONNECTION_STATE to connectionState,
        BleChannelContract.Key.DISCONNECT_REASON_CODE to disconnectReasonCode,
        BleChannelContract.Key.DISCONNECT_REASON_STRING to disconnectReasonString,
    )
}

internal data class CharacteristicPropertiesMessage(
    val broadcast: Int,
    val read: Int,
    val writeWithoutResponse: Int,
    val write: Int,
    val notify: Int,
    val indicate: Int,
    val authenticatedSignedWrites: Int,
    val extendedProperties: Int,
) : BleChannelMessage {
    override fun toMap(): Map<String, Any> = mapOf(
        BleChannelContract.Key.BROADCAST to broadcast,
        BleChannelContract.Key.READ to read,
        BleChannelContract.Key.WRITE_WITHOUT_RESPONSE to writeWithoutResponse,
        BleChannelContract.Key.WRITE to write,
        BleChannelContract.Key.NOTIFY to notify,
        BleChannelContract.Key.INDICATE to indicate,
        BleChannelContract.Key.AUTHENTICATED_SIGNED_WRITES to authenticatedSignedWrites,
        BleChannelContract.Key.EXTENDED_PROPERTIES to extendedProperties,
    )
}

internal data class CharacteristicMessage(
    val remoteId: String,
    val primaryServiceUuid: String?,
    val serviceUuid: String,
    val characteristicUuid: String,
    val instanceId: Int,
    val properties: CharacteristicPropertiesMessage,
) : BleChannelMessage {
    override fun toMap(): Map<String, Any> = buildMap {
        put(BleChannelContract.Key.REMOTE_ID, remoteId)
        primaryServiceUuid?.let { put(BleChannelContract.Key.PRIMARY_SERVICE_UUID, it) }
        put(BleChannelContract.Key.SERVICE_UUID, serviceUuid)
        put(BleChannelContract.Key.CHARACTERISTIC_UUID, characteristicUuid)
        put(BleChannelContract.Key.INSTANCE_ID, instanceId)
        put(BleChannelContract.Key.PROPERTIES, properties.toMap())
    }
}

internal data class ServiceMessage(
    val remoteId: String,
    val primaryServiceUuid: String?,
    val serviceUuid: String,
    val characteristics: List<CharacteristicMessage>,
) : BleChannelMessage {
    override fun toMap(): Map<String, Any> = buildMap {
        put(BleChannelContract.Key.REMOTE_ID, remoteId)
        primaryServiceUuid?.let { put(BleChannelContract.Key.PRIMARY_SERVICE_UUID, it) }
        put(BleChannelContract.Key.SERVICE_UUID, serviceUuid)
        put(BleChannelContract.Key.CHARACTERISTICS, characteristics.map { it.toMap() })
    }
}

internal data class DiscoveredServicesMessage(
    val remoteId: String,
    val services: List<ServiceMessage>,
    val success: Boolean,
    val errorCode: Int,
    val errorString: String,
) : BleChannelEventMessage {
    override val event: String = BleChannelContract.Event.DISCOVERED_SERVICES

    override fun toMap(): Map<String, Any> = resultMap(success, errorCode, errorString).apply {
        put(BleChannelContract.Key.REMOTE_ID, remoteId)
        put(BleChannelContract.Key.SERVICES, services.map { it.toMap() })
    }
}

internal data class MtuMessage(
    val remoteId: String,
    val mtu: Int,
    val success: Boolean,
    val errorCode: Int,
    val errorString: String,
) : BleChannelEventMessage {
    override val event: String = BleChannelContract.Event.MTU_CHANGED

    override fun toMap(): Map<String, Any> = resultMap(success, errorCode, errorString).apply {
        put(BleChannelContract.Key.REMOTE_ID, remoteId)
        put(BleChannelContract.Key.MTU, mtu)
    }
}

internal data class CharacteristicWrittenMessage(
    val remoteId: String,
    val primaryServiceUuid: String?,
    val serviceUuid: String,
    val characteristicUuid: String,
    val instanceId: Int,
    val success: Boolean,
    val errorCode: Int,
    val errorString: String,
) : BleChannelEventMessage {
    override val event: String = BleChannelContract.Event.CHARACTERISTIC_WRITTEN

    override fun toMap(): Map<String, Any> = resultMap(success, errorCode, errorString).apply {
        put(BleChannelContract.Key.REMOTE_ID, remoteId)
        primaryServiceUuid?.let { put(BleChannelContract.Key.PRIMARY_SERVICE_UUID, it) }
        put(BleChannelContract.Key.SERVICE_UUID, serviceUuid)
        put(BleChannelContract.Key.CHARACTERISTIC_UUID, characteristicUuid)
        put(BleChannelContract.Key.INSTANCE_ID, instanceId)
    }
}

private fun resultMap(success: Boolean, code: Int, message: String): MutableMap<String, Any> =
    mutableMapOf(
        BleChannelContract.Key.SUCCESS to if (success) 1 else 0,
        BleChannelContract.Key.ERROR_CODE to code,
        BleChannelContract.Key.ERROR_STRING to message,
    )

private fun requireMap(value: Any?): Map<*, *> = value as? Map<*, *>
    ?: throw IllegalArgumentException("arguments must be a map")

private fun requireString(map: Map<*, *>, key: String): String {
    val value = map[key]
    require(value is String && value.isNotBlank()) { "$key must be a non-empty string" }
    return value
}

private fun requireInt(map: Map<*, *>, key: String): Int {
    val value = map[key]
    require(value is Int) { "$key must be an integer" }
    return value
}
