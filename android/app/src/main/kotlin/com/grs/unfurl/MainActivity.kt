package com.grs.unfurl

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.res.Configuration
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private lateinit var storage: Storage
    private lateinit var speech: Speech
    private var pending: MethodChannel.Result? = null
    private var pendingIntent: Map<String, Any?>? = null
    private var volumeKeys = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        paintLaunchWindow()
        pendingIntent = describe(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        storage = Storage(this)
        speech = Speech(this) { method, args -> runOnUiThread { channel.invokeMethod(method, args) } }
        channel = MethodChannel(messenger, "unfurl/platform")
        channel.setMethodCallHandler(::handle)
        Scanner(this).register(messenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        describe(intent)?.let { channel.invokeMethod("intent", it) }
    }

    override fun onDestroy() {
        if (::speech.isInitialized) speech.shutdown()
        super.onDestroy()
    }

    /** Volume keys turn pages while a reader asks for them; otherwise they set the volume. */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        if (volumeKeys && (code == KeyEvent.KEYCODE_VOLUME_UP || code == KeyEvent.KEYCODE_VOLUME_DOWN)) {
            if (event.action == KeyEvent.ACTION_DOWN) channel.invokeMethod("volumeKey", if (code == KeyEvent.KEYCODE_VOLUME_DOWN) 1 else -1)
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "pickFile" -> {
                    pending = result
                    val pick = Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
                    call.argument<List<String>>("mimes")?.let { pick.putExtra(Intent.EXTRA_MIME_TYPES, it.toTypedArray()) }
                    startActivityForResult(pick, PICK_FILE)
                }
                "pickFolder" -> {
                    pending = result
                    startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(TREE_FLAGS), PICK_FOLDER)
                }
                "releaseFolder" -> result.success(storage.release(call.argument<String>("uri")!!))
                "persistedFolders" -> result.success(contentResolver.persistedUriPermissions.filter { it.isReadPermission }.map { it.uri.toString() })
                "stat" -> result.success(storage.stat(Uri.parse(call.argument<String>("uri")!!)))
                "openFd" -> result.success(storage.openFd(Uri.parse(call.argument<String>("uri")!!)))
                "closeFd" -> result.success(storage.closeFd(call.argument<Int>("fd")!!))
                "takeIntent" -> { result.success(pendingIntent); pendingIntent = null }
                "openWith" -> result.success(launch(Intent.createChooser(viewIntent(call), null)))
                "shareFile" -> {
                    val send = Intent(Intent.ACTION_SEND).setType(call.argument<String>("mime") ?: "*/*")
                        .putExtra(Intent.EXTRA_STREAM, Uri.parse(call.argument<String>("uri")!!))
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    result.success(launch(Intent.createChooser(send, null)))
                }
                "shareText" -> {
                    val send = Intent(Intent.ACTION_SEND).setType("text/markdown")
                        .putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                        .putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("subject"))
                    result.success(launch(Intent.createChooser(send, null)))
                }
                "appVersion" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
                    result.success("${info.versionName} ($code)")
                }
                "isInstalled" -> result.success(installed(call.argument<String>("package")!!))
                "openApp" -> result.success(
                    packageManager.getLaunchIntentForPackage(call.argument<String>("package")!!)?.let { launch(it) } ?: false,
                )
                "defineInMull" -> {
                    // Mull's DefineActivity takes PROCESS_TEXT and shows its word sheet over Unfurl.
                    val define = Intent(Intent.ACTION_PROCESS_TEXT).setType("text/plain").setPackage(MULL)
                        .putExtra(Intent.EXTRA_PROCESS_TEXT, call.argument<String>("text"))
                        .putExtra(Intent.EXTRA_PROCESS_TEXT_READONLY, true)
                    result.success(launch(define))
                }
                "openStore" -> {
                    val id = call.argument<String>("package")!!
                    result.success(
                        launch(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$id"))) ||
                            launch(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$id"))),
                    )
                }
                "openUrl" -> result.success(launch(Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")!!))))
                "email" -> result.success(
                    launch(
                        Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:${call.argument<String>("to")}"))
                            .putExtra(Intent.EXTRA_SUBJECT, call.argument<String>("subject")),
                    ),
                )
                "ttsSettings" -> result.success(launch(Intent("com.android.settings.TTS_SETTINGS")))
                "keepScreenOn" -> {
                    if (call.argument<Boolean>("on") == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "brightness" -> {
                    // -1 hands brightness back to the system.
                    window.attributes = window.attributes.apply { screenBrightness = (call.argument<Double>("value") ?: -1.0).toFloat() }
                    result.success(null)
                }
                "volumeKeys" -> { volumeKeys = call.argument<Boolean>("on") == true; result.success(null) }
                "speak" -> result.success(speech.speak(call.argument<String>("text")!!, call.argument<String>("id")!!))
                "stopSpeaking" -> { speech.stop(); result.success(null) }
                "speechRate" -> { speech.rate = (call.argument<Double>("rate") ?: 1.0).toFloat(); result.success(null) }
                "voices" -> speech.voices { result.success(it) }
                "setVoice" -> result.success(speech.setVoice(call.argument<String>("name")))
                "preview" -> result.success(speech.preview(call.argument<String>("name")!!, call.argument<String>("text")!!))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("platform", e.message, null)
        }
    }

    @Deprecated("Activity results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) return result.success(null)
        when (requestCode) {
            PICK_FILE -> {
                try {
                    contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } catch (_: SecurityException) {
                }
                result.success(storage.stat(uri))
            }
            PICK_FOLDER -> result.success(storage.takeFolder(uri))
        }
    }

    private fun viewIntent(call: MethodCall): Intent =
        Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse(call.argument<String>("uri")!!), call.argument<String>("mime") ?: "*/*")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

    private fun launch(intent: Intent): Boolean = try {
        startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    private fun installed(pkg: String): Boolean = try {
        packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: Exception) {
        false
    }

    /** An "Open with" or share arrival, as the file it names. */
    private fun describe(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        val uri: Uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        } ?: return null
        try {
            contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) {
        }
        val stat = storage.stat(uri) ?: mapOf("uri" to uri.toString())
        return stat + mapOf("referrer" to referrer?.host, "mime" to (stat["mime"] ?: intent.type))
    }

    /**
     * Until Flutter's first frame the window shows through. Paint it in the chrome
     * surface the app cached (`AppSettings.kLaunchLight` / `kLaunchDark`, which follow
     * dynamic colour and true black), and on Android 13+ choose the splash theme the
     * next cold start uses, so a launch never flashes a colour the app will not draw.
     */
    private fun paintLaunchWindow() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val mode = prefs.getString("flutter.theme.mode", "system")
        val amoled = prefs.getBoolean("flutter.theme.amoled", false)
        val night = when (mode) {
            "light" -> false
            "dark" -> true
            else -> resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        }
        val key = if (night) "flutter.theme.launchDark" else "flutter.theme.launchLight"
        if (prefs.contains(key)) window.setBackgroundDrawable(ColorDrawable(prefs.getLong(key, 0L).toInt()))
        if (Build.VERSION.SDK_INT >= 33) {
            splashScreen.setSplashScreenTheme(
                when {
                    mode == "light" -> R.style.LaunchTheme_Light
                    mode == "dark" && amoled -> R.style.LaunchTheme_Amoled
                    mode == "dark" -> R.style.LaunchTheme_Dark
                    amoled -> R.style.LaunchTheme_SystemAmoled
                    else -> R.style.LaunchTheme
                },
            )
        }
    }

    companion object {
        const val PICK_FILE = 41
        const val PICK_FOLDER = 42
        const val MULL = "com.grs.dictionary"
        const val TREE_FLAGS = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
    }
}

/** Display name of a single document, via its provider. */
fun android.content.Context.displayName(uri: Uri): String? = try {
    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { if (it.moveToFirst()) it.getString(0) else null }
} catch (_: Exception) {
    null
}
