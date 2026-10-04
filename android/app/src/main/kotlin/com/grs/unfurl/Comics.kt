package com.grs.unfurl

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import com.github.junrar.Archive
import com.github.junrar.exception.UnsupportedRarV5Exception
import com.github.junrar.io.SeekableReadOnlyByteChannel
import com.github.junrar.rarfile.FileHeader
import com.github.junrar.volume.Volume
import com.github.junrar.volume.VolumeManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.apache.commons.compress.archivers.sevenz.SevenZArchiveEntry
import org.apache.commons.compress.archivers.sevenz.SevenZFile
import org.apache.commons.compress.archivers.tar.TarArchiveEntry
import org.apache.commons.compress.archivers.tar.TarFile
import org.apache.commons.compress.archivers.zip.ZipArchiveEntry
import org.apache.commons.compress.archivers.zip.ZipArchiveInputStream
import org.apache.commons.compress.archivers.zip.ZipFile
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.channels.Channels
import java.nio.channels.FileChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.LinkedBlockingDeque
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Comic archives (CBZ, CBR, CB7, CBT), read in place through the descriptor the
 * system hands over: the entry list without extracting anything, then one page at
 * a time on demand. The archive type comes from the file's magic bytes, so a `.cbr`
 * that is really a zip still opens. Read-only; nothing is written next to the file.
 *
 * zip, 7z and tar: Apache Commons Compress (Apache-2.0) with XZ for Java (0BSD).
 * rar: junrar (UnRAR licence, extraction only), RAR 1.5 to 4.x; RAR5 reports
 * `unsupported`.
 */
