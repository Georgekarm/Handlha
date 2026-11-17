package com.handelha.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

object AlarmAudioController {
    private const val AUTO_STOP_MS = 120_000L
    private const val SAMPLE_RATE = 22050
    private const val CHIME_FILE_NAME = "handelha_native_alarm_v1.wav"

    private val lock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var mediaPlayer: MediaPlayer? = null

    @Volatile
    private var vibrator: Vibrator? = null

    @Volatile
    private var audioManager: AudioManager? = null

    @Volatile
    private var focusRequest: AudioFocusRequest? = null

    @Volatile
    private var isActive = false

    private val autoStopRunnable = Runnable {
        stopInternal()
    }

    fun start(context: Context) {
        val appContext = context.applicationContext
        synchronized(lock) {
            if (isActive && mediaPlayer != null) {
                return
            }
            stopLocked()
            isActive = true

            val am = appContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            audioManager = am
            requestAlarmFocus(am)

            val wavFile = ensureAlarmWavFile(appContext)
            try {
                val player = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build(),
                    )
                    setDataSource(wavFile.absolutePath)
                    isLooping = true
                    setVolume(0.9f, 0.9f)
                    prepare()
                    start()
                }
                mediaPlayer = player
            } catch (_: Exception) {
                mediaPlayer = null
            }

            startVibration(appContext)

            mainHandler.removeCallbacks(autoStopRunnable)
            mainHandler.postDelayed(autoStopRunnable, AUTO_STOP_MS)
        }
    }

    fun stop(context: Context? = null) {
        stopInternal()
    }

    private fun stopInternal() {
        synchronized(lock) {
            mainHandler.removeCallbacks(autoStopRunnable)
            stopLocked()
        }
    }

    private fun stopLocked() {
        isActive = false
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                reset()
                release()
            }
        } catch (_: Exception) {
        }
        mediaPlayer = null

        try {
            vibrator?.cancel()
        } catch (_: Exception) {
        }
        vibrator = null

        try {
            val am = audioManager
            if (am != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    focusRequest?.let { am.abandonAudioFocusRequest(it) }
                    focusRequest = null
                } else {
                    @Suppress("DEPRECATION")
                    am.abandonAudioFocus(null)
                }
            }
        } catch (_: Exception) {
        }
        audioManager = null
    }

    private fun requestAlarmFocus(am: AudioManager?) {
        if (am == null) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val attrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                    .setAudioAttributes(attrs)
                    .setAcceptsDelayedFocusGain(false)
                    .build()
                focusRequest = req
                am.requestAudioFocus(req)
            } else {
                @Suppress("DEPRECATION")
                am.requestAudioFocus(
                    null,
                    AudioManager.STREAM_ALARM,
                    AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
                )
            }
        } catch (_: Exception) {
        }
    }

    private fun startVibration(context: Context) {
        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vm?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            vibrator = vib
            val pattern = longArrayOf(0L, 260L, 380L, 260L, 980L)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vib?.vibrate(VibrationEffect.createWaveform(pattern, 0))
            } else {
                @Suppress("DEPRECATION")
                vib?.vibrate(pattern, 0)
            }
        } catch (_: Exception) {
        }
    }

    /** Synthesizes a clean, warm marimba-bell harmonic alarm WAV once into cacheDir. */
    private fun ensureAlarmWavFile(context: Context): File {
        val dir = context.cacheDir
        if (!dir.exists()) dir.mkdirs()
        val outFile = File(dir, CHIME_FILE_NAME)
        if (outFile.exists() && outFile.length() > 1024L) {
            return outFile
        }

        val totalSeconds = 2.6
        val numSamples = (SAMPLE_RATE * totalSeconds).toInt()
        val pcm = ShortArray(numSamples)

        // Warm soothing ascending major-ninth bell progression: C5, E5, G5, D6
        val notes = doubleArrayOf(523.25, 659.25, 783.99, 1174.66)
        val onsets = doubleArrayOf(0.05, 0.27, 0.49, 0.72)

        for (i in 0 until numSamples) {
            val t = i.toDouble() / SAMPLE_RATE
            var mix = 0.0
            for (n in notes.indices) {
                val dt = t - onsets[n]
                if (dt >= 0.0) {
                    val attack = if (dt < 0.014) dt / 0.014 else 1.0
                    val decay = exp(-dt * 2.9)
                    val env = attack * decay
                    val f = notes[n]
                    val tone = sin(2.0 * PI * f * dt) * 0.72 +
                        sin(2.0 * PI * f * 2.0 * dt) * 0.20 +
                        sin(2.0 * PI * f * 3.0 * dt) * 0.06
                    mix += tone * env * 0.42
                }
            }
            val tailFade = if (t > 2.35) ((2.6 - t) / 0.25).coerceIn(0.0, 1.0) else 1.0
            val sample = (mix * tailFade).coerceIn(-0.96, 0.96)
            pcm[i] = (sample * Short.MAX_VALUE).toInt().toShort()
        }

        val dataSize = pcm.size * 2
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray(Charsets.US_ASCII))
            putInt(36 + dataSize)
            put("WAVE".toByteArray(Charsets.US_ASCII))
            put("fmt ".toByteArray(Charsets.US_ASCII))
            putInt(16)
            putShort(1)
            putShort(1)
            putInt(SAMPLE_RATE)
            putInt(SAMPLE_RATE * 2)
            putShort(2)
            putShort(16)
            put("data".toByteArray(Charsets.US_ASCII))
            putInt(dataSize)
        }.array()

        FileOutputStream(outFile).use { fos ->
            fos.write(header)
            val byteBuf = ByteBuffer.allocate(dataSize).order(ByteOrder.LITTLE_ENDIAN)
            for (s in pcm) {
                byteBuf.putShort(s)
            }
            fos.write(byteBuf.array())
            fos.flush()
        }
        return outFile
    }
}
