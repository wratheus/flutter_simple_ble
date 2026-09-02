package com.github.wratheus.flutter_simple_ble

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FlutterSimpleBlePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var ble: BleCore

    override fun onAttachedToEngine(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        channel = MethodChannel(
            binding.binaryMessenger,
            BleChannelContract.CHANNEL_NAME,
        )

        ble = BleCore()
        ble.initialize(binding.applicationContext) { method, arguments ->
            channel.invokeMethod(method, arguments)
        }
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        ble.handleMethodCall(call, result)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        ble.dispose()
    }
}