class Comics(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val books = ConcurrentHashMap<Int, Book>()
    private val nextId = AtomicInteger(1)

    /** Newest request first: the page on screen jumps the prefetch queue. */
    private val io = ThreadPoolExecutor(1, 1, 30, TimeUnit.SECONDS, LinkedBlockingDeque<Runnable>().let { LifoQueue(it) })

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "comicOpen" -> run(result) { open(Uri.parse(call.argument<String>("uri")!!)) }
            "comicPage" -> {
                val book = books[call.argument<Int>("id")!!] ?: return true.also { result.success(null) }
                val name = call.argument<String>("name")!!
                val token = book.token.get()
                run(result) { if (book.closed || token != book.token.get() && call.argument<Boolean>("cancellable") == true) null else book.read(name) }
            }
            "comicCancel" -> {
                // Drops queued prefetches: they run, see the new token and return at once.
                books[call.argument<Int>("id")!!]?.token?.incrementAndGet()
                result.success(null)
            }
            "comicClose" -> {
                books.remove(call.argument<Int>("id")!!)?.let { book ->
                    book.closed = true
                    io.execute { book.close() }
                }
                result.success(null)
            }
            else -> return false
        }
        return true
    }

    private fun run(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Problem) {
                main.post { result.error(e.code, e.message, null) }
            } catch (e: LinkageError) {
                // Commons Compress needs java.nio.file (Android 8+).
                main.post { result.error("unsupported", "Needs Android 8 or later", null) }
            } catch (e: Exception) {
                main.post { result.error("damaged", e.message, null) }
            }
        }
    }

    private class Problem(val code: String, message: String) : Exception(message)

    private fun open(uri: Uri): Map<String, Any?> {
        val pfd = if (uri.scheme == "file") {
            ParcelFileDescriptor.open(File(uri.path!!), ParcelFileDescriptor.MODE_READ_ONLY)
        } else {
            context.contentResolver.openFileDescriptor(uri, "r") ?: throw Problem("missing", "Can't open")
        }
        val channel = FileInputStream(pfd.fileDescriptor).channel
        val head = ByteBuffer.allocate(264)
        channel.read(head, 0)
        val magic = head.array()
        fun at(i: Int, vararg bytes: Int) = bytes.withIndex().all { (k, b) -> magic[i + k] == b.toByte() }
        val book: Book = try {
            when {
                at(0, 0x50, 0x4B) -> ZipBook(channel, pfd, context.cacheDir)
                at(0, 0x52, 0x61, 0x72, 0x21, 0x1A, 0x07, 0x01, 0x00) -> throw Problem("unsupported", "RAR 5 archive")
                at(0, 0x52, 0x61, 0x72, 0x21) -> RarBook(channel, pfd)
                at(0, 0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C) -> SevenBook(channel, pfd)
                String(magic, 257, 5, Charsets.US_ASCII) == "ustar" -> TarBook(channel, pfd)
                else -> throw Problem("unsupported", "Not a comic archive")
            }
        } catch (e: Exception) {
            channel.close()
            pfd.close()
            throw e
        }
        val id = nextId.getAndIncrement()
        books[id] = book
        return mapOf(
            "id" to id,
            "kind" to book.kind,
            "names" to book.names,
            "info" to book.info,
            "damaged" to book.damaged,
            "total" to book.total,
        )
    }

    private abstract class Book(val channel: FileChannel, val pfd: ParcelFileDescriptor) {
        @Volatile var closed = false
        val token = AtomicInteger()
        abstract val kind: String
        /** Image entries, in archive order (Dart sorts them naturally). */
        abstract val names: List<String>
        /** ComicInfo.xml, if the archive has one. */
        var info: String? = null
        /** Some pages could not be read (only the readable ones are listed). */
        var damaged = false
        /** Entries the archive claims, when it could be listed at all. */
        var total: Int? = null
        abstract fun read(name: String): ByteArray?
        open fun close() {
            channel.close()
            pfd.close()
        }

        protected fun isImage(name: String): Boolean {
            val n = name.lowercase()
            if (n.startsWith("__macosx/") || n.substringAfterLast('/').startsWith(".")) return false
            return IMAGE.any { n.endsWith(it) }
        }

        protected fun isInfo(name: String) = name.substringAfterLast('/').equals("ComicInfo.xml", ignoreCase = true)
    }

    private class ZipBook(channel: FileChannel, pfd: ParcelFileDescriptor, cache: File) : Book(channel, pfd) {
        override val kind = "zip"
        private var zip: ZipFile? = null
        private val entries = LinkedHashMap<String, ZipArchiveEntry>()
        /** A damaged zip (no central directory): readable pages, copied to the app's cache. */
        private var salvage: File? = null
        override val names: List<String>

        /** ZipFile closes its channel (and so the descriptor) when it fails; it gets its own copy. */
        private val dup: ParcelFileDescriptor = pfd.dup()

        init {
            names = try {
                val z = ZipFile.builder().setSeekableByteChannel(FileInputStream(dup.fileDescriptor).channel).get()
                zip = z
                for (e in z.entries) {
                    if (e.isDirectory) continue
                    if (isInfo(e.name)) info = z.getInputStream(e).use { String(it.readBytes(), Charsets.UTF_8) }
                    if (isImage(e.name)) entries[e.name] = e
                }
                total = entries.size
                entries.keys.toList()
            } catch (e: IOException) {
                salvageLocal(cache)
            }
        }

        /** Walks the local headers from the start and keeps every entry that reads in full. */
        private fun salvageLocal(cache: File): List<String> {
            val dir = File(cache, "comic-salvage-${System.nanoTime()}").apply { mkdirs() }
            salvage = dir
            val out = ArrayList<String>()
            damaged = true
            try {
                ZipArchiveInputStream(Channels.newInputStream(channel.position(0))).use { zin ->
                    while (true) {
                        val e = zin.nextEntry ?: break
                        if (e.isDirectory || !isImage(e.name)) continue
                        val bytes = zin.readBytes()
                        File(dir, out.size.toString()).writeBytes(bytes)
                        out.add(e.name)
                    }
                }
            } catch (_: Exception) {
                // Stop at the first entry that doesn't read: everything before it is kept.
            }
            if (out.isEmpty()) throw Problem("damaged", "No readable pages")
            return out
        }

        override fun read(name: String): ByteArray? {
            salvage?.let { dir -> return File(dir, names.indexOf(name).toString()).takeIf { it.exists() }?.readBytes() }
            val e = entries[name] ?: return null
            return zip!!.getInputStream(e).use { it.readBytes() }
        }

        override fun close() {
            zip?.close()
            runCatching { dup.close() }
            salvage?.deleteRecursively()
            super.close()
        }
    }

    private class SevenBook(channel: FileChannel, pfd: ParcelFileDescriptor) : Book(channel, pfd) {
        override val kind = "7z"
        private val seven = SevenZFile.builder().setSeekableByteChannel(channel).get()
        private val entries = LinkedHashMap<String, SevenZArchiveEntry>()
        override val names: List<String>

        init {
            for (e in seven.entries) {
                if (e.isDirectory || !e.hasStream()) continue
                if (isInfo(e.name)) info = seven.getInputStream(e).use { String(it.readBytes(), Charsets.UTF_8) }
                if (isImage(e.name)) entries[e.name] = e
            }
            total = entries.size
            names = entries.keys.toList()
        }

        override fun read(name: String): ByteArray? = entries[name]?.let { e -> seven.getInputStream(e).use { it.readBytes() } }

        override fun close() {
            seven.close()
            super.close()
        }
    }

    /** Tar has no index: TarFile walks the headers once, then reads entries by position. */
    private class TarBook(channel: FileChannel, pfd: ParcelFileDescriptor) : Book(channel, pfd) {
        override val kind = "tar"
        private val dup: ParcelFileDescriptor = pfd.dup()
        private val tar = TarFile(FileInputStream(dup.fileDescriptor).channel)
        private val entries = LinkedHashMap<String, TarArchiveEntry>()
        override val names: List<String>

        init {
            for (e in tar.entries) {
                if (!e.isFile) continue
                if (isInfo(e.name)) info = tar.getInputStream(e).use { String(it.readBytes(), Charsets.UTF_8) }
                else if (isImage(e.name)) entries[e.name] = e
            }
            total = entries.size
            names = entries.keys.toList()
        }

        override fun read(name: String): ByteArray? = entries[name]?.let { e -> tar.getInputStream(e).use { it.readBytes() } }

        override fun close() {
            tar.close()
            runCatching { dup.close() }
            super.close()
        }
    }

    private class RarBook(channel: FileChannel, pfd: ParcelFileDescriptor) : Book(channel, pfd) {
        override val kind = "rar"
        private val archive: Archive
        private val headers = LinkedHashMap<String, FileHeader>()
        override val names: List<String>

        init {
            archive = try {
                Archive(ChannelVolumeManager(channel), null, null)
            } catch (e: UnsupportedRarV5Exception) {
                throw Problem("unsupported", "RAR 5 archive")
            }
            if (archive.isEncrypted) throw Problem("unsupported", "Password-protected archive")
            for (h in archive.fileHeaders) {
                if (h.isDirectory) continue
                val name = h.fileName.replace('\\', '/')
                if (isInfo(name)) info = String(extract(h), Charsets.UTF_8)
                if (isImage(name)) headers[name] = h
            }
            total = headers.size
            names = headers.keys.toList()
        }

        private fun extract(h: FileHeader): ByteArray = ByteArrayOutputStream(h.fullUnpackSize.toInt().coerceAtLeast(0)).also { archive.extractFile(h, it) }.toByteArray()

        override fun read(name: String): ByteArray? = headers[name]?.let(::extract)

        override fun close() {
            archive.close()
            super.close()
        }
    }

    /** junrar reads one volume, through our descriptor's channel (no path, no copy). */
    private class ChannelVolumeManager(private val file: FileChannel) : VolumeManager {
        override fun nextVolume(archive: Archive, last: Volume?): Volume? = if (last != null) null else object : Volume {
            override fun getChannel(): SeekableReadOnlyByteChannel = ChannelReader(file)
            override fun getLength(): Long = file.size()
            override fun getArchive(): Archive = archive
        }
    }

    private class ChannelReader(private val channel: FileChannel) : SeekableReadOnlyByteChannel {
        private var position = 0L
        override fun getPosition(): Long = position
        override fun setPosition(pos: Long) {
            position = pos
        }
        override fun read(): Int {
            val b = ByteBuffer.allocate(1)
            return if (channel.read(b, position) <= 0) -1 else { position++; b.array()[0].toInt() and 0xFF }
        }
        override fun read(buffer: ByteArray, off: Int, count: Int): Int {
            val n = channel.read(ByteBuffer.wrap(buffer, off, count), position)
            if (n > 0) position += n
            return n
        }
        override fun readFully(buffer: ByteArray, count: Int): Int {
            var done = 0
            while (done < count) {
                val n = read(buffer, done, count - done)
                if (n <= 0) break
                done += n
            }
            return done
        }
        override fun close() {}
    }

    /** A deque used as a stack, so the executor serves the newest request first. */
    private class LifoQueue(private val deque: LinkedBlockingDeque<Runnable>) : java.util.concurrent.BlockingQueue<Runnable> by deque {
        override fun offer(e: Runnable): Boolean = deque.offerFirst(e)
        override fun add(element: Runnable): Boolean = deque.offerFirst(element)
        override fun put(e: Runnable) = deque.putFirst(e)
    }

    fun shutdown() {
        books.values.forEach { it.closed = true; runCatching { it.close() } }
        books.clear()
        io.shutdown()
    }

    companion object {
        val IMAGE = listOf(".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".avif", ".heic", ".heif")
    }
}
