// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

import Flutter
import Foundation

public final class FlutterSimpleBlePlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private var core: BleCore!

    private init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        core = BleCore { [weak self] method, arguments in
            self?.channel.invokeMethod(method, arguments: arguments)
        }
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: BleChannelContract.channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = FlutterSimpleBlePlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        complete(result) {
            switch call.method {
            case BleChannelContract.Method.isSupported:
                return core.isSupported
            case BleChannelContract.Method.getAdapterState:
                return [BleChannelContract.Key.adapterState: core.adapterState]
            case BleChannelContract.Method.startScan:
                return try core.startScan()
            case BleChannelContract.Method.stopScan:
                return core.stopScan()
            case BleChannelContract.Method.connect:
                return try core.connect(requireRemoteId(call.arguments))
            case BleChannelContract.Method.disconnect:
                return core.disconnect(try requireRemoteId(call.arguments))
            case BleChannelContract.Method.discoverServices:
                return try core.discoverServices(requireRemoteId(call.arguments))
            case BleChannelContract.Method.requestMtu:
                return try core.reportMtu(requireRemoteIdMap(call.arguments))
            case BleChannelContract.Method.writeCharacteristic:
                return try core.write(BleWriteArguments(call.arguments))
            default:
                return FlutterMethodNotImplemented
            }
        }
    }

    private func complete(_ result: FlutterResult, operation: () throws -> Any) {
        do {
            result(try operation())
        } catch let pluginError as BlePluginError {
            result(FlutterError(code: pluginError.code, message: pluginError.message, details: nil))
        } catch {
            result(FlutterError(code: "iosException", message: error.localizedDescription, details: nil))
        }
    }
}
