// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

package com.github.wratheus.flutter_simple_ble

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class FlutterSimpleBlePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private lateinit var ble: BleCore
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val pendingPermissionCalls = mutableListOf<PendingPermissionCall>()
    private var permissionRequestInFlight = false
    private var requestedPermissions = emptySet<String>()

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
        if (missingPermissions(call.method).isEmpty()) {
            ble.handleMethodCall(call, result)
            return
        }

        pendingPermissionCalls += PendingPermissionCall(call, result)
        requestPermissionsForPendingCalls()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        failPendingPermissionCalls("Bluetooth permissions require a foreground Android activity")
        ble.dispose()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        requestPermissionsForPendingCalls()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachFromActivity()
        permissionRequestInFlight = false
        requestedPermissions = emptySet()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachFromActivity()
        failPendingPermissionCalls("Bluetooth permissions require a foreground Android activity")
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE || !permissionRequestInFlight) return false

        permissionRequestInFlight = false
        val completedRequest = requestedPermissions
        requestedPermissions = emptySet()

        val deniedCalls = mutableListOf<PendingPermissionCall>()
        val iterator = pendingPermissionCalls.iterator()
        while (iterator.hasNext()) {
            val pendingCall = iterator.next()
            if (missingPermissions(pendingCall.call.method).any(completedRequest::contains)) {
                iterator.remove()
                deniedCalls += pendingCall
            }
        }
        deniedCalls.forEach { pendingCall ->
            pendingCall.result.error(
                "permissionDenied",
                "Bluetooth permission was denied",
                null,
            )
        }

        ble.emitAdapterState()
        requestPermissionsForPendingCalls()
        return true
    }

    private fun requestPermissionsForPendingCalls() {
        if (permissionRequestInFlight) return

        val readyCalls = mutableListOf<PendingPermissionCall>()
        val iterator = pendingPermissionCalls.iterator()
        while (iterator.hasNext()) {
            val pendingCall = iterator.next()
            if (missingPermissions(pendingCall.call.method).isEmpty()) {
                iterator.remove()
                readyCalls += pendingCall
            }
        }
        readyCalls.forEach { pendingCall -> ble.handleMethodCall(pendingCall.call, pendingCall.result) }

        if (pendingPermissionCalls.isEmpty()) return

        val currentActivity = activity
        if (currentActivity == null) {
            failPendingPermissionCalls("Bluetooth permissions require a foreground Android activity")
            return
        }

        requestedPermissions = pendingPermissionCalls
            .flatMapTo(linkedSetOf()) { pendingCall -> missingPermissions(pendingCall.call.method) }
        if (requestedPermissions.isEmpty()) return

        permissionRequestInFlight = true
        ActivityCompat.requestPermissions(
            currentActivity,
            requestedPermissions.toTypedArray(),
            PERMISSION_REQUEST_CODE,
        )
    }

    private fun missingPermissions(method: String): Set<String> {
        val currentActivity = activity ?: return requiredPermissions(method)
        return requiredPermissions(method).filterTo(linkedSetOf()) { permission ->
            ContextCompat.checkSelfPermission(currentActivity, permission) !=
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requiredPermissions(method: String): Set<String> = when (method) {
        BleChannelContract.Method.START_SCAN -> scanPermissions()
        BleChannelContract.Method.CONNECT,
        BleChannelContract.Method.DISCONNECT,
        BleChannelContract.Method.DISCOVER_SERVICES,
        BleChannelContract.Method.REQUEST_MTU,
        BleChannelContract.Method.WRITE_CHARACTERISTIC,
        -> connectPermissions()
        else -> emptySet()
    }

    private fun scanPermissions(): Set<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        linkedSetOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
    } else {
        setOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private fun connectPermissions(): Set<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        setOf(Manifest.permission.BLUETOOTH_CONNECT)
    } else {
        emptySet()
    }

    private fun detachFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
    }

    private fun failPendingPermissionCalls(message: String) {
        val pendingCalls = pendingPermissionCalls.toList()
        pendingPermissionCalls.clear()
        pendingCalls.forEach { pendingCall ->
            pendingCall.result.error("permissionDenied", message, null)
        }
    }

    private data class PendingPermissionCall(
        val call: MethodCall,
        val result: MethodChannel.Result,
    )

    private companion object {
        const val PERMISSION_REQUEST_CODE = 18733
    }
}
