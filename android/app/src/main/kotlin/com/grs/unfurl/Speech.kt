package com.grs.unfurl

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice

/**
 * Read aloud through the system text-to-speech engine, bound lazily on first use
 * (binding in configureFlutterEngine is platform-thread work at cold start; Mull's
 * lesson). One sentence per utterance; Dart queues the next on `ttsDone`. Audio
 * focus loss pauses (`ttsFocusLost`), as the spec asks.
 */
class Speech(private val context: Context, private val send: (String, Any?) -> Unit) {
    private var tts: TextToSpeech? = null
    private var ready = false
    private val queued = ArrayList<() -> Unit>()
    private val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focus: AudioFocusRequest? = null
    var rate = 1f

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
            stop()
            send("ttsFocusLost", null)
        }
    }

    private fun withEngine(action: () -> Unit) {
        if (ready) return action()
        queued.add(action)
        if (tts != null) return
        tts = TextToSpeech(context) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (!ready) {
                send("ttsError", "unavailable")
                queued.clear()
                return@TextToSpeech
            }
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(id: String) = send("ttsStart", id)
                override fun onDone(id: String) = send("ttsDone", id)
                @Deprecated("Deprecated in Java")
                override fun onError(id: String) = send("ttsError", id)
            })
            queued.forEach { it() }
            queued.clear()
        }
    }

    fun speak(text: String, id: String): Boolean {
        requestFocus()
        withEngine {
            tts?.setSpeechRate(rate)
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), id)
        }
        return true
    }

    fun preview(name: String, text: String): Boolean {
        withEngine {
            val previous = tts?.voice
            tts?.voices?.firstOrNull { it.name == name }?.let { tts?.voice = it }
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), "preview")
            previous?.let { tts?.voice = it }
        }
        return true
    }

    fun stop() {
        tts?.stop()
        abandonFocus()
    }

    fun voices(callback: (List<Map<String, Any?>>) -> Unit) = withEngine {
        val engine = tts ?: return@withEngine callback(emptyList())
        val current = engine.voice?.name
        val list = (engine.voices ?: emptySet<Voice>())
            .filter { !it.isNetworkConnectionRequired && it.features?.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED) != true }
            .sortedWith(compareBy({ it.locale.displayName }, { it.name }))
            .map { mapOf("name" to it.name, "locale" to it.locale.toLanguageTag(), "label" to it.locale.displayName, "selected" to (it.name == current)) }
        callback(list)
    }

    fun setVoice(name: String?): Boolean {
        withEngine { tts?.voices?.firstOrNull { it.name == name }?.let { tts?.voice = it } }
        return true
    }

    fun shutdown() {
        tts?.shutdown()
        abandonFocus()
    }

    private fun requestFocus() {
        if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                .setOnAudioFocusChangeListener(focusListener).build()
            focus = request
            audio.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audio.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
        else @Suppress("DEPRECATION") audio.abandonAudioFocus(focusListener)
    }
}
