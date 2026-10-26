package com.sentorr.sentorr

import android.app.Activity
import android.content.Context
import android.content.ComponentName
import android.content.pm.PackageManager
import android.content.res.Resources
import android.util.Log
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/// Matches the launcher icon and the next launch's splash to the app theme.
/// The launcher swap is deferred to onStop: toggling the alias the running
/// task was launched from can disturb that task while it is on screen.
class AppAppearance(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        private val VARIANTS = listOf("dark", "light")

        // Read the same file as Dart, before the engine or plugins exist.
        // Package identity isolates stable and nightly installations.
        fun savedThemeMode(context: Context): String {
            val directory = if (context.packageName.endsWith(".nightly")) {
                "SentorrNightlyData"
            } else {
                "SentorrData"
            }
            val settings = File(context.filesDir, "$directory/settings/settings.json")
            for (file in listOf(settings, File("${settings.path}.bak"))) {
                try {
                    if (!file.isFile) continue
                    val mode = JSONObject(file.readText()).optString("themeMode", "system")
                    return mode.takeIf { it in listOf("light", "dark", "system") } ?: "system"
                } catch (error: Exception) {
                    Log.w("SentorrAppearance", "Cannot read launch theme from $file", error)
                }
            }
            return "system"
        }

        fun launchTheme(mode: String): Int = when (mode) {
            "light" -> R.style.SplashLight
            "dark" -> R.style.SplashDark
            else -> R.style.LaunchTheme
        }

        fun normalTheme(mode: String): Int = when (mode) {
            "light" -> R.style.NormalLight
            "dark" -> R.style.NormalDark
            else -> R.style.NormalTheme
        }
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
        Log.i("SentorrLifecycle", "Applying pending launcher variant=$variant onStop")
        val packageManager = activity.packageManager
        // Enable before disabling so the app never has zero launcher entries.
        for (name in VARIANTS.sortedBy { it != variant }) {
            val alias = "Launcher" + name.replaceFirstChar(Char::uppercase)
            // Manifest aliases use the code namespace, not the applicationId or
            // this class's runtime package, which R8 can rename in release builds.
            val component = ComponentName(activity, "com.sentorr.sentorr.$alias")
            val state = if (name == variant) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            if (packageManager.getComponentEnabledSetting(component) == state) continue
            Log.i("SentorrLifecycle", "Changing launcher alias=$alias state=$state DONT_KILL_APP")
            packageManager.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
        }
    }

    /// Android 12+ persists this for later launches; "system" restores the
    /// manifest's LaunchTheme, which follows the system night mode.
    private fun setSplashTheme(mode: String?) {
        activity.window.setBackgroundDrawableResource(
            when (mode) {
                "light" -> R.color.splash_background_light
                "dark" -> R.color.splash_background_dark
                else -> R.color.splash_background
            },
        )
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        activity.splashScreen.setSplashScreenTheme(
            when (mode) {
                "light" -> R.style.SplashLight
                "dark" -> R.style.SplashDark
                else -> Resources.ID_NULL
            },
        )
    }
}
