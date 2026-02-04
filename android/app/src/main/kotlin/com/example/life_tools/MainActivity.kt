package com.example.life_tools

import android.os.Build
import android.view.Window
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "life_tools/display"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestFrameRate" -> {
                    val hz = (call.argument<Double>("hz") ?: 90.0).toFloat()
                    result.success(requestFrameRateSafely(hz))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestFrameRateSafely(hz: Float): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.setFrameRate(
                    hz,
                    Window.FRAME_RATE_COMPATIBILITY_DEFAULT,
                    Window.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS,
                )
                true
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }
}
