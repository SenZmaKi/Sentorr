package com.sentorr.sentorr

import android.app.Activity
import android.content.ComponentName
import android.content.pm.PackageManager
import android.content.res.Resources
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/// Matches the launcher icon and the next launch's splash to the app theme.
/// The launcher swap is deferred to onStop: toggling the alias the running
/// task was launched from can disturb that task while it is on screen.
class AppAppearance(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private companion object {
        val VARIANTS = listOf("dark", "light")
    }

    private val channel = MethodChannel(messenger, "sentorr/app_icon")
    private var pendingLauncher: String? = null

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setLauncherIcon" -> {
                    pendingLauncher = call.arguments<String>()?.takeIf { it in VARIANTS }
                    result.success(null)
                }

                "setSplashTheme" -> {
                    setSplashTheme(call.arguments<String>())
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    fun onStop() {
        val variant = pendingLauncher ?: return
        pendingLauncher = null
        val packageManager = activity.packageManager
        // Enable before disabling so the app never has zero launcher entries.
        for (name in VARIANTS.sortedBy { it != variant }) {
            val alias = "Launcher" + name.replaceFirstChar(Char::uppercase)
            // Aliases live in the code namespace, which may differ from the applicationId.
            val component = ComponentName(activity, "${javaClass.`package`!!.name}.$alias")
            val state = if (name == variant) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            if (packageManager.getComponentEnabledSetting(component) == state) continue
            packageManager.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
        }
    }

    /// Android 13+ persists this for later launches; "system" restores the
    /// manifest's LaunchTheme, which follows the system night mode.
    private fun setSplashTheme(mode: String?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        activity.splashScreen.setSplashScreenTheme(
            when (mode) {
                "light" -> R.style.SplashLight
                "dark" -> R.style.SplashDark
                else -> Resources.ID_NULL
            },
        )
    }
}
