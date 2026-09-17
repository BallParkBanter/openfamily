package yukams.app.background_locator_2

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

// Restarts tracking after a device reboot AND after the app is updated in
// place (bray 2026-09-17: an `adb install -r` of a new build kills the app
// and its location foreground service, and Android does not restart the
// service on its own - Bo's tablet posted nothing for 21 minutes in the truck
// until he opened the app). MY_PACKAGE_REPLACED runs the same boot path.
class BootBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            try {
                BackgroundLocatorPlugin.registerAfterBoot(context)
            } catch (e: Exception) {
                // Never registered on this device (nothing stored): nothing to restart.
                Log.w("BootBroadcastReceiver", "no stored locator settings to restart: ${e.message}")
            }
        }
    }
}
