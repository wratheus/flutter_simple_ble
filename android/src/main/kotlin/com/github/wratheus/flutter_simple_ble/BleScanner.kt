// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

package com.github.wratheus.flutter_simple_ble

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

internal class BleScanner(
    private val context: Context,
    private val emitter: BluetoothEventEmitter,
) {
    private var activeScanner: BluetoothLeScanner? = null
    private var scanning = false

    private val callback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            if (!hasScanPermissions()) {
                stopSilently()
                emitter.scanFailed(-1, "Bluetooth permission denied")
                return
            }
            emitter.scanResult(BluetoothMapper.advertisement(result))
        }

        override fun onScanFailed(errorCode: Int) {
            synchronized(this@BleScanner) {
                scanning = false
                activeScanner = null
            }
            emitter.scanFailed(errorCode, scanError(errorCode))
        }
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun start(adapter: BluetoothAdapter, scanMode: Int): Boolean {
        if (scanning) return false
        val bluetoothLeScanner = adapter.bluetoothLeScanner ?: return false
        val settings = ScanSettings.Builder().apply {
            setScanMode(scanMode)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                setPhy(ScanSettings.PHY_LE_ALL_SUPPORTED)
                setLegacy(false)
            }
        }.build()
        bluetoothLeScanner.startScan(null, settings, callback)
        activeScanner = bluetoothLeScanner
        scanning = true
        return true
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun stop(): Boolean {
        if (!scanning) return false
        activeScanner?.stopScan(callback)
        activeScanner = null
        scanning = false
        return true
    }

    @SuppressLint("MissingPermission")
    @Synchronized
    fun stopSilently() {
        if (!scanning) return
        try {
            if (hasScanPermission()) activeScanner?.stopScan(callback)
        } catch (_: SecurityException) {
            // Permission may be revoked while scanning is active.
        }
        activeScanner = null
        scanning = false
    }

    private fun hasScanPermission(): Boolean = ContextCompat.checkSelfPermission(
        context,
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Manifest.permission.BLUETOOTH_SCAN
        } else {
            Manifest.permission.ACCESS_FINE_LOCATION
        },
    ) == PackageManager.PERMISSION_GRANTED

    private fun hasScanPermissions(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return hasScanPermission() && ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT,
            ) == PackageManager.PERMISSION_GRANTED
        }
        return hasScanPermission()
    }

    private companion object {
        fun scanError(code: Int): String = when (code) {
            ScanCallback.SCAN_FAILED_ALREADY_STARTED -> "scan already started"
            ScanCallback.SCAN_FAILED_APPLICATION_REGISTRATION_FAILED -> "scan registration failed"
            ScanCallback.SCAN_FAILED_FEATURE_UNSUPPORTED -> "scan feature unsupported"
            ScanCallback.SCAN_FAILED_INTERNAL_ERROR -> "internal scan error"
            ScanCallback.SCAN_FAILED_OUT_OF_HARDWARE_RESOURCES -> "no scan hardware resources"
            ScanCallback.SCAN_FAILED_SCANNING_TOO_FREQUENTLY -> "scanning too frequently"
            else -> "scan failed ($code)"
        }
    }
}
