package com.hiltking.app

import android.view.WindowManager
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ObjectInputStream

class MainActivity : FlutterFragmentActivity(), MessageClient.OnMessageReceivedListener {
    private val scannerBrightnessChannel = "com.hiltking.app/scanner_brightness"
    private val watchHeartRateChannel = "com.hiltking.app/watch_heart_rate"
    private val watchConnectivityPath = "watch_connectivity"
    private var previousWindowBrightness: Float? = null
    private var watchHeartRateSink: EventChannel.EventSink? = null
    private lateinit var watchMessageClient: MessageClient

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        watchMessageClient = Wearable.getMessageClient(applicationContext)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            watchHeartRateChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                watchHeartRateSink = events
            }

            override fun onCancel(arguments: Any?) {
                watchHeartRateSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            scannerBrightnessChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "dimForScanner" -> {
                    val level = (call.argument<Double>("level") ?: 0.08).toFloat()
                    dimForScanner(level)
                    result.success(null)
                }

                "restoreBrightness" -> {
                    restoreBrightness()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onStart() {
        super.onStart()
        watchMessageClient.addListener(this)
    }

    override fun onStop() {
        watchMessageClient.removeListener(this)
        super.onStop()
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != watchConnectivityPath) return

        try {
            val payload = ObjectInputStream(ByteArrayInputStream(messageEvent.data)).use {
                it.readObject()
            }
            if (payload is Map<*, *>) {
                val safePayload = payload.entries.associate { (key, value) ->
                    key.toString() to value
                }
                runOnUiThread { watchHeartRateSink?.success(safePayload) }
            }
        } catch (error: Exception) {
            runOnUiThread {
                watchHeartRateSink?.error(
                    "invalid_watch_payload",
                    "Unable to decode heart-rate data from the watch.",
                    error.message
                )
            }
        }
    }

    private fun dimForScanner(level: Float) {
        val params = window.attributes
        if (previousWindowBrightness == null) {
            previousWindowBrightness = params.screenBrightness
        }
        params.screenBrightness = level.coerceIn(0.01f, 0.2f)
        window.attributes = params
    }

    private fun restoreBrightness() {
        val params = window.attributes
        params.screenBrightness = previousWindowBrightness
            ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        window.attributes = params
        previousWindowBrightness = null
    }
}
