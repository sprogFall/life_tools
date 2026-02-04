package com.example.life_tools

import android.os.Build
import android.view.Display
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "life_tools/display"
    private val minModeApi = 23

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
            val attributes = window.attributes
            attributes.preferredRefreshRate = hz

            if (Build.VERSION.SDK_INT >= minModeApi) {
                @Suppress("DEPRECATION")
                val display = windowManager.defaultDisplay
                val supported = display.supportedModes
                val current = display.mode
                val candidateModes = supported
                    .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
                    .ifEmpty { supported.asList() }
                val targetMode = pickBestMode(candidateModes, hz)
                if (targetMode != null) {
                    attributes.preferredDisplayModeId = targetMode.modeId
                    // 某些机型更依赖 preferredRefreshRate，因此同时设置。
                    attributes.preferredRefreshRate = targetMode.refreshRate
                }
            }

            window.attributes = attributes
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun pickBestMode(modes: List<Display.Mode>, desiredHz: Float): Display.Mode? {
        if (modes.isEmpty()) return null
        val sorted = modes.sortedBy { it.refreshRate }
        val target = sorted.firstOrNull { it.refreshRate + 0.1f >= desiredHz }
        return target ?: sorted.lastOrNull()
    }
}
