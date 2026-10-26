package dev.bakequote.bakequote_mobile

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.bakequote/share")
            .setMethodCallHandler { call, result ->
                if (call.method == "share" && call.arguments is String) {
                    try {
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, call.arguments as String)
                        }
                        startActivity(Intent.createChooser(intent, "Share BakeQuote code"))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("share_unavailable", "Sharing unavailable", null)
                    }
                } else result.notImplemented()
            }
    }
}
