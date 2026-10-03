package com.grs.unfurl

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract.Document
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
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
                walk(tree, stop) { batch -> main.post { if (!stop.get()) events.success(batch) } }
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

    companion object {
        const val BATCH = 200
        val JUNK = setOf("Android", "LOST.DIR", "lost+found", "node_modules", "__MACOSX", "cache", "Cache", "thumbnails")
    }
}
