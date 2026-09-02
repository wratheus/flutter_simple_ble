// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import CoreBluetooth
import Flutter
import Foundation

enum BleMapper {
    static func adapterState(_ state: CBManagerState) -> Int {
        switch state {
        case .unsupported: return 1
        case .unauthorized: return 2
        case .poweredOn: return 4
        case .poweredOff: return 6
        case .unknown, .resetting: return 0
        @unknown default: return 0
        }
    }

    static func advertisement(
        peripheral: CBPeripheral,
        data: [String: Any],
        rssi: NSNumber
    ) -> [String: Any] {
        var result: [String: Any] = [
            BleChannelContract.Key.remoteId: peripheral.identifier.uuidString,
            BleChannelContract.Key.rssi: rssi.intValue,
        ]
        if let name = peripheral.name { result[BleChannelContract.Key.platformName] = name }
        if let name = data[CBAdvertisementDataLocalNameKey] as? String {
            result[BleChannelContract.Key.advName] = name
        }
        if let connectable = data[CBAdvertisementDataIsConnectable] as? NSNumber,
           connectable.boolValue {
            result[BleChannelContract.Key.connectable] = 1
        }
        if let txPower = data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber {
            result[BleChannelContract.Key.txPowerLevel] = txPower.intValue
        }
        if let manufacturer = data[CBAdvertisementDataManufacturerDataKey] as? Data,
           manufacturer.count >= 2 {
            let bytes = [UInt8](manufacturer)
            let companyId = Int(bytes[0]) | Int(bytes[1]) << 8
            result[BleChannelContract.Key.manufacturerData] = [
                companyId: FlutterStandardTypedData(bytes: Data(bytes.dropFirst(2))),
            ]
        }
        if let nativeServiceData = data[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] {
            result[BleChannelContract.Key.serviceData] = Dictionary(
                uniqueKeysWithValues: nativeServiceData.map {
                    (uuid($0.key), FlutterStandardTypedData(bytes: $0.value))
                }
            )
        }
        if let serviceUuids = data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            result[BleChannelContract.Key.serviceUuids] = serviceUuids.map(uuid)
        }
        return result
    }

    static func connection(
        peripheral: CBPeripheral,
        connected: Bool,
        error: Error?
    ) -> [String: Any] {
        let nativeError = error as NSError?
        return [
            BleChannelContract.Key.remoteId: peripheral.identifier.uuidString,
            BleChannelContract.Key.connectionState: connected ? 1 : 0,
            BleChannelContract.Key.disconnectReasonCode: nativeError?.code ?? 0,
            BleChannelContract.Key.disconnectReasonString: nativeError?.localizedDescription ?? "",
        ]
    }

    static func discoveredServices(
        peripheral: CBPeripheral,
        error: Error?
    ) -> [String: Any] {
        let nativeError = error as NSError?
        return [
            BleChannelContract.Key.remoteId: peripheral.identifier.uuidString,
            BleChannelContract.Key.services: (peripheral.services ?? []).map {
                service(peripheral: peripheral, service: $0)
            },
            BleChannelContract.Key.success: nativeError == nil ? 1 : 0,
            BleChannelContract.Key.errorCode: nativeError?.code ?? 0,
            BleChannelContract.Key.errorString: nativeError?.localizedDescription ?? "",
        ]
    }

    static func mtu(_ peripheral: CBPeripheral) -> [String: Any] {
        [
            BleChannelContract.Key.remoteId: peripheral.identifier.uuidString,
            BleChannelContract.Key.mtu: peripheral.maximumWriteValueLength(for: .withResponse) + 3,
            BleChannelContract.Key.success: 1,
            BleChannelContract.Key.errorCode: 0,
            BleChannelContract.Key.errorString: "",
        ]
    }

    static func characteristicWritten(
        _ pending: BlePendingWrite,
        error: Error?
    ) -> [String: Any] {
        let nativeError = error as NSError?
        var result: [String: Any] = [
            BleChannelContract.Key.remoteId: pending.remoteId.uuidString,
            BleChannelContract.Key.serviceUuid: pending.serviceUuid,
            BleChannelContract.Key.characteristicUuid: pending.characteristicUuid,
            BleChannelContract.Key.instanceId: pending.instanceId,
            BleChannelContract.Key.success: nativeError == nil ? 1 : 0,
            BleChannelContract.Key.errorCode: nativeError?.code ?? 0,
            BleChannelContract.Key.errorString: nativeError?.localizedDescription ?? "",
        ]
        if let primaryServiceUuid = pending.primaryServiceUuid {
            result[BleChannelContract.Key.primaryServiceUuid] = primaryServiceUuid
        }
        return result
    }

    static func uuid(_ value: CBUUID) -> String {
        value.uuidString.lowercased()
    }

    private static func service(peripheral: CBPeripheral, service: CBService) -> [String: Any] {
        [
            BleChannelContract.Key.remoteId: peripheral.identifier.uuidString,
            BleChannelContract.Key.serviceUuid: uuid(service.uuid),
            BleChannelContract.Key.characteristics: (service.characteristics ?? []).map {
                characteristic(peripheral: peripheral, service: service, characteristic: $0)
            },
        ]
    }

    private static func characteristic(
        peripheral: CBPeripheral,
        service: CBService,
        characteristic: CBCharacteristic
    ) -> [String: Any] {
        [
            BleChannelContract.Key.remoteId: peripheral.identifier.uuidString,
            BleChannelContract.Key.serviceUuid: uuid(service.uuid),
            BleChannelContract.Key.characteristicUuid: uuid(characteristic.uuid),
            BleChannelContract.Key.instanceId: instanceId(characteristic, in: service),
            BleChannelContract.Key.properties: properties(characteristic.properties),
        ]
    }

    private static func instanceId(_ target: CBCharacteristic, in service: CBService) -> Int {
        var instance = 0
        for characteristic in service.characteristics ?? [] where characteristic.uuid == target.uuid {
            if characteristic === target { return instance }
            instance += 1
        }
        return 0
    }

    private static func properties(_ value: CBCharacteristicProperties) -> [String: Any] {
        [
            BleChannelContract.Key.broadcast: value.contains(.broadcast) ? 1 : 0,
            BleChannelContract.Key.read: value.contains(.read) ? 1 : 0,
            BleChannelContract.Key.writeWithoutResponse: value.contains(.writeWithoutResponse) ? 1 : 0,
            BleChannelContract.Key.write: value.contains(.write) ? 1 : 0,
            BleChannelContract.Key.notify: value.contains(.notify) ? 1 : 0,
            BleChannelContract.Key.indicate: value.contains(.indicate) ? 1 : 0,
            BleChannelContract.Key.authenticatedSignedWrites: value.contains(.authenticatedSignedWrites) ? 1 : 0,
            BleChannelContract.Key.extendedProperties: value.contains(.extendedProperties) ? 1 : 0,
        ]
    }
}
