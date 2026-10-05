package com.sentorr.sentorr

import android.app.Activity
import android.content.Intent
import android.os.Bundle

// Opened by sentorr://return links, e.g. the Drive sign-in page's "Back to
// Sentorr": brings the running app's task forward, as its launcher icon
// would, and goes. MainActivity never sees the link, so it is neither
// started twice nor handed a route.
class ReturnActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(it)
        }
        finish()
    }
}
