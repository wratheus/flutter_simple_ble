// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

package com.github.wratheus.flutter_simple_ble

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.atomic.AtomicBoolean

internal class BleCore {
    fun interface EventCallback {
        fun emit(method: String, arguments: Any?)
    }

    private var context: Context? = null
    private var adapter: BluetoothAdapter? = null
    private var emitter: BluetoothEventEmitter? = null
    private var scanner: BleScanner? = null
    private var connections: GattConnectionManager? = null
    private var bleSupported = false
    private var receiverRegistered = false

    private val adapterStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(receiverContext: Context, intent: Intent) {
            if (intent.action != BluetoothAdapter.ACTION_STATE_CHANGED) return

            val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
            if (state == BluetoothAdapter.STATE_TURNING_OFF || state == BluetoothAdapter.STATE_OFF) {
                scanner?.stopSilently()
                connections?.closeAll()
            }
            emitter?.adapterStateChanged(state)
        }
    }

    @Synchronized
    fun initialize(initializationContext: Context, eventCallback: EventCallback) {
        emitter?.let {
            it.setCallback(eventCallback)
            return
        }

        val applicationContext = initializationContext.applicationContext
        val bluetoothAdapter = applicationContext
            .getSystemService(BluetoothManager::class.java)
            ?.adapter

        context = applicationContext
        adapter = bluetoothAdapter
        bleSupported = bluetoothAdapter != null && applicationContext.packageManager.hasSystemFeature(
            PackageManager.FEATURE_BLUETOOTH_LE,
        )
        val eventEmitter = BluetoothEventEmitter(eventCallback)
        emitter = eventEmitter
        scanner = BleScanner(applicationContext, eventEmitter)
        connections = GattConnectionManager(applicationContext, eventEmitter)

        ContextCompat.registerReceiver(
            applicationContext,
            adapterStateReceiver,
            IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        receiverRegistered = true
    }

    @Synchronized
    fun dispose() {
        val currentContext = context ?: return
        try {
            scanner?.stopSilently()
            connections?.closeAll()
            if (receiverRegistered) {
                try {
                    currentContext.unregisterReceiver(adapterStateReceiver)
                } catch (_: IllegalArgumentException) {
                    // The receiver may already have been removed during process teardown.
                }
            }
        } finally {
            receiverRegistered = false
            emitter?.clear()
            connections = null
            scanner = null
            emitter = null
            adapter = null
            bleSupported = false
            context = null
        }
    }

    fun handleMethodCall(call: MethodCall, result: Result) {
        val onceResult = OnceResult(result)
        try {
            if (context == null) {
                onceResult.error("notInitialized", "Bluetooth core is not initialized", null)
                return
            }

            when (call.method) {
                BleChannelContract.Method.IS_SUPPORTED -> onceResult.success(bleSupported)
                BleChannelContract.Method.GET_ADAPTER_STATE -> getAdapterState(onceResult)
                BleChannelContract.Method.START_SCAN -> startScan(onceResult)
                BleChannelContract.Method.STOP_SCAN -> stopScan(onceResult)
                BleChannelContract.Method.CONNECT -> connect(call.arguments, onceResult)
                BleChannelContract.Method.DISCONNECT -> disconnect(call.arguments, onceResult)
                BleChannelContract.Method.DISCOVER_SERVICES -> discoverServices(call.arguments, onceResult)
                BleChannelContract.Method.REQUEST_MTU -> requestMtu(call.arguments, onceResult)
                BleChannelContract.Method.WRITE_CHARACTERISTIC -> {
                    writeCharacteristic(call.arguments, onceResult)
                }
                else -> onceResult.notImplemented()
            }
        } catch (_: SecurityException) {
            onceResult.error("permissionDenied", "Bluetooth permission was revoked", null)
        } catch (exception: IllegalArgumentException) {
            onceResult.error("invalidArguments", exception.message, null)
        } catch (exception: RuntimeException) {
            onceResult.error("androidException", exception.message, null)
        }
    }

    @SuppressLint("MissingPermission")
    fun emitAdapterState() {
        val currentAdapter = adapter
        when {
            currentAdapter == null -> emitter?.adapterStateChanged(BluetoothAdapter.ERROR)
            !hasConnectPermission() -> emitter?.emit(BluetoothMapper.unauthorizedAdapterState())
            else -> emitter?.adapterStateChanged(currentAdapter.state)
        }
    }

    @SuppressLint("MissingPermission")
    private fun getAdapterState(result: Result) {
        val currentAdapter = adapter
        if (currentAdapter == null) {
            result.success(BluetoothMapper.adapterState(BluetoothAdapter.ERROR).toMap())
            return
        }
        if (!hasConnectPermission()) {
            result.success(BluetoothMapper.unauthorizedAdapterState().toMap())
            return
        }
        result.success(BluetoothMapper.adapterState(currentAdapter.state).toMap())
    }

    @SuppressLint("MissingPermission")
    private fun startScan(result: Result) {
        if (!hasScanPermission()) {
            permissionDenied(result, scanPermission())
            return
        }
        if (!requireConnectPermission(result)) return
        val currentAdapter = requireAdapterOn(result) ?: return

        if (scanner?.start(currentAdapter, ScanSettings.SCAN_MODE_LOW_LATENCY) == true) {
            result.success(true)
        } else {
            result.error(
                BleChannelContract.Method.START_SCAN,
                "Bluetooth LE scanner is unavailable",
                null,
            )
        }
    }

    private fun stopScan(result: Result) {
        val currentScanner = scanner
            ?: throw IllegalStateException("Bluetooth scanner is not initialized")
        if (!hasScanPermission()) {
            currentScanner.stopSilently()
            permissionDenied(result, scanPermission())
            return
        }
        result.success(currentScanner.stop())
    }

    private fun connect(arguments: Any?, result: Result) {
        if (!requireConnectPermission(result)) return
        val currentAdapter = requireAdapterOn(result) ?: return
        val remoteId = requireString(arguments, BleChannelContract.Key.REMOTE_ID)
        result.success(requireConnections().connect(currentAdapter, remoteId))
    }

    private fun disconnect(arguments: Any?, result: Result) {
        if (!requireConnectPermission(result)) return
        result.success(
            requireConnections().disconnect(
                requireString(arguments, BleChannelContract.Key.REMOTE_ID),
            ),
        )
    }

    private fun discoverServices(arguments: Any?, result: Result) {
        if (!requireConnectPermission(result)) return
        completeOperation(
            result,
            requireConnections().discoverServices(
                requireString(arguments, BleChannelContract.Key.REMOTE_ID),
            ),
        )
    }

    private fun requestMtu(arguments: Any?, result: Result) {
        if (!requireConnectPermission(result)) return
        val args = RequestMtuArgs.fromMap(arguments)
        completeOperation(result, requireConnections().requestMtu(args.remoteId, args.mtu))
    }

    private fun writeCharacteristic(arguments: Any?, result: Result) {
        if (!requireConnectPermission(result)) return
        val args = WriteCharacteristicArgs.fromMap(arguments)
        completeOperation(
            result,
            requireConnections().writeCharacteristic(
                args.remoteId,
                args.primaryServiceUuid,
                args.serviceUuid,
                args.characteristicUuid,
                args.instanceId,
                args.value,
                args.withoutResponse,
            ),
        )
    }

    @SuppressLint("MissingPermission")
    private fun requireAdapterOn(result: Result): BluetoothAdapter? {
        val currentAdapter = adapter
        if (currentAdapter == null) {
            result.error("bluetoothUnavailable", "This device does not support Bluetooth", null)
            return null
        }
        if (!currentAdapter.isEnabled) {
            result.error("bluetoothOff", "Bluetooth must be turned on", null)
            return null
        }
        return currentAdapter
    }

    private fun requireConnectPermission(result: Result): Boolean {
        if (hasConnectPermission()) return true
        permissionDenied(result, CONNECT_PERMISSION)
        return false
    }

    private fun hasScanPermission(): Boolean {
        val currentContext = context ?: return false
        return ContextCompat.checkSelfPermission(currentContext, scanPermission()) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasConnectPermission(): Boolean {
        val currentContext = context ?: return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(
                currentContext,
                Manifest.permission.BLUETOOTH_CONNECT,
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requireConnections(): GattConnectionManager =
        connections ?: throw IllegalStateException("Bluetooth connections are not initialized")

    private class OnceResult(private val delegate: Result) : Result {
        private val completed = AtomicBoolean()

        override fun success(result: Any?) {
            if (completed.compareAndSet(false, true)) delegate.success(result)
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            if (completed.compareAndSet(false, true)) {
                delegate.error(errorCode, errorMessage, errorDetails)
            }
        }

        override fun notImplemented() {
            if (completed.compareAndSet(false, true)) delegate.notImplemented()
        }
    }

    private companion object {
        const val CONNECT_PERMISSION = "android.permission.BLUETOOTH_CONNECT"

        fun completeOperation(result: Result, error: String?) {
            when (error) {
                null -> result.success(true)
                GattConnectionManager.BUSY_ERROR -> result.error("operationBusy", error, null)
                else -> result.error("operationFailed", error, null)
            }
        }

        fun scanPermission(): String = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Manifest.permission.BLUETOOTH_SCAN
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        }

        fun permissionDenied(result: Result, permission: String) {
            result.error("permissionDenied", "Permission $permission is required", null)
        }

        fun requireString(value: Any?, name: String): String {
            val string = value as? String
            if (string.isNullOrBlank()) {
                throw IllegalArgumentException("$name must be a non-empty string")
            }
            return string
        }
    }
}
