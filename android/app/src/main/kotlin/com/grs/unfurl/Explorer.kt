package com.grs.unfurl

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.os.storage.StorageManager
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * The Files tab's view of the device: all-files access, storage volumes, quick-access
 * locations and directory listings. Read-only: nothing here creates, renames, moves or
 * deletes a file. Everything works without all-files access too; it then answers
 * "no access" and the app falls back to folders picked through the system picker.
 */
class Explorer(private val activity: Activity) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val pool = Executors.newFixedThreadPool(2)

    fun register(messenger: BinaryMessenger) = EventChannel(messenger, "unfurl/list").setStreamHandler(this)

    // ------------------------------------------------------------ access

    /** Android 11+: All files access. Android 10 and below: the read storage permission. */
    fun hasAccess(): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        Environment.isExternalStorageManager()
    } else {
        activity.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Opens Android's All files access page for Unfurl (falling back to the general list),
     * or on Android 10 and below asks for the read permission. The result is read on resume.
     */
    fun requestAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            activity.requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE), REQUEST_READ)
            return true
        }
        val own = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:${activity.packageName}"))
        return try {
            activity.startActivity(own)
            true
        } catch (_: ActivityNotFoundException) {
            try {
                activity.startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                true
            } catch (_: ActivityNotFoundException) {
                false
            }
        }
    }

    // ------------------------------------------------------------ roots

    /** Internal storage and every mounted SD card or USB drive, with space used. */
    fun volumes(): List<Map<String, Any?>> {
        val sm = activity.getSystemService(Context.STORAGE_SERVICE) as StorageManager
        val out = ArrayList<Map<String, Any?>>()
        for (v in sm.storageVolumes) {
            val dir = volumeDir(v) ?: continue
            val state = v.state
            val mounted = state == Environment.MEDIA_MOUNTED || state == Environment.MEDIA_MOUNTED_READ_ONLY
            if (!mounted && v.isPrimary) continue
            val description = v.getDescription(activity) ?: ""
            val usb = description.contains("USB", ignoreCase = true)
            var total = 0L
            var free = 0L
            if (mounted) {
                try {
                    val fs = StatFs(dir.path)
                    total = fs.totalBytes
                    free = fs.availableBytes
                } catch (_: Exception) {
                }
            }
            out.add(
                mapOf(
                    "path" to dir.path,
                    "kind" to if (v.isPrimary) "internal" else if (usb) "usb" else "sd",
                    "label" to description,
                    "mounted" to mounted,
                    "readable" to (mounted && dir.canRead()),
                    "total" to total,
                    "free" to free,
                ),
            )
        }
        return out
    }

    private fun volumeDir(v: android.os.storage.StorageVolume): File? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) return v.directory
        // Before Android 11 the path is only on the app-specific directories.
        return try {
            v.javaClass.getMethod("getPathFile").invoke(v) as? File
        } catch (_: Exception) {
            if (v.isPrimary) Environment.getExternalStorageDirectory() else null
        }
    }

    /**
     * The standard places documents land, relative to internal storage, keeping only the
     * ones that exist. Each entry lists alternatives, newest location first.
     */
    fun quickAccess(): List<Map<String, Any?>> {
        val root = Environment.getExternalStorageDirectory()
        val out = ArrayList<Map<String, Any?>>()
        for ((id, candidates) in QUICK) {
            val dir = candidates.map { File(root, it) }.firstOrNull { it.isDirectory } ?: continue
            // Files, not folders: the board's "142" is the folder's "142 files".
            out.add(mapOf("id" to id, "path" to dir.path, "count" to (dir.listFiles()?.count { it.isFile && !it.name.startsWith(".") } ?: 0)))
        }
        return out
    }

    // ------------------------------------------------------------ listing

    private class Snapshot(val stamp: Long, val names: Array<String>, val dirs: BooleanArray, val sizes: LongArray, val times: LongArray)

    /** Recently listed folders, newest last, bounded by total entries. */
    private val cache = object : LinkedHashMap<String, Snapshot>(16, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Snapshot>): Boolean {
            var total = 0
            for (s in values) total += s.names.size
            return total > CACHE_ENTRIES && size > 1
        }
    }

    /**
     * One event stream for every listing, each event tagged with its listing id: an
     * EventChannel carries one stream at a time, and folders open and close faster
     * than a per-folder stream could be torn down.
     */
    private var sink: EventChannel.EventSink? = null
    private val running = HashMap<Int, AtomicBoolean>()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        synchronized(running) { running.values.forEach { it.set(true) } }
    }

    fun cancel(id: Int) {
        synchronized(running) { running.remove(id)?.set(true) }
    }

    /** Lists [path] for listing [id]: a head, then the first page fast and the rest in larger pages. */
    fun start(id: Int, path: String, sort: String, hidden: Boolean) {
        val stop = AtomicBoolean(false)
        synchronized(running) { running[id] = stop }
        pool.execute {
            fun send(v: Map<String, Any?>) = main.post { if (!stop.get()) sink?.success(v + ("id" to id)) }
            try {
                val problem = problemWith(File(path))
                if (problem != null) {
                    send(mapOf("kind" to "error", "code" to problem))
                    return@execute
                }
                val snap = snapshot(File(path), stop) ?: return@execute
                val order = sorted(snap, sort, hidden)
                send(mapOf("kind" to "head", "total" to order.size, "dirs" to order.count { snap.dirs[it] }))
                var from = 0
                var page = FIRST_PAGE
                while (from < order.size && !stop.get()) {
                    val to = minOf(order.size, from + page)
                    val rows = ArrayList<List<Any>>(to - from)
                    for (k in from until to) {
                        val i = order[k]
                        rows.add(listOf(snap.names[i], snap.dirs[i], snap.sizes[i], snap.times[i]))
                    }
                    send(mapOf("kind" to "page", "from" to from, "rows" to rows))
                    from = to
                    page = NEXT_PAGE
                }
                send(mapOf("kind" to "done"))
            } catch (e: Exception) {
                send(mapOf("kind" to "error", "code" to "unreadable"))
            } finally {
                synchronized(running) { if (running[id] === stop) running.remove(id) }
            }
        }
    }

    /** Why a folder can't be listed, as a state the Files screens show, or null. */
    private fun problemWith(dir: File): String? {
        val rel = dir.path.removePrefix(Environment.getExternalStorageDirectory().path).trim('/')
        if (rel.equals("Android/data", true) || rel.equals("Android/obb", true) ||
            rel.startsWith("Android/data/", true) || rel.startsWith("Android/obb/", true)
        ) {
            return "restricted"
        }
        if (!hasAccess()) return "denied"
        val volume = volumes().firstOrNull { dir.path == it["path"] || dir.path.startsWith("${it["path"]}/") }
        if (volume == null) return if (dir.exists()) "unreadable" else "removed"
        if (volume["mounted"] != true) return "removed"
        if (!dir.exists()) return "missing"
        if (!dir.isDirectory || !dir.canRead()) return "unreadable"
        return null
    }

    /** Stats run on several threads: shared storage is served by a FUSE daemon that answers in parallel. */
    private val stats = Executors.newFixedThreadPool(STAT_THREADS)

    private fun snapshot(dir: File, stop: AtomicBoolean): Snapshot? {
        val stamp = dir.lastModified()
        synchronized(cache) { cache[dir.path]?.takeIf { it.stamp == stamp }?.let { return it } }
        val t0 = System.nanoTime()
        // One readdir for the names, then one stat per entry, spread over threads.
        val names = dir.list() ?: return null
        val t1 = System.nanoTime()
        val n = names.size
        val dirs = BooleanArray(n)
        val sizes = LongArray(n)
        val times = LongArray(n)
        val chunk = maxOf(64, (n + STAT_THREADS - 1) / STAT_THREADS)
        val jobs = (0 until n step chunk).map { from ->
            stats.submit {
                for (k in from until minOf(n, from + chunk)) {
                    if (stop.get()) return@submit
                    val f = File(dir, names[k])
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val a = java.nio.file.Files.readAttributes(f.toPath(), java.nio.file.attribute.BasicFileAttributes::class.java)
                            dirs[k] = a.isDirectory
                            sizes[k] = if (a.isDirectory) 0L else a.size()
                            times[k] = a.lastModifiedTime().toMillis()
                        } catch (_: Exception) {
                        }
                    } else {
                        dirs[k] = f.isDirectory
                        sizes[k] = if (dirs[k]) 0L else f.length()
                        times[k] = f.lastModified()
                    }
                }
            }
        }
        jobs.forEach { it.get() }
        if (stop.get()) return null
        android.util.Log.d("UnfurlExplorer", "list ${dir.path}: $n names ${(t1 - t0) / 1_000_000} ms, stats ${(System.nanoTime() - t1) / 1_000_000} ms")
        val snap = Snapshot(stamp, names, dirs, sizes, times)
        synchronized(cache) { cache[dir.path] = snap }
        return snap
    }

    /** Indices in display order: folders first, then the chosen sort. */
    private fun sorted(s: Snapshot, sort: String, hidden: Boolean): List<Int> {
        val idx = s.names.indices.filter { hidden || !s.names[it].startsWith(".") }
        val byName = Comparator<Int> { a, b -> natural(s.names[a], s.names[b]) }
        val within: Comparator<Int> = when (sort) {
            "modified" -> compareByDescending<Int> { s.times[it] }.then(byName)
            "size" -> compareByDescending<Int> { s.sizes[it] }.then(byName)
            "type" -> compareBy<Int> { s.names[it].substringAfterLast('.', "").lowercase() }.then(byName)
            else -> byName
        }
        return idx.sortedWith(compareByDescending<Int> { s.dirs[it] }.then(within))
    }

    /** "scan-2" before "scan-10", case folded. */
    private fun natural(a: String, b: String): Int {
        var i = 0
        var j = 0
        while (i < a.length && j < b.length) {
            val ca = a[i]
            val cb = b[j]
            if (ca.isDigit() && cb.isDigit()) {
                var ei = i
                while (ei < a.length && a[ei].isDigit()) ei++
                var ej = j
                while (ej < b.length && b[ej].isDigit()) ej++
                val na = a.substring(i, ei).trimStart('0')
                val nb = b.substring(j, ej).trimStart('0')
                if (na.length != nb.length) return na.length - nb.length
                val c = na.compareTo(nb)
                if (c != 0) return c
                i = ei
                j = ej
            } else {
                val c = ca.lowercaseChar().compareTo(cb.lowercaseChar())
                if (c != 0) return c
                i++
                j++
            }
        }
        return (a.length - i) - (b.length - j)
    }

    /** "12 files · 9 readable" for a folder row: direct children only, cached by stamp. */
    private val summaries = HashMap<String, Pair<Long, IntArray>>()

    fun summary(path: String, readable: Set<String>): Map<String, Int>? {
        val dir = File(path)
        if (problemWith(dir) != null) return null
        val stamp = dir.lastModified()
        val known = synchronized(summaries) { summaries[path]?.takeIf { it.first == stamp }?.second }
        val counts = known ?: run {
            var files = 0
            var ok = 0
            var folders = 0
            for (f in dir.listFiles() ?: emptyArray()) {
                if (f.name.startsWith(".")) continue
                if (f.isDirectory) { folders++; continue }
                files++
                if (f.name.substringAfterLast('.', "").lowercase() in readable) ok++
            }
            intArrayOf(files, ok, folders).also { synchronized(summaries) { summaries[path] = stamp to it } }
        }
        return mapOf("files" to counts[0], "readable" to counts[1], "folders" to counts[2])
    }

    fun summaryAsync(path: String, readable: Set<String>, done: (Map<String, Int>?) -> Unit) =
        pool.execute { val r = summary(path, readable); main.post { done(r) } }

    // ------------------------------------------------------------ sharing

    /**
     * A content URI another app can open for a file path: the MediaStore entry when the
     * media scanner knows it, else Unfurl's own read-only FileProvider. Never a file:// URI.
     */
    fun contentUriFor(path: String): Uri? {
        val file = File(path)
        if (!file.isFile) return null
        try {
            activity.contentResolver.query(
                MediaStore.Files.getContentUri("external"),
                arrayOf(MediaStore.Files.FileColumns._ID),
                "${MediaStore.Files.FileColumns.DATA} = ?",
                arrayOf(file.path),
                null,
            )?.use { c ->
                if (c.moveToFirst()) return ContentUris.withAppendedId(MediaStore.Files.getContentUri("external"), c.getLong(0))
            }
        } catch (_: Exception) {
        }
        return try {
            FileProvider.getUriForFile(activity, "${activity.packageName}.files", file)
        } catch (_: IllegalArgumentException) {
            null
        }
    }

    companion object {
        const val REQUEST_READ = 41
        private const val FIRST_PAGE = 60
        private const val NEXT_PAGE = 300
        private const val CACHE_ENTRIES = 40_000
        private val STAT_THREADS = Runtime.getRuntime().availableProcessors().coerceIn(2, 8)

        /** Quick access, in the spec's order. Paths are relative to internal storage. */
        private val QUICK = listOf(
            "downloads" to listOf("Download"),
            "documents" to listOf("Documents"),
            "whatsapp" to listOf(
                "Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents",
                "WhatsApp/Media/WhatsApp Documents",
            ),
            "telegram" to listOf(
                "Android/media/org.telegram.messenger/Telegram/Telegram Documents",
                "Download/Telegram",
                "Telegram/Telegram Documents",
                "Telegram",
            ),
            "bluetooth" to listOf("Download/Bluetooth", "Bluetooth"),
            "screenshots" to listOf("Pictures/Screenshots", "DCIM/Screenshots"),
        )
    }
}
