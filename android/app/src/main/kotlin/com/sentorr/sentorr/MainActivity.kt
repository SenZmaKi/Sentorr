package com.sentorr.sentorr

import android.os.Bundle
import android.os.Process
import android.util.Log
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import com.pravera.flutter_foreground_task.service.ForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private companion object {
        const val ENGINE_ID = "main"
    }

    // Downloads and the torrent engine run in this engine's isolates. While
    // the download service holds the process up, the engine outlives the
    // activity, so dismissing the app keeps downloading and reopening it
    // reattaches to the running app.
    override fun provideFlutterEngine(context: Context): FlutterEngine? =
        FlutterEngineCache.getInstance().get(ENGINE_ID)

    override fun shouldDestroyEngineWithHost(): Boolean =
        !isChangingConfigurations && !ForegroundService.isRunningServiceState.value

    private var pip: PipController? = null
    private var appearance: AppAppearance? = null
    private var driveAuthorization: DriveAuthorization? = null

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        pip?.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pip?.onModeChanged(isInPictureInPictureMode)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.i("SentorrLifecycle", "onCreate pid=${Process.myPid()} restored=${savedInstanceState != null}")
        super.onCreate(savedInstanceState)
    }

    override fun onResume() {
        super.onResume()
        Log.i("SentorrLifecycle", "onResume pid=${Process.myPid()}")
    }

    override fun onPause() {
        Log.i("SentorrLifecycle", "onPause finishing=$isFinishing changingConfig=$isChangingConfigurations")
        super.onPause()
    }

    override fun onStop() {
        Log.i("SentorrLifecycle", "onStop finishing=$isFinishing changingConfig=$isChangingConfigurations")
        super.onStop()
        appearance?.onStop()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        driveAuthorization?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        driveAuthorization?.dispose()
        driveAuthorization = null
        pip?.dispose()
        pip = null
        appearance?.dispose()
        appearance = null
        val destroyEngine = shouldDestroyEngineWithHost()
        Log.i("SentorrLifecycle", "onDestroy pid=${Process.myPid()} finishing=$isFinishing changingConfig=$isChangingConfigurations destroyEngine=$destroyEngine foregroundService=${ForegroundService.isRunningServiceState.value}")
        super.onDestroy()
        if (destroyEngine) FlutterEngineCache.getInstance().remove(ENGINE_ID)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        driveAuthorization?.dispose()
        driveAuthorization = DriveAuthorization(this, flutterEngine.dartExecutor.binaryMessenger)
        pip?.dispose()
        pip = PipController(this, flutterEngine.dartExecutor.binaryMessenger)
        appearance?.dispose()
        appearance = AppAppearance(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "sentorr/update_installer",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath.isNullOrBlank()) {
                        result.error("invalid_path", "Missing prepared APK path.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        openApkInstaller(File(filePath))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("install_failed", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openApkInstaller(apk: File) {
        require(apk.isFile) { "The prepared APK is missing." }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            return
        }

        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.update_provider",
            apk,
        )
        startActivity(
            Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                data = apkUri
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
                putExtra(Intent.EXTRA_RETURN_RESULT, false)
            },
        )
    }
}
