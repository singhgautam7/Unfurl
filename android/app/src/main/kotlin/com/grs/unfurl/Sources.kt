package com.grs.unfurl

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import java.io.File
import java.io.FileNotFoundException

/**
 * Where a file came from and where it is, as far as Android says. A location is a
 * document id of Android's own storage provider ("primary:Download/abc.pdf") and is
 * only ever one Android gave exactly: a storage or Downloads document URI, or a
 * MediaStore row. Nothing is guessed from other providers' URIs, names or sizes.
 */
class Sources(private val context: Context) {
    private val resolver: ContentResolver = context.contentResolver

    /** What an arriving or picked file says about itself, for its Recents row. */
    fun describe(uri: Uri, referrer: String?, persisted: Boolean): Map<String, Any?> {
        val pkg = sender(uri, referrer)
        return mapOf(
            "authority" to uri.authority,
            "docId" to docId(uri),
            "senderPackage" to pkg,
            "sender" to pkg?.let(::label),
            "persisted" to persisted,
        )
    }

    /** The exact location, or null when Android didn't give one. */
    fun docId(uri: Uri): String? = try {
        when (uri.authority) {
            EXTERNAL -> if (DocumentsContract.isDocumentUri(context, uri)) DocumentsContract.getDocumentId(uri) else null
            DOWNLOADS ->
                if (DocumentsContract.isDocumentUri(context, uri)) {
                    DocumentsContract.getDocumentId(uri).takeIf { it.startsWith("raw:") }?.let { pathDocId(it.removePrefix("raw:")) }
                } else null
            MediaStore.AUTHORITY -> mediaDocId(uri)
            else -> null
        }
    } catch (_: Exception) {
        null
    }

    private fun mediaDocId(uri: Uri): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val cols = arrayOf(MediaStore.MediaColumns.RELATIVE_PATH, MediaStore.MediaColumns.DISPLAY_NAME, MediaStore.MediaColumns.VOLUME_NAME)
        return resolver.query(uri, cols, null, null, null)?.use { c ->
            if (!c.moveToFirst()) return@use null
            val dir = c.getString(0) ?: return@use null
            val name = c.getString(1) ?: return@use null
            val volume = c.getString(2) ?: return@use null
            // MediaStore lowercases a card's volume name; the storage provider doesn't.
            val root = if (volume == MediaStore.VOLUME_EXTERNAL_PRIMARY) "primary" else volume.uppercase()
            "$root:${dir.trim('/')}/$name".replace(":/", ":")
        }
    }

    private fun pathDocId(path: String): String? {
        val primary = Environment.getExternalStorageDirectory().path
        if (path.startsWith("$primary/")) return "primary:${path.removePrefix("$primary/")}"
        val m = Regex("^/storage/([^/]+)/(.+)$").find(path) ?: return null
        return if (m.groupValues[1] == "emulated") null else "${m.groupValues[1]}:${m.groupValues[2]}"
    }

    /**
     * The state of a file that could not be read: its exact location if known, whether
     * it is still there (null when that can't be told), and whether some app shows folders.
     */
    fun probe(uri: Uri, knownDocId: String?): Map<String, Any?> {
        val id = docId(uri) ?: knownDocId
        return mapOf(
            "docId" to id,
            "exists" to id?.let { exists(uri, it) },
            "covered" to id?.let(::covered),
            "folderApp" to (id != null && folderIntent(parent(id)).resolveActivity(context.packageManager) != null),
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    /**
     * True or false only when Android says so: a grant that is still held answers
     * through its provider; otherwise, from Android 11, an exact path in shared storage
     * can be looked up (not read) without any permission.
     */
    private fun exists(uri: Uri, id: String): Boolean? {
        val volume = id.substringBefore(':')
        val root = if (volume == "primary") Environment.getExternalStorageDirectory() else File("/storage/$volume")
        // A card that was taken out says nothing about the files on it.
        if (!root.isDirectory) return null
        val held = resolver.persistedUriPermissions.any { it.isReadPermission && it.uri == uri } ||
            DocumentsContract.isTreeUri(uri)
        if (held) {
            try {
                resolver.openFileDescriptor(uri, "r")?.use { return true }
            } catch (_: FileNotFoundException) {
                return false
            } catch (_: Exception) {
                // No access after all: look the path up below.
            }
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val rel = id.substringAfter(':')
        if (Regex("^Android/(data|obb)(/|$)", RegexOption.IGNORE_CASE).containsMatchIn(rel)) return null
        return File(root, rel).exists()
    }

    /** The file inside a folder already allowed, or null. */
    private fun covered(id: String): String? {
        for (p in resolver.persistedUriPermissions) {
            if (p.isReadPermission) inTree(p.uri, id)?.let { return it }
        }
        return null
    }

    /** [id] as a document of the granted [tree]; null when the tree doesn't hold it. */
    fun inTree(tree: Uri, id: String): String? {
        if (tree.authority != EXTERNAL || !DocumentsContract.isTreeUri(tree)) return null
        val root = DocumentsContract.getTreeDocumentId(tree)
        if (!id.startsWith(if (root.endsWith(":")) root else "$root/")) return null
        return DocumentsContract.buildDocumentUriUsingTree(tree, id).toString()
    }

    fun folderIntent(folderId: String): Intent =
        Intent(Intent.ACTION_VIEW).setDataAndType(documentUri(folderId), DocumentsContract.Document.MIME_TYPE_DIR)

    private fun parent(id: String): String {
        val rel = id.substringAfter(':')
        return id.substringBefore(':') + ":" + rel.substringBeforeLast('/', "")
    }

    /** The app that sent the file: the intent's referrer, else the URI's own provider. */
    private fun sender(uri: Uri, referrer: String?): String? {
        if (referrer != null && referrer != context.packageName && referrer !in SYSTEM) return referrer
        val authority = uri.authority ?: return null
        val pkg = context.packageManager.resolveContentProvider(authority, 0)?.packageName ?: return null
        return pkg.takeIf { it != context.packageName && it !in SYSTEM && !it.startsWith("com.android.providers.") && it != "com.android.externalstorage" }
    }

    private fun label(pkg: String): String? = try {
        val pm = context.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Exception) {
        null
    }

    companion object {
        const val EXTERNAL = "com.android.externalstorage.documents"
        const val DOWNLOADS = "com.android.providers.downloads.documents"

        /** The chooser and the shell are not where a file came from. */
        private val SYSTEM = setOf("android", "com.android.intentresolver", "com.android.shell", "com.android.systemui")

        fun documentUri(id: String): Uri = DocumentsContract.buildDocumentUri(EXTERNAL, id)
    }
}
