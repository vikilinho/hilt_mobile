package com.hiltking.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val scannerBrightnessChannel = "com.hiltking.app/scanner_brightness"
    private var previousWindowBrightness: Float? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
