package app.openfamily

import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    // bray 2026-09-18 (offline maps): the storage volumes a map pack can live
    // on - the app's internal files dir plus the app-specific folder on every
    // mounted external volume (a removable SD card included), each with its
    // free space. No permission needed: these folders are the app's own.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.openfamily/storage").setMethodCallHandler { call, result ->
            if (call.method != "volumes") { result.notImplemented(); return@setMethodCallHandler }
            result.success(volumes())
        }
    }

    private fun stat(dir: File): Pair<Long, Long> = try {
        val s = StatFs(dir.path); Pair(s.availableBytes, s.totalBytes)
    } catch (e: Exception) { Pair(0L, 0L) }

    private fun volumes(): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        val internal = filesDir
        val (f, t) = stat(internal)
        out.add(mapOf("id" to "internal", "label" to "Internal storage", "path" to internal.path, "free" to f, "total" to t, "removable" to false))
        val sm = getSystemService(STORAGE_SERVICE) as StorageManager
        var n = 0
        for (dir in getExternalFilesDirs(null)) {
            if (dir == null) continue
            // the primary "external" volume on modern phones is the same flash as internal; skip it unless it is really removable
            val vol = try { sm.getStorageVolume(dir) } catch (e: Exception) { null }
            val removable = vol?.isRemovable ?: Environment.isExternalStorageRemovable(dir)
            val emulated = vol?.isEmulated ?: Environment.isExternalStorageEmulated(dir)
            if (emulated && !removable) continue
            if (Environment.getExternalStorageState(dir) != Environment.MEDIA_MOUNTED) continue
            n++
            val label = (if (Build.VERSION.SDK_INT >= 30) vol?.getDescription(this) else null) ?: (if (removable) "SD card" else "External storage")
            val (ff, tt) = stat(dir)
            out.add(mapOf("id" to "external$n", "label" to label, "path" to dir.path, "free" to ff, "total" to tt, "removable" to removable))
        }
        return out
    }
}
