// SPDX-FileCopyrightText: 2026 Aleksandr <https://github.com/Wratheus>
// SPDX-License-Identifier: BSD-3-Clause

package com.github.wratheus.flutter_simple_ble

import android.os.Handler
import android.os.Looper

internal class BluetoothEventEmitter(callback: BleCore.EventCallback) {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var callback: BleCore.EventCallback? = callback

    fun setCallback(callback: BleCore.EventCallback) {
        this.callback = callback
    }

    fun clear() {
        callback = null
    }

    fun emit(message: BleChannelEventMessage) {
        mainHandler.post {
            callback?.emit(message.event, message.toMap())
        }
    }

    fun adapterStateChanged(state: Int) {
        emit(BluetoothMapper.adapterState(state))
    }

    fun scanResult(advertisement: AdvertisementMessage) {
        emit(
            ScanResponseMessage(
                success = true,
                advertisements = listOf(advertisement),
            ),
        )
    }

    fun scanFailed(code: Int, message: String) {
        emit(
            ScanResponseMessage(
                success = false,
                advertisements = emptyList(),
                errorCode = code,
                errorString = message,
            ),
        )
    }
}
