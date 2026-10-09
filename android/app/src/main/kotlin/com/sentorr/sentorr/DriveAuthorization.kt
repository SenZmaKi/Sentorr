package com.sentorr.sentorr

import android.app.Activity
import android.content.Intent
import android.util.Log
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.AuthorizationResult
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** On-device Drive authorization. No browser redirect, client secret or refresh token. */
class DriveAuthorization(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val REQUEST = 61042
        private const val SCOPE = "https://www.googleapis.com/auth/drive.appdata"
    }

    private val client = Identity.getAuthorizationClient(activity)
    private val preferences = activity.getSharedPreferences("drive_authorization", Activity.MODE_PRIVATE)
    private val channel = MethodChannel(messenger, "sentorr/drive_auth")
    private var pending: MethodChannel.Result? = null
    private var interactive = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "restore" -> result.success(preferences.getBoolean("connected", false))
                "authorize" -> {
                    if (pending != null) {
                        result.error("busy", "Drive authorization is already running.", null)
                    } else {
                        pending = result
                        interactive = call.argument<Boolean>("interactive") == true
                        val token = call.argument<String>("invalidateToken")
                        if (token.isNullOrEmpty()) authorize()
                        else client.clearToken(ClearTokenRequest.builder().setToken(token).build())
                            .addOnSuccessListener { if (pending != null) authorize() }
                            .addOnFailureListener { fail(it) }
                    }
                }
                "forget" -> {
                    preferences.edit().remove("connected").apply()
                    val token = call.argument<String>("token")
                    if (token.isNullOrEmpty()) result.success(null)
                    else client.clearToken(ClearTokenRequest.builder().setToken(token).build())
                        .addOnCompleteListener {
                            Log.i("SentorrDriveAuth", "Drive disconnected; cacheCleared=${it.isSuccessful}")
                            result.success(null)
                        }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun authorize() {
        Log.i("SentorrDriveAuth", "Native authorization starting; interactive=$interactive")
        val request = AuthorizationRequest.builder()
            .setRequestedScopes(listOf(Scope(SCOPE)))
            .build()
        client.authorize(request)
            .addOnSuccessListener { authorization ->
                if (pending == null) return@addOnSuccessListener
                if (!authorization.hasResolution()) finish(authorization)
                else if (!interactive) {
                    preferences.edit().remove("connected").apply()
                    completeError("reauthorize_required", "Google Drive access needs permission. Connect again.")
                } else {
                    try {
                        Log.i("SentorrDriveAuth", "Opening native account/consent dialog")
                        activity.startIntentSenderForResult(
                            authorization.pendingIntent!!.intentSender, REQUEST, null, 0, 0, 0,
                        )
                    } catch (error: Exception) { fail(error) }
                }
            }
            .addOnFailureListener { fail(it) }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        if (pending == null) return true
        if (resultCode != Activity.RESULT_OK) {
            completeError("cancelled", "Sign-in was cancelled.")
        } else {
            try { finish(client.getAuthorizationResultFromIntent(data)) }
            catch (error: Exception) { fail(error) }
        }
        return true
    }

    private fun finish(authorization: AuthorizationResult) {
        val token = authorization.accessToken
        if (token.isNullOrEmpty() || !authorization.grantedScopes.contains(SCOPE)) {
            preferences.edit().remove("connected").apply()
            completeError("missing_access", "Google did not grant Drive backup access.")
            return
        }
        preferences.edit().putBoolean("connected", true).apply()
        Log.i("SentorrDriveAuth", "Native Drive authorization complete")
        val result = pending
        pending = null
        result?.success(token)
    }

    private fun fail(error: Exception) {
        val status = (error as? ApiException)?.statusCode
        Log.w("SentorrDriveAuth", "Native authorization failed: ${error.javaClass.simpleName}, status=$status")
        completeError("authorization_failed", "Google Drive authorization failed (status ${status ?: "unknown"}). Check Google Play services and the Android OAuth registration.")
    }

    private fun completeError(code: String, message: String) {
        val result = pending
        pending = null
        result?.error(code, message, null)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        completeError("activity_destroyed", "Sign-in was interrupted. Try connecting again.")
    }
}
