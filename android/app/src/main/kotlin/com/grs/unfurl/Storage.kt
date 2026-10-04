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

    /**
     * Name, size, type and modified time of one document, or null when it is gone or no
     * longer readable. File managers, MediaStore and SAF all name these columns differently
     * (or not at all), so every column is asked for and whichever exist are read; a provider
     * that refuses the query still answers through the file itself.
     */
    fun stat(uri: Uri): Map<String, Any?>? {
        if (uri.scheme == "file") {
            // A path from the Files tab (all-files access): read straight from the file.
            val f = File(uri.path ?: return null)
            if (!f.isFile || !f.canRead()) return null
            val ext = f.name.substringAfterLast('.', "").lowercase()
            return mapOf(
                "uri" to uri.toString(),
                "name" to f.name,
                "size" to f.length(),
                "modified" to f.lastModified(),
                "mime" to android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext),
            )
        }
        val queried = try {
            resolver.query(uri, null, null, null, null)?.use { c ->
                if (!c.moveToFirst()) return@use null
                fun col(vararg names: String) = names.map(c::getColumnIndex).firstOrNull { it >= 0 && !c.isNull(it) }
                val modified = col(DocumentsContract.Document.COLUMN_LAST_MODIFIED)?.let(c::getLong)
                    ?: col("date_modified")?.let { c.getLong(it) * 1000 } // MediaStore keeps seconds
                    ?: 0L
                mapOf(
                    "name" to col(OpenableColumns.DISPLAY_NAME, "_display_name", "title")?.let(c::getString),
                    "size" to (col(OpenableColumns.SIZE, "_size")?.let(c::getLong) ?: -1L),
                    "modified" to modified,
                )
            }
        } catch (_: Exception) {
            null
        }
        // Readable at all? (Also the size when the provider didn't say.)
        val size = try {
            resolver.openFileDescriptor(uri, "r")?.use { it.statSize } ?: return null
        } catch (_: Exception) {
            return null
        }
        return mapOf(
            "uri" to uri.toString(),
            "name" to (queried?.get("name") ?: uri.lastPathSegment?.substringAfterLast('/') ?: "Document"),
            "size" to ((queried?.get("size") as Long?)?.takeIf { it >= 0 } ?: size.coerceAtLeast(0)),
            "modified" to (queried?.get("modified") ?: 0L),
            "mime" to resolver.getType(uri),
        )
    }

    /**
     * A raw file descriptor for the document, read via `/proc/self/fd/<fd>` from Dart
     * (PDFium, zip and fingerprint reads all seek). Closed with [closeFd].
     */
    fun openFd(uri: Uri): Int? = try {
        if (uri.scheme == "file") {
            ParcelFileDescriptor.open(File(uri.path!!), ParcelFileDescriptor.MODE_READ_ONLY).detachFd()
        } else
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
