// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import CoreBluetooth
import Foundation

final class BleCore: NSObject {
    typealias EventCallback = (_ method: String, _ arguments: [String: Any]) -> Void

    private enum Operation {
        case discoverServices
        case writeCharacteristic
    }

    private struct DiscoveryState {
        var pendingServices: Set<ObjectIdentifier>
        var error: Error?
    }

    private let eventCallback: EventCallback
    private var centralManager: CBCentralManager!
    private var knownPeripherals: [UUID: CBPeripheral] = [:]
    private var connectingPeripherals: Set<UUID> = []
    private var connectedPeripherals: Set<UUID> = []
    private var operations: [UUID: Operation] = [:]
    private var discoveries: [UUID: DiscoveryState] = [:]
    private var pendingWrites: [ObjectIdentifier: BlePendingWrite] = [:]

    init(eventCallback: @escaping EventCallback) {
        self.eventCallback = eventCallback
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    var isSupported: Bool {
        centralManager.state != .unsupported
    }

    var adapterState: Int {
        BleMapper.adapterState(centralManager.state)
    }

    func startScan() throws -> Bool {
        guard centralManager.state == .poweredOn else {
            throw BlePluginError(code: "bluetoothOff", message: "Bluetooth must be turned on")
        }
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        return true
    }

    func stopScan() -> Bool {
        let wasScanning = centralManager.isScanning
        centralManager.stopScan()
        return wasScanning
    }

    func connect(_ identifier: UUID) throws -> Bool {
        guard centralManager.state == .poweredOn else {
            throw BlePluginError(code: "bluetoothOff", message: "Bluetooth must be turned on")
        }
        if connectingPeripherals.contains(identifier) { return true }
        if connectedPeripherals.contains(identifier) { return false }
        guard let peripheral = peripheral(identifier) else {
            throw BlePluginError(
                code: "peripheralNotFound",
                message: "Scan for the peripheral before connecting"
            )
        }
        knownPeripherals[identifier] = peripheral
        connectingPeripherals.insert(identifier)
        peripheral.delegate = self
        centralManager.connect(peripheral)
        return true
    }

    func disconnect(_ identifier: UUID) -> Bool {
        guard let peripheral = peripheral(identifier),
              connectingPeripherals.contains(identifier) ||
              connectedPeripherals.contains(identifier) ||
              peripheral.state != .disconnected
        else {
            return false
        }
        centralManager.cancelPeripheralConnection(peripheral)
        return true
    }

    func discoverServices(_ identifier: UUID) throws -> Bool {
        let peripheral = try connectedPeripheral(identifier)
        try requireIdle(identifier)
        operations[identifier] = .discoverServices
        discoveries[identifier] = DiscoveryState(pendingServices: [], error: nil)
        peripheral.discoverServices(nil)
        return true
    }

    func reportMtu(_ identifier: UUID) throws -> Bool {
        emit(BleChannelContract.Event.mtuChanged, BleMapper.mtu(try connectedPeripheral(identifier)))
        return true
    }

    func write(_ arguments: BleWriteArguments) throws -> Bool {
        let peripheral = try connectedPeripheral(arguments.remoteId)
        try requireIdle(arguments.remoteId)
        guard arguments.primaryServiceUuid == nil else {
            throw BlePluginError(
                code: "operationFailed",
                message: "included service writes are not supported on iOS"
            )
        }
        guard let characteristic = locateCharacteristic(peripheral, arguments) else {
            throw BlePluginError(code: "operationFailed", message: "characteristic not found")
        }

        let type: CBCharacteristicWriteType = arguments.withoutResponse ? .withoutResponse : .withResponse
        let requiredProperty: CBCharacteristicProperties = arguments.withoutResponse
            ? .writeWithoutResponse
            : .write
        guard characteristic.properties.contains(requiredProperty) else {
            throw BlePluginError(
                code: "operationFailed",
                message: "characteristic does not support the requested write type"
            )
        }
        guard arguments.value.count <= peripheral.maximumWriteValueLength(for: type) else {
            throw BlePluginError(code: "operationFailed", message: "value exceeds maximum write length")
        }
        if arguments.withoutResponse && !peripheral.canSendWriteWithoutResponse {
            throw BlePluginError(
                code: "operationBusy",
                message: "peripheral is not ready for write without response"
            )
        }

        let pending = BlePendingWrite(
            remoteId: arguments.remoteId,
            primaryServiceUuid: arguments.primaryServiceUuid,
            serviceUuid: arguments.serviceUuid,
            characteristicUuid: arguments.characteristicUuid,
            instanceId: arguments.instanceId
        )
        if arguments.withoutResponse {
            peripheral.writeValue(arguments.value, for: characteristic, type: type)
            emit(
                BleChannelContract.Event.characteristicWritten,
                BleMapper.characteristicWritten(pending, error: nil)
            )
        } else {
            operations[arguments.remoteId] = .writeCharacteristic
            pendingWrites[ObjectIdentifier(characteristic)] = pending
            peripheral.writeValue(arguments.value, for: characteristic, type: type)
        }
        return true
    }

    private func emit(_ method: String, _ arguments: [String: Any]) {
        eventCallback(method, arguments)
    }

    private func peripheral(_ identifier: UUID) -> CBPeripheral? {
        if let known = knownPeripherals[identifier] { return known }
        let retrieved = centralManager.retrievePeripherals(withIdentifiers: [identifier]).first
        if let retrieved { knownPeripherals[identifier] = retrieved }
        return retrieved
    }

    private func connectedPeripheral(_ identifier: UUID) throws -> CBPeripheral {
        guard let peripheral = knownPeripherals[identifier], connectedPeripherals.contains(identifier) else {
            throw BlePluginError(code: "invalidArguments", message: "device is disconnected")
        }
        return peripheral
    }

    private func requireIdle(_ identifier: UUID) throws {
        guard operations[identifier] == nil else {
            throw BlePluginError(code: "operationBusy", message: "another GATT operation is in progress")
        }
    }

    private func locateCharacteristic(
        _ peripheral: CBPeripheral,
        _ arguments: BleWriteArguments
    ) -> CBCharacteristic? {
        let targetService = CBUUID(string: arguments.serviceUuid)
        let targetCharacteristic = CBUUID(string: arguments.characteristicUuid)
        for service in peripheral.services ?? [] where service.uuid == targetService {
            var currentInstance = 0
            for characteristic in service.characteristics ?? []
                where characteristic.uuid == targetCharacteristic {
                if currentInstance == arguments.instanceId { return characteristic }
                currentInstance += 1
            }
        }
        return nil
    }

    private func completeDiscovery(_ peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        guard let state = discoveries[identifier], state.pendingServices.isEmpty else { return }
        discoveries.removeValue(forKey: identifier)
        operations.removeValue(forKey: identifier)
        emit(
            BleChannelContract.Event.discoveredServices,
            BleMapper.discoveredServices(peripheral: peripheral, error: state.error)
        )
    }

    private func clearOperations(_ identifier: UUID) {
        operations.removeValue(forKey: identifier)
        discoveries.removeValue(forKey: identifier)
        pendingWrites = pendingWrites.filter { $0.value.remoteId != identifier }
    }
}

extension BleCore: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        emit(
            BleChannelContract.Event.adapterStateChanged,
            [BleChannelContract.Key.adapterState: BleMapper.adapterState(central.state)]
        )
        guard central.state != .poweredOn else { return }
        central.stopScan()
        for identifier in connectedPeripherals.union(connectingPeripherals) {
            if let peripheral = knownPeripherals[identifier] {
                emit(
                    BleChannelContract.Event.connectionStateChanged,
                    BleMapper.connection(peripheral: peripheral, connected: false, error: nil)
                )
            }
        }
        connectedPeripherals.removeAll()
        connectingPeripherals.removeAll()
        operations.removeAll()
        discoveries.removeAll()
        pendingWrites.removeAll()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        knownPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        emit(
            BleChannelContract.Event.scanResponse,
            [
                BleChannelContract.Key.success: 1,
                BleChannelContract.Key.advertisements: [
                    BleMapper.advertisement(
                        peripheral: peripheral,
                        data: advertisementData,
                        rssi: RSSI
                    ),
                ],
            ]
        )
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectingPeripherals.remove(peripheral.identifier)
        connectedPeripherals.insert(peripheral.identifier)
        knownPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        emit(
            BleChannelContract.Event.connectionStateChanged,
            BleMapper.connection(peripheral: peripheral, connected: true, error: nil)
        )
        emit(BleChannelContract.Event.mtuChanged, BleMapper.mtu(peripheral))
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectingPeripherals.remove(peripheral.identifier)
        clearOperations(peripheral.identifier)
        emit(
            BleChannelContract.Event.connectionStateChanged,
            BleMapper.connection(peripheral: peripheral, connected: false, error: error)
        )
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        connectingPeripherals.remove(peripheral.identifier)
        connectedPeripherals.remove(peripheral.identifier)
        clearOperations(peripheral.identifier)
        emit(
            BleChannelContract.Event.connectionStateChanged,
            BleMapper.connection(peripheral: peripheral, connected: false, error: error)
        )
    }
}

extension BleCore: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let identifier = peripheral.identifier
        guard operations[identifier] == .discoverServices else { return }
        var state = discoveries[identifier] ?? DiscoveryState(pendingServices: [], error: nil)
        if state.error == nil { state.error = error }
        let services = peripheral.services ?? []
        state.pendingServices = Set(services.map(ObjectIdentifier.init))
        discoveries[identifier] = state
        if services.isEmpty {
            completeDiscovery(peripheral)
        } else {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let identifier = peripheral.identifier
        guard var state = discoveries[identifier] else { return }
        if state.error == nil { state.error = error }
        state.pendingServices.remove(ObjectIdentifier(service))
        discoveries[identifier] = state
        completeDiscovery(peripheral)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let pending = pendingWrites.removeValue(forKey: ObjectIdentifier(characteristic)) else {
            return
        }
        operations.removeValue(forKey: peripheral.identifier)
        emit(
            BleChannelContract.Event.characteristicWritten,
            BleMapper.characteristicWritten(pending, error: error)
        )
    }
}
