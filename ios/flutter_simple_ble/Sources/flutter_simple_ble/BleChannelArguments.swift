// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import Flutter
import Foundation

struct BlePluginError: Error {
    let code: String
    let message: String
}

struct BleWriteArguments {
    let remoteId: UUID
    let primaryServiceUuid: String?
    let serviceUuid: String
    let characteristicUuid: String
    let instanceId: Int
    let value: Data
    let withoutResponse: Bool

    init(_ value: Any?) throws {
        guard let map = value as? [String: Any],
              let remoteIdString = map[BleChannelContract.Key.remoteId] as? String,
              let remoteId = UUID(uuidString: remoteIdString),
              let serviceUuid = map[BleChannelContract.Key.serviceUuid] as? String,
              let characteristicUuid = map[BleChannelContract.Key.characteristicUuid] as? String,
              let instanceId = map[BleChannelContract.Key.instanceId] as? Int,
              let writeType = map[BleChannelContract.Key.writeType] as? Int,
              let bytes = map[BleChannelContract.Key.value] as? FlutterStandardTypedData,
              writeType == 0 || writeType == 1
        else {
            throw BlePluginError(code: "invalidArguments", message: "invalid write arguments")
        }
        self.remoteId = remoteId
        primaryServiceUuid = map[BleChannelContract.Key.primaryServiceUuid] as? String
        self.serviceUuid = serviceUuid
        self.characteristicUuid = characteristicUuid
        self.instanceId = instanceId
        self.value = bytes.data
        withoutResponse = writeType == 1
    }
}

struct BlePendingWrite {
    let remoteId: UUID
    let primaryServiceUuid: String?
    let serviceUuid: String
    let characteristicUuid: String
    let instanceId: Int
}

func requireRemoteId(_ value: Any?) throws -> UUID {
    guard let string = value as? String, let identifier = UUID(uuidString: string) else {
        throw BlePluginError(code: "invalidArguments", message: "remote_id must be a valid UUID")
    }
    return identifier
}

func requireRemoteIdMap(_ value: Any?) throws -> UUID {
    guard let map = value as? [String: Any] else {
        throw BlePluginError(code: "invalidArguments", message: "arguments must be a map")
    }
    return try requireRemoteId(map[BleChannelContract.Key.remoteId])
}
