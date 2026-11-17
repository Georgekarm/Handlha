package com.handelha.app.core.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.random.Random

enum class AmbientSoundscape(
    val storedKey: String,
    val labelAr: String,
    val labelEn: String,
    val subtitleAr: String,
    val subtitleEn: String,
) {
    SILENT(
        storedKey = "silent",
        labelAr = "صامت",
        labelEn = "Silent",
        subtitleAr = "تركيز بدون مؤثرات صوتية",
        subtitleEn = "Focus without background audio",
    ),
    OCEAN(
        storedKey = "ocean",
        labelAr = "أمواج البحر",
        labelEn = "Ocean Waves",
        subtitleAr = "صوت حركة الموج الهادئة على الشاطئ لصفاء الذهن",
        subtitleEn = "Rhythmic ocean waves washing ashore for mental clarity",
    ),
    NIGHT(
        storedKey = "night",
        labelAr = "هدوء الليل",
        labelEn = "Calm Night",
        subtitleAr = "ترددات ليلية دافئة وهادئة تساعد على التركيز العميق",
        subtitleEn = "Warm nocturnal frequencies for deep evening focus",
    ),
    RAIN(
        storedKey = "rain",
        labelAr = "مطر هادئ",
        labelEn = "Gentle Rain",
        subtitleAr = "قطرات مطر خفيفة تعزلك عن الضوضاء حولك",
        subtitleEn = "Soft rainfall patter that masks surrounding noise",
    ),
    FOREST(
        storedKey = "forest",
        labelAr = "نسيم الغابة",
        labelEn = "Forest Breeze",
        subtitleAr = "نسيم الطبيعة مع نغمات هادئة مريحة للأعصاب",
        subtitleEn = "Calm nature breeze with soothing harmonic tones",
    ),
    WARM_NOISE(
        storedKey = "warmNoise",
        labelAr = "ضوضاء دافئة",
        labelEn = "Warm Focus",
        subtitleAr = "تردد بني دافئ يعزل الإلهاء ويريح الذهن أثناء المذاكرة",
        subtitleEn = "Warm brown noise that masks distractions during study",
    );

    fun label(isEnglish: Boolean): String = if (isEnglish) labelEn else labelAr
    fun subtitle(isEnglish: Boolean): String = if (isEnglish) subtitleEn else subtitleAr

    companion object {
        fun fromKey(raw: String?): AmbientSoundscape =
            entries.firstOrNull { it.storedKey == raw } ?: SILENT
    }
}

/**
 * Synthesizes 6-second seamless loop PCM-16 mono 22050Hz WAV ambient soundscapes
 * into cacheDir and plays via MediaPlayer.
 */
class HandelhaSoundEngine(private val context: Context) {
    private val appContext = context.applicationContext
    private var ambientPlayer: MediaPlayer? = null
    private var alarmPlayer: MediaPlayer? = null

    var currentAmbient: AmbientSoundscape = AmbientSoundscape.SILENT
        private set
    var volume: Float = 0.65f
        private set

