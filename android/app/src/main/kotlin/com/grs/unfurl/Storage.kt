package com.grs.unfurl

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import java.io.File

/**
 * Read-only access through the Storage Access Framework. Nothing here writes,
 * moves or deletes a user's file: the only grants taken are read grants.
 */
class Storage(private val context: Context) {
    private val resolver = context.contentResolver

    /** Name, size, type and modified time of one document, or null when it is gone or no longer readable. */
    fun stat(uri: Uri): Map<String, Any?>? = try {
        val cols = arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE, DocumentsContract.Document.COLUMN_LAST_MODIFIED)
        resolver.query(uri, cols, null, null, null)?.use { c ->
            if (!c.moveToFirst()) return null
            val modifiedCol = c.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            mapOf(
                "uri" to uri.toString(),
                "name" to c.getString(0),
                "size" to if (c.isNull(1)) 0L else c.getLong(1),
                "modified" to if (modifiedCol < 0 || c.isNull(modifiedCol)) 0L else c.getLong(modifiedCol),
                "mime" to resolver.getType(uri),
            )
        }
    } catch (_: Exception) {
        null
    }

    /**
     * A raw file descriptor for the document, read via `/proc/self/fd/<fd>` from Dart
     * (PDFium, zip and fingerprint reads all seek). Closed with [closeFd].
     */
    fun openFd(uri: Uri): Int? = try {
        resolver.openFileDescriptor(uri, "r")?.let { pfd ->
            if (pfd.statSize >= 0) {
                pfd.detachFd()
            } else {
                // A stream, not a file (some providers pipe their data): copy
                // it to an unlinked cache file so readers can seek.
                val tmp = File.createTempFile("open", null, context.cacheDir)
                try {
                    ParcelFileDescriptor.AutoCloseInputStream(pfd).use { input -> tmp.outputStream().use { input.copyTo(it) } }
                    ParcelFileDescriptor.open(tmp, ParcelFileDescriptor.MODE_READ_ONLY).detachFd()
                } finally {
                    tmp.delete()
                }
            }
        }
    } catch (_: Exception) {
        null
    }

    fun closeFd(fd: Int): Boolean = try {
        ParcelFileDescriptor.adoptFd(fd).close()
        true
    } catch (_: Exception) {
        false
    }

    /** Keeps a picked folder readable across restarts and describes it. */
    fun takeFolder(tree: Uri): Map<String, Any?> {
        resolver.takePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val docId = DocumentsContract.getTreeDocumentId(tree)
        val name = context.displayName(DocumentsContract.buildDocumentUriUsingTree(tree, docId))
        return mapOf("uri" to tree.toString(), "name" to (name ?: docId.substringAfterLast(':').substringAfterLast('/')), "path" to readablePath(docId))
    }

    /** Remove access: the persisted grant goes; the folder itself is untouched. */
    fun release(tree: String): Boolean = try {
        resolver.releasePersistableUriPermission(Uri.parse(tree), Intent.FLAG_GRANT_READ_URI_PERMISSION)
        true
    } catch (_: Exception) {
        false
    }

    /** "primary:Documents/Papers" becomes "Documents › Papers". */
    private fun readablePath(docId: String): String =
        docId.substringAfter(':').split('/').filter { it.isNotEmpty() }.joinToString(" › ")
}
