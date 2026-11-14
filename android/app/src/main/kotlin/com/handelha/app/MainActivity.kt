package com.handelha.app

import android.accounts.AccountManager
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Base64
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        private const val AUDIO_CHANNEL = "com.handelha.app/audio"
        private const val AUTH_CHANNEL = "com.handelha.app/auth"
        private const val REQUEST_CODE_PICK_ACCOUNT = 9401
    }

    private var ambientPlayer: MediaPlayer? = null
    private var alarmPlayer: MediaPlayer? = null
    private var ambientVolume: Float = 0.6f
    private var pendingAccountResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Wake the screen and display alarm alerts over the lock screen across Android 7-16+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playWavBase64" -> {
                    val base64Wav = call.argument<String>("base64Wav")
                    val key = call.argument<String>("key") ?: "tone"
                    val loop = call.argument<Boolean>("loop") ?: false
                    val volume = (call.argument<Number>("volume")?.toDouble() ?: 0.6)
                        .toFloat()
                        .coerceIn(0f, 1f)
                    val isAlarm = call.argument<Boolean>("isAlarm") ?: false
                    if (base64Wav.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val ok = playWav(base64Wav, key, loop, volume, isAlarm)
                    result.success(ok)
                }

                "setVolume" -> {
                    val volume = (call.argument<Number>("volume")?.toDouble() ?: 0.6)
                        .toFloat()
                        .coerceIn(0f, 1f)
                    val isAlarm = call.argument<Boolean>("isAlarm") ?: false
                    if (isAlarm) {
                        try {
                            alarmPlayer?.setVolume(volume, volume)
                        } catch (_: Exception) {
                        }
                    } else {
                        ambientVolume = volume
                        try {
                            ambientPlayer?.setVolume(volume, volume)
                        } catch (_: Exception) {
                        }
                    }
                    result.success(true)
                }

                "stop" -> {
                    val isAlarm = call.argument<Boolean>("isAlarm") ?: false
                    if (isAlarm) {
                        stopAlarmPlayer()
                    } else {
                        stopAmbientPlayer()
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUTH_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickGoogleAccount" -> {
                    if (pendingAccountResult != null) {
                        result.error("BUSY", "Account picker already active", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = AccountManager.newChooseAccountIntent(
                            null,
                            null,
                            arrayOf("com.google"),
                            null,
                            null,
                            null,
                            null,
                        )
                        pendingAccountResult = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQUEST_CODE_PICK_ACCOUNT)
                    } catch (_: Exception) {
                        pendingAccountResult = null
                        result.success(null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_ACCOUNT) {
            val callback = pendingAccountResult
            pendingAccountResult = null
            if (callback != null) {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    val email = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                    if (!email.isNullOrBlank()) {
                        callback.success(mapOf("email" to email.trim()))
                        return
                    }
                }
                callback.success(null)
            }
        }
    }

    private fun playWav(
        base64Wav: String,
        key: String,
        loop: Boolean,
        volume: Float,
        isAlarm: Boolean,
    ): Boolean {
        return try {
            val bytes = Base64.decode(base64Wav, Base64.DEFAULT)
            val safeKey = key.replace(Regex("[^a-zA-Z0-9_-]"), "_")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            val file = File(cacheDir, "handelha_audio_$safeKey.wav")
            if (!file.exists() || file.length().toInt() != bytes.size) {
                file.writeBytes(bytes)
            }

            if (isAlarm) {
                stopAlarmPlayer()
                alarmPlayer = createWavPlayer(file, loop, volume, isAlarm = true)
                triggerAlarmVibration(loop)
            } else {
                stopAmbientPlayer()
                ambientVolume = volume
                ambientPlayer = createWavPlayer(file, loop, ambientVolume, isAlarm = false)
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun createWavPlayer(
        file: File,
        loop: Boolean,
        volume: Float,
        isAlarm: Boolean,
    ): MediaPlayer {
        val player = MediaPlayer()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(
                        if (isAlarm) {
                            AudioAttributes.USAGE_ALARM
                        } else {
                            AudioAttributes.USAGE_MEDIA
                        },
                    )
                    .setContentType(
                        if (isAlarm) {
                            AudioAttributes.CONTENT_TYPE_SONIFICATION
                        } else {
                            AudioAttributes.CONTENT_TYPE_MUSIC
                        },
                    )
                    .build(),
            )
        } else {
            @Suppress("DEPRECATION")
            player.setAudioStreamType(
                if (isAlarm) AudioManager.STREAM_ALARM else AudioManager.STREAM_MUSIC,
            )
        }
        player.setDataSource(file.absolutePath)
        player.isLooping = loop
        player.setVolume(volume, volume)
        player.setOnCompletionListener { mp ->
            if (!loop) {
                releaseHandledPlayer(mp, isAlarm)
            }
        }
        player.setOnErrorListener { mp, _, _ ->
            releaseHandledPlayer(mp, isAlarm)
            true
        }
        player.prepare()
        player.start()
        return player
    }

    private fun releaseHandledPlayer(mp: MediaPlayer, isAlarm: Boolean) {
        try {
            mp.release()
        } catch (_: Exception) {
        }
        if (isAlarm && alarmPlayer === mp) {
            alarmPlayer = null
        } else if (!isAlarm && ambientPlayer === mp) {
            ambientPlayer = null
        }
    }

    private fun stopAmbientPlayer() {
        try {
            ambientPlayer?.let { mp ->
                if (mp.isPlaying) {
                    mp.stop()
                }
                mp.release()
            }
        } catch (_: Exception) {
        } finally {
            ambientPlayer = null
        }
    }

    private fun stopAlarmPlayer() {
        try {
            alarmPlayer?.let { mp ->
                if (mp.isPlaying) {
                    mp.stop()
                }
                mp.release()
            }
        } catch (_: Exception) {
        } finally {
            alarmPlayer = null
        }
        cancelVibration()
    }

    private fun currentVibrator(): Vibrator? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                manager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun triggerAlarmVibration(loop: Boolean) {
        try {
            val vibrator = currentVibrator() ?: return
            if (!vibrator.hasVibrator()) return
            val pattern = longArrayOf(0L, 320L, 680L)
            val repeatIndex = if (loop) 0 else -1
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, repeatIndex))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, repeatIndex)
            }
        } catch (_: Exception) {
        }
    }

    private fun cancelVibration() {
        try {
            currentVibrator()?.cancel()
        } catch (_: Exception) {
        }
    }

    override fun onDestroy() {
        stopAmbientPlayer()
        stopAlarmPlayer()
        super.onDestroy()
    }
}