    fun playAmbient(soundscape: AmbientSoundscape, newVolume: Float? = null) {
        if (newVolume != null) {
            volume = newVolume.coerceIn(0.05f, 1.0f)
        }
        currentAmbient = soundscape
        if (soundscape == AmbientSoundscape.SILENT) {
            stopAmbient()
            return
        }
        try {
            stopPlayer(ambientPlayer)
            ambientPlayer = null
            val wavFile = ensureAmbientWavFile(soundscape)
            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build(),
                )
                setDataSource(wavFile.absolutePath)
                isLooping = true
                setVolume(volume, volume)
                prepare()
                start()
            }
            ambientPlayer = player
        } catch (_: Exception) {
            ambientPlayer = null
        }
    }

    fun setAmbientVolume(newVolume: Float) {
        volume = newVolume.coerceIn(0.05f, 1.0f)
        try {
            ambientPlayer?.setVolume(volume, volume)
        } catch (_: Exception) {
        }
    }

    fun stopAmbient() {
        currentAmbient = AmbientSoundscape.SILENT
        stopPlayer(ambientPlayer)
        ambientPlayer = null
    }

    fun playAlarmChime(loop: Boolean = true) {
        try {
            stopPlayer(alarmPlayer)
            alarmPlayer = null
            val wavFile = ensureAlarmChimeFile()
            val player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                setDataSource(wavFile.absolutePath)
                isLooping = loop
                setVolume(0.9f, 0.9f)
                prepare()
                start()
            }
            alarmPlayer = player
        } catch (_: Exception) {
            alarmPlayer = null
        }
    }

    fun stopAlarmChime() {
        stopPlayer(alarmPlayer)
        alarmPlayer = null
    }

    fun release() {
        stopAmbient()
        stopAlarmChime()
    }

    private fun stopPlayer(player: MediaPlayer?) {
        try {
            player?.apply {
                if (isPlaying) stop()
                reset()
                release()
            }
        } catch (_: Exception) {
        }
    }

    private fun ensureAmbientWavFile(type: AmbientSoundscape): File {
        val dir = appContext.cacheDir
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "handelha_ambient_${type.storedKey}_v1.wav")
        if (file.exists() && file.length() > 1024L) return file

        val sampleRate = 22050
        val durationSeconds = 6
        val numSamples = sampleRate * durationSeconds
        val samples = DoubleArray(numSamples)
        val rng = Random(42 + type.ordinal)

        var lp1 = 0.0
        var lp2 = 0.0

        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val loopPhase = (t / durationSeconds) * 2.0 * PI
            val white = rng.nextDouble() * 2.0 - 1.0
            lp1 = 0.96 * lp1 + 0.04 * white
            lp2 = 0.92 * lp2 + 0.08 * lp1

            val value = when (type) {
                AmbientSoundscape.OCEAN -> {
                    val swell = 0.35 + 0.65 * (0.5 + 0.5 * sin(loopPhase))
                    val subWave = 0.12 * sin(2.0 * PI * 110.0 * t) +
                        0.08 * sin(2.0 * PI * 165.0 * t)
                    (lp2 * 2.2 * swell) + subWave * swell
                }
                AmbientSoundscape.NIGHT -> {
                    val pad = 0.18 * sin(2.0 * PI * 174.6 * t) +
                        0.14 * sin(2.0 * PI * 261.6 * t) +
                        0.09 * sin(2.0 * PI * 392.0 * t)
                    val shimmerEnv = max(0.0, sin(2.0 * PI * 2.5 * t)) * 0.04
                    val cricket = shimmerEnv * sin(2.0 * PI * 3200.0 * t)
                    pad + (lp2 * 0.4) + cricket
                }
                AmbientSoundscape.RAIN -> {
                    val rainFilter = 0.80 * lp1 + 0.20 * white
                    val warmPad = 0.08 * sin(2.0 * PI * 196.0 * t)
                    (rainFilter * 0.55) + warmPad
                }
                AmbientSoundscape.FOREST -> {
                    val breeze = lp2 * 1.1 * (0.6 + 0.4 * cos(loopPhase))
                    val noteFreq = when {
                        t < 2.0 -> 293.66
                        t < 4.0 -> 329.63
                        else -> 392.00
                    }
                    val localT = t % 2.0
                    val bellEnv = exp(-localT * 2.2)
                    val bell = 0.22 * bellEnv * sin(2.0 * PI * noteFreq * t)
                    breeze + bell
                }
                AmbientSoundscape.WARM_NOISE -> {
                    val brown = 0.72 * lp2 + 0.28 * lp1
                    val roomTone = 0.05 * sin(2.0 * PI * 130.81 * t)
                    (brown * 2.4) + roomTone
                }
                AmbientSoundscape.SILENT -> 0.0
            }
            samples[i] = value.coerceIn(-0.9, 0.9)
        }

        // Crossfade final 40ms back into opening 40ms for click-free loops
        val fadeSamples = 882
        if (numSamples > fadeSamples * 2) {
            for (i in 0 until fadeSamples) {
                val alpha = i.toDouble() / fadeSamples
                val tailIdx = numSamples - fadeSamples + i
                samples[i] = samples[i] * alpha + samples[tailIdx] * (1.0 - alpha)
            }
        }

        writePcm16Wav(file, samples, sampleRate)
        return file
    }

    private fun ensureAlarmChimeFile(): File {
        val dir = appContext.cacheDir
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "handelha_focus_chime_v1.wav")
        if (file.exists() && file.length() > 1024L) return file

        val sampleRate = 22050
        val durationSeconds = 3
        val numSamples = sampleRate * durationSeconds
        val samples = DoubleArray(numSamples)
        val notes = doubleArrayOf(523.25, 659.25, 783.99, 1046.50)

        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            if (t >= 2.2) {
                samples[i] = 0.0
                continue
            }
            val step = (t / 0.26).toInt() % notes.size
            val noteT = t % 0.26
            val freq = notes[step]
            val env = exp(-noteT * 7.5)
            val tone = 0.45 * sin(2.0 * PI * freq * t) +
                0.20 * sin(2.0 * PI * (freq * 2.0) * t)
            samples[i] = (tone * env).coerceIn(-0.9, 0.9)
        }

        writePcm16Wav(file, samples, sampleRate)
        return file
    }

    private fun writePcm16Wav(outFile: File, samples: DoubleArray, sampleRate: Int) {
        val numSamples = samples.size
        val dataSize = numSamples * 2
        val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN).apply {
            put("RIFF".toByteArray(Charsets.US_ASCII))
            putInt(36 + dataSize)
            put("WAVE".toByteArray(Charsets.US_ASCII))
            put("fmt ".toByteArray(Charsets.US_ASCII))
            putInt(16)
            putShort(1)
            putShort(1)
            putInt(sampleRate)
            putInt(sampleRate * 2)
            putShort(2)
            putShort(16)
            put("data".toByteArray(Charsets.US_ASCII))
            putInt(dataSize)
        }.array()

        val pcmBytes = ByteBuffer.allocate(dataSize).order(ByteOrder.LITTLE_ENDIAN)
        for (s in samples) {
            val v = (s * 32767.0).roundToInt().coerceIn(-32768, 32767).toShort()
            pcmBytes.putShort(v)
        }

        FileOutputStream(outFile).use { fos ->
            fos.write(header)
            fos.write(pcmBytes.array())
            fos.flush()
        }
    }
}
