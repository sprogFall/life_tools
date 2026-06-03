package com.example.life_tools

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.Display
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val displayChannelName = "life_tools/display"
    private val mediaStoreChannelName = "life_tools/media_store"
    private val updateChannelName = "life_tools/app_update"
    private val minModeApi = 23
    private val scannedMediaUris = mutableMapOf<String, String>()

    companion object {
        private const val APP_ALBUM_ROOT = "外拍助手"  // App 专属相册根目录
    }

    override fun onResume() {
        super.onResume()
        // 某些机型在切后台/锁屏后会重置刷新率偏好；恢复时尽量再次请求高刷。
        requestFrameRateSafely(90.0f)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, displayChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestFrameRate" -> {
                    val hz = (call.argument<Double>("hz") ?: 90.0).toFloat()
                    result.success(requestFrameRateSafely(hz))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaStoreChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImage" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val albumRelativePath = call.argument<String>("albumRelativePath")
                    val displayName = call.argument<String>("displayName")
                    if (sourcePath.isNullOrBlank() || albumRelativePath.isNullOrBlank() || displayName.isNullOrBlank()) {
                        result.success(null)
                    } else {
                        result.success(saveImageToGallery(sourcePath, albumRelativePath, displayName))
                    }
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        scanMediaFile(path) { success -> result.success(success) }
                    }
                }
                "deleteFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.success(false)
                    } else {
                        deleteMediaFileRecord(path) { success -> result.success(success) }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("invalid_path", "安装包路径为空", null)
                    } else {
                        installApk(path, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        try {
            val apkFile = File(path).canonicalFile
            val updateDir = File(cacheDir, "updates").canonicalFile
            if (!apkFile.path.startsWith(updateDir.path + File.separator) || apkFile.extension.lowercase() != "apk") {
                result.error("invalid_path", "安装包路径不在允许目录内", null)
                return
            }
            if (!apkFile.isFile) {
                result.error("file_not_found", "安装包不存在", null)
                return
            }

            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.update_file_provider",
                apkFile,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("install_failed", "无法打开系统安装器", null)
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

    private fun scanMediaFile(path: String, callback: (Boolean) -> Unit) {
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(path),
            arrayOf("image/jpeg"),
        ) { scannedPath, uri ->
            if (scannedPath != null && uri != null) {
                scannedMediaUris[scannedPath] = uri.toString()
            }
            callback(uri != null)
        }
    }

    private fun deleteMediaFileRecord(path: String, callback: (Boolean) -> Unit) {
        // 安全检查：仅允许删除 app 目录内的图片
        if (!isPathInAppDirectory(path)) {
            callback(false)
            return
        }

        val uriValue = scannedMediaUris.remove(path)
        if (uriValue != null) {
            try {
                val rows = contentResolver.delete(Uri.parse(uriValue), null, null)
                callback(rows > 0)
                return
            } catch (_: Exception) {
                // 继续走查询删除兜底。
            }
        }

        try {
            val uri = findImageUri(path)
            if (uri != null) {
                val rows = contentResolver.delete(uri, null, null)
                callback(rows > 0)
            } else {
                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(path),
                    arrayOf("image/jpeg"),
                ) { _, _ -> callback(false) }
            }
        } catch (_: Exception) {
            callback(false)
        }
    }

    private fun saveImageToGallery(
        sourcePath: String,
        albumRelativePath: String,
        displayName: String,
    ): String? {
        // 安全检查：仅允许保存到 app 目录内
        if (!isAlbumPathInAppDirectory(albumRelativePath)) {
            return null
        }

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveImageToMediaStore(sourcePath, albumRelativePath, displayName)
            } else {
                saveImageToPublicPictures(sourcePath, albumRelativePath, displayName)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun saveImageToMediaStore(
        sourcePath: String,
        albumRelativePath: String,
        displayName: String,
    ): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null

        val relativePath = "${Environment.DIRECTORY_PICTURES}/${albumRelativePath.trim('/')}/"
        val absolutePath = "${Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).absolutePath}/${albumRelativePath.trim('/')}/$displayName"
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
            put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = contentResolver.insert(collection, values) ?: return null
        return try {
            val outputStream = contentResolver.openOutputStream(uri)
            if (outputStream == null) {
                contentResolver.delete(uri, null, null)
                return null
            }
            outputStream.use { output ->
                FileInputStream(File(sourcePath)).use { input -> input.copyTo(output) }
            }
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            scannedMediaUris[absolutePath] = uri.toString()
            absolutePath
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            throw e
        }
    }

    private fun saveImageToPublicPictures(
        sourcePath: String,
        albumRelativePath: String,
        displayName: String,
    ): String? {
        val dir = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            albumRelativePath.trim('/'),
        )
        if (!dir.exists() && !dir.mkdirs()) return null
        val target = File(dir, displayName)
        File(sourcePath).copyTo(target, overwrite = true)
        scanMediaFile(target.absolutePath) { _ -> }
        return target.absolutePath
    }

    private fun findImageUri(path: String): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            findImageUriByRelativePath(path)
        } else {
            findImageUriByDataPath(path)
        }
    }

    private fun findImageUriByRelativePath(path: String): Uri? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val file = File(path)
        val picturesRoot = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES).absolutePath
        val relative = file.parentFile?.absolutePath
            ?.removePrefix(picturesRoot)
            ?.trim('/')
            ?.takeIf { it.isNotBlank() }
            ?: return null
        val mediaRelativePath = "${Environment.DIRECTORY_PICTURES}/$relative/"
        val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        contentResolver.query(
            collection,
            arrayOf(MediaStore.Images.Media._ID),
            "${MediaStore.Images.Media.DISPLAY_NAME}=? AND ${MediaStore.Images.Media.RELATIVE_PATH}=?",
            arrayOf(file.name, mediaRelativePath),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(0)
                return ContentUris.withAppendedId(collection, id)
            }
        }
        return null
    }

    private fun findImageUriByDataPath(path: String): Uri? {
        @Suppress("DEPRECATION")
        contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(MediaStore.Images.Media._ID),
            "${MediaStore.Images.Media.DATA}=?",
            arrayOf(path),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(0)
                return ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
            }
        }
        return null
    }

    /**
     * 检查绝对路径是否在 app 目录内
     * 仅允许访问 /Pictures/外拍助手/ 下的文件
     */
    private fun isPathInAppDirectory(path: String): Boolean {
        val file = File(path).canonicalFile
        val appRoot = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            APP_ALBUM_ROOT,
        ).canonicalFile
        return file.path.startsWith(appRoot.path + File.separator)
    }

    /**
     * 检查相册相对路径是否在 app 目录内
     * 例如："外拍助手/photos/123" -> true, "../../etc/passwd" -> false
     */
    private fun isAlbumPathInAppDirectory(albumRelativePath: String): Boolean {
        val normalized = albumRelativePath.trim('/')
        if (normalized.isEmpty()) return false

        // 禁止路径穿越
        if (normalized.contains("..")) return false

        // 必须以 APP_ALBUM_ROOT 开头
        val segments = normalized.split('/').filter { it.isNotEmpty() }
        return segments.isNotEmpty() && segments[0] == APP_ALBUM_ROOT
    }
}
