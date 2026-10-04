package com.sentorr.sentorr

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// System Picture-in-Picture for the player. Dart pushes what the window's
/// controls should show; taps on them and the window opening or closing
/// are sent back, so the OS window drives the same player as the app.
class PipController(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private companion object {
        const val ACTION = "com.sentorr.sentorr.PIP_ACTION"
        val ACTIONS = listOf("previous", "playPause", "next")
    }

    private val channel = MethodChannel(messenger, "sentorr/pip")
    private var enabled = false
    private var playing = false
    private var hasNext = false

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.getStringExtra("action") ?: return
            channel.invokeMethod("action", action)
        }
    }

    init {
        ContextCompat.registerReceiver(
            activity,
            receiver,
            IntentFilter(ACTION),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(supported())
                "enter" -> result.success(enter())
                "update" -> {
                    enabled = call.argument<Boolean>("enabled") == true
                    playing = call.argument<Boolean>("playing") == true
                    hasNext = call.argument<Boolean>("hasNext") == true
                    apply()
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        activity.unregisterReceiver(receiver)
    }

    /// Before Android 12 there is no auto-enter flag, so leaving with Home
    /// while playing enters by hand.
    fun onUserLeaveHint() {
        if (enabled && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) enter()
    }

    fun onModeChanged(active: Boolean) {
        channel.invokeMethod("changed", active)
    }

    private fun supported() =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(
                PackageManager.FEATURE_PICTURE_IN_PICTURE,
            )

    private fun enter(): Boolean {
        if (!supported()) return false
        return try {
            activity.enterPictureInPictureMode(params())
        } catch (_: IllegalStateException) {
            false
        }
    }

    private fun apply() {
        if (supported()) activity.setPictureInPictureParams(params())
    }

    private fun params(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .setActions(remoteActions())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(enabled).setSeamlessResizeEnabled(true)
        }
        return builder.build()
    }

    private fun remoteActions(): List<RemoteAction> = ACTIONS.mapIndexed { i, name ->
        val (icon, title) = when (name) {
            "previous" -> R.drawable.ic_pip_previous to "Previous"
            "next" -> R.drawable.ic_pip_next to "Next"
            else -> if (playing) {
                R.drawable.ic_pip_pause to "Pause"
            } else {
                R.drawable.ic_pip_play to "Play"
            }
        }
        val intent = PendingIntent.getBroadcast(
            activity,
            i,
            Intent(ACTION).setPackage(activity.packageName).putExtra("action", name),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        RemoteAction(Icon.createWithResource(activity, icon), title, title, intent)
            .apply { isEnabled = name != "next" || hasNext }
    }
}
