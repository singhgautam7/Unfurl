package com.grs.unfurl

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Walks a granted folder tree with DocumentsContract child queries (never
 * DocumentFile.listFiles, which costs one IPC per property) on a background
 * thread, and streams what it finds in batches so the UI fills progressively.
 */
class Scanner(private val context: Context) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val pool = Executors.newSingleThreadExecutor()
    private var cancel: AtomicBoolean? = null

    fun register(messenger: BinaryMessenger) = EventChannel(messenger, "unfurl/scan").setStreamHandler(this)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val tree = Uri.parse((arguments as Map<*, *>)["uri"] as String)
        val stop = AtomicBoolean(false).also { cancel = it }
        pool.execute {
            try {
                val emit: (List<Map<String, Any?>>) -> Unit = { batch -> main.post { if (!stop.get()) events.success(batch) } }
                when (tree.scheme) {
                    "file" -> walkPath(File(tree.path!!), stop, emit)
                    "device" -> walkMediaStore(stop, emit)
                    else -> walk(tree, stop, emit)
                }
                main.post { if (!stop.get()) events.endOfStream() }
            } catch (e: Exception) {
                main.post { if (!stop.get()) events.error("access", e.message, null) }
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        cancel?.set(true)
    }

    private fun walk(tree: Uri, stop: AtomicBoolean, emit: (List<Map<String, Any?>>) -> Unit) {
        val resolver = context.contentResolver
        val cols = arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME, Document.COLUMN_MIME_TYPE, Document.COLUMN_SIZE, Document.COLUMN_LAST_MODIFIED)
        val queue = ArrayDeque<Pair<String, String>>() // docId, relative dir
        queue.add(DocumentsContract.getTreeDocumentId(tree) to "")
        var batch = ArrayList<Map<String, Any?>>(BATCH)
        while (queue.isNotEmpty() && !stop.get()) {
            val (parent, rel) = queue.removeFirst()
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
            resolver.query(children, cols, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0)
                    val name = c.getString(1) ?: continue
                    if (name.startsWith('.') || name in JUNK) continue
                    val dir = c.getString(2) == Document.MIME_TYPE_DIR
                    batch.add(
                        mapOf(
                            "docId" to id,
                            "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                            "parent" to rel,
                            "name" to name,
                            "mime" to c.getString(2),
                            "dir" to dir,
                            "size" to if (c.isNull(3)) 0L else c.getLong(3),
                            "modified" to if (c.isNull(4)) 0L else c.getLong(4),
                        ),
                    )
                    if (dir) queue.add(id to if (rel.isEmpty()) name else "$rel/$name")
                    if (batch.size >= BATCH) {
                        emit(batch)
                        batch = ArrayList(BATCH)
                    }
                }
            } ?: throw SecurityException("No access to $tree")
        }
        if (batch.isNotEmpty()) emit(batch)
    }

    /**
     * A folder added by path from the Files tab (all-files access): the same rows as a
     * tree walk, the relative path standing in for the document id.
     */
    private fun walkPath(root: File, stop: AtomicBoolean, emit: (List<Map<String, Any?>>) -> Unit) {
        if (!root.isDirectory || !root.canRead()) throw SecurityException("No access to $root")
        val mime = android.webkit.MimeTypeMap.getSingleton()
        val queue = ArrayDeque<Pair<File, String>>()
        queue.add(root to "")
        var batch = ArrayList<Map<String, Any?>>(BATCH)
        while (queue.isNotEmpty() && !stop.get()) {
            val (dir, rel) = queue.removeFirst()
            for (f in dir.listFiles() ?: continue) {
                val name = f.name
                if (name.startsWith('.') || name in JUNK) continue
                val isDir = f.isDirectory
                val path = if (rel.isEmpty()) name else "$rel/$name"
                batch.add(
                    mapOf(
                        "docId" to path,
                        "uri" to Uri.fromFile(f).toString(),
                        "parent" to rel,
                        "name" to name,
                        "mime" to if (isDir) null else mime.getMimeTypeFromExtension(name.substringAfterLast('.', "").lowercase()),
                        "dir" to isDir,
                        "size" to if (isDir) 0L else f.length(),
                        "modified" to f.lastModified(),
                    ),
                )
                if (isDir) queue.add(f to path)
                if (batch.size >= BATCH) {
                    emit(batch)
                    batch = ArrayList(BATCH)
                }
            }
        }
        if (batch.isNotEmpty()) emit(batch)
    }

    /**
     * "Find books across this device": every PDF and EPUB MediaStore knows, on every
     * volume, skipping pending, trashed and hidden-folder items and app-private folders.
     * Rows look like a walk's, the MediaStore id standing in for the document id.
     */
    private fun walkMediaStore(stop: AtomicBoolean, emit: (List<Map<String, Any?>>) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && !android.os.Environment.isExternalStorageManager()) {
            throw SecurityException("No all-files access")
        }
        val volumes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) MediaStore.getExternalVolumeNames(context) else setOf("external")
        val cols = arrayOf(
            MediaStore.Files.FileColumns._ID,
            MediaStore.Files.FileColumns.DATA,
            MediaStore.Files.FileColumns.MIME_TYPE,
            MediaStore.Files.FileColumns.SIZE,
            MediaStore.Files.FileColumns.DATE_MODIFIED,
        )
        val sel = StringBuilder(
            "(${MediaStore.Files.FileColumns.MIME_TYPE} IN ('application/pdf', 'application/epub+zip') " +
                "OR ${MediaStore.Files.FileColumns.DATA} LIKE '%.pdf' OR ${MediaStore.Files.FileColumns.DATA} LIKE '%.epub') " +
                "AND ${MediaStore.Files.FileColumns.DATA} NOT LIKE '%/.%' " +
                "AND ${MediaStore.Files.FileColumns.DATA} NOT LIKE '%/Android/data/%' " +
                "AND ${MediaStore.Files.FileColumns.DATA} NOT LIKE '%/Android/obb/%'",
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) sel.append(" AND ${MediaStore.MediaColumns.IS_PENDING} = 0")
        var batch = ArrayList<Map<String, Any?>>(BATCH)
        for (volume in volumes) {
            if (stop.get()) return
            // Trashed items are left out by default from Android 11.
            context.contentResolver.query(MediaStore.Files.getContentUri(volume), cols, sel.toString(), null, null)?.use { c ->
                while (c.moveToNext() && !stop.get()) {
                    val path = c.getString(1) ?: continue
                    val f = File(path)
                    val root = rootOf(path)
                    val rel = f.parent?.removePrefix(root)?.trim('/') ?: ""
                    batch.add(
                        mapOf(
                            "docId" to "$volume:${c.getLong(0)}",
                            "uri" to Uri.fromFile(f).toString(),
                            "parent" to rel,
                            "name" to f.name,
                            "mime" to c.getString(2),
                            "dir" to false,
                            "size" to if (c.isNull(3)) 0L else c.getLong(3),
                            "modified" to if (c.isNull(4)) 0L else c.getLong(4) * 1000,
                        ),
                    )
                    if (batch.size >= BATCH) {
                        emit(batch)
                        batch = ArrayList(BATCH)
                    }
                }
            }
        }
        if (batch.isNotEmpty()) emit(batch)
    }

    /** "/storage/emulated/0" or "/storage/1A2B-3C4D" for a path on a volume. */
    private fun rootOf(path: String): String {
        val parts = path.split('/')
        return if (parts.size > 3 && parts[2] == "emulated") parts.take(4).joinToString("/") else parts.take(3).joinToString("/")
    }

    companion object {
        /** MediaStore's change counter: a rescan is skipped while it hasn't moved. */
        fun generation(context: Context): Long =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) MediaStore.getGeneration(context, MediaStore.VOLUME_EXTERNAL) else -1L

        const val BATCH = 200
        val JUNK = setOf("Android", "LOST.DIR", "lost+found", "node_modules", "__MACOSX", "cache", "Cache", "thumbnails")
    }
}
