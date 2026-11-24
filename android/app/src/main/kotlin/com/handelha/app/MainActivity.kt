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
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

class MainActivity : FlutterActivity() {
    companion object {
        private const val AUDIO_CHANNEL = "com.handelha.app/audio"
        private const val AUTH_CHANNEL = "com.handelha.app/auth"
        private const val ALARM_CHANNEL = "com.handelha.app/alarm"
        private const val REQUEST_CODE_PICK_ACCOUNT = 9401
    }

    private val audioLock = Any()
    private val audioExecutor = Executors.newSingleThreadExecutor()
    private val ambientGen = AtomicLong(0L)
    private val alarmGen = AtomicLong(0L)

    @Volatile
    private var ambientPlayer: MediaPlayer? = null

    @Volatile
    private var alarmPlayer: MediaPlayer? = null

    @Volatile
    private var ambientVolume: Float = 0.6f
    private var pendingAccountResult: MethodChannel.Result? = null
    private var alarmChannel: MethodChannel? = null

    @Volatile
    private var pendingSharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureSharedTextIntent(intent)
    }

    private fun captureSharedTextIntent(incoming: Intent?) {
        if (incoming == null) return
        if (incoming.action == Intent.ACTION_SEND && incoming.type?.startsWith("text/") == true) {
            val shared = incoming.getStringExtra(Intent.EXTRA_TEXT)?.trim()
            if (!shared.isNullOrEmpty()) {
                pendingSharedText = shared
                // Clear action so configuration changes do not re-trigger the same shared text.
                incoming.action = Intent.ACTION_MAIN
                try {
                    alarmChannel?.invokeMethod("onSharedTextReceived", shared)
                } catch (_: Exception) {
                }
            }
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
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            AccountManager.newChooseAccountIntent(
                                null,
                                null,
                                arrayOf("com.google"),
                                null,
                                null,
                                null,
                                null,
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            AccountManager.newChooseAccountIntent(
                                null,
                                null,
                                arrayOf("com.google"),
                                false,
                                null,
                                null,
                                null,
                                null,
                            )
                        }
                        pendingAccountResult = result
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQUEST_CODE_PICK_ACCOUNT)
                    } catch (_: Exception) {
                        pendingAccountResult = null
                        result.success(mapOf("status" to "unavailable"))
                    }
                }

                else -> result.notImplemented()
            }
        }

        alarmChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        val id = call.argument<String>("id") ?: ""
                        val title = call.argument<String>("title") ?: "تذكير مهمة"
                        val triggerAtMs = (call.argument<Number>("scheduledAtMs")?.toLong() ?: 0L)
                        val alertMode = call.argument<String>("alertMode") ?: "alarm"
                        val taskId = call.argument<String>("taskId")
                        val isEn = call.argument<Boolean>("isEn") ?: false
                        val mode = if (id.isNotBlank() && triggerAtMs > 0L) {
                            NativeAlarmScheduler.scheduleAlarm(
                                context = applicationContext,
                                id = id,
                                title = title,
                                triggerAtMs = triggerAtMs,
                                alertMode = alertMode,
                                taskId = taskId,
                                isEn = isEn,
                            )
                        } else {
                            "failed"
                        }
                        result.success(
                            mapOf(
                                "scheduled" to (mode == "exact" || mode == "inexact"),
                                "mode" to mode,
                                "canExact" to NativeAlarmScheduler.canScheduleExactAlarms(applicationContext),
                            ),
                        )
                    }

                    "getDeviceTimeZone" -> {
                        result.success(java.util.TimeZone.getDefault().id)
                    }

                    "startFocusService", "updateFocusService" -> {
                        val title = call.argument<String>("title") ?: ""
                        val subtitle = call.argument<String>("subtitle") ?: ""
                        val isEn = call.argument<Boolean>("isEn") ?: false
                        FocusTimerForegroundService.startOrUpdate(
                            context = applicationContext,
                            title = title,
                            subtitle = subtitle,
                            isEn = isEn,
                        )
                        result.success(true)
                    }

                    "stopFocusService" -> {
                        FocusTimerForegroundService.stop(applicationContext)
                        result.success(true)
                    }

                    "cancelAlarm" -> {
                        val id = call.argument<String>("id") ?: ""
                        if (id.isNotBlank()) {
                            NativeAlarmScheduler.cancelAlarm(applicationContext, id)
                        }
                        result.success(true)
                    }

                    "cancelAllAlarms" -> {
                        NativeAlarmScheduler.cancelAllAlarms(applicationContext)
                        AlarmAudioController.stop(applicationContext)
                        result.success(true)
                    }

                    "showAlarmNow" -> {
                        val id = call.argument<String>("id")
                            ?: "preview_${System.currentTimeMillis()}"
                        val title = call.argument<String>("title") ?: "مراجعة الامتحان"
                        val taskId = call.argument<String>("taskId")
                        val isEn = call.argument<Boolean>("isEn") ?: false
                        val isPreview = call.argument<Boolean>("isPreview") ?: true
                        val launched = NativeAlarmScheduler.launchAlarmActivityNow(
                            context = this@MainActivity,
                            id = id,
                            title = title,
                            taskId = taskId,
                            isEn = isEn,
                            isPreview = isPreview,
                        )
                        result.success(launched)
                    }

                    "stopAlarmAudio" -> {
                        AlarmAudioController.stop(applicationContext)
                        result.success(true)
                    }

                    "checkCapabilities" -> {
                        result.success(
                            mapOf(
                                "exactAlarm" to NativeAlarmScheduler.canScheduleExactAlarms(applicationContext),
                                "canDrawOverlays" to NativeAlarmScheduler.canDrawOverlays(applicationContext),
                                "fullScreenIntent" to NativeAlarmScheduler.canUseFullScreenIntent(applicationContext),
                            ),
                        )
                    }

                    "requestOverlayPermission" -> {
                        NativeAlarmScheduler.openOverlayPermissionSettings(this)
                        result.success(true)
                    }

                    "requestExactAlarmPermission" -> {
                        NativeAlarmScheduler.openExactAlarmSettings(this)
                        result.success(true)
                    }

                    "requestFullScreenIntentPermission" -> {
                        NativeAlarmScheduler.openFullScreenIntentSettings(this)
                        result.success(true)
                    }

                    "consumePendingActions" -> {
                        result.success(NativeAlarmStore.drainPendingActions(applicationContext))
                    }

                    "consumeSharedText" -> {
                        val text = pendingSharedText
                        pendingSharedText = null
                        result.success(text)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureSharedTextIntent(intent)
        if (intent.action == AlarmActivity.ACTION_START_FOCUS_FROM_ALARM) {
            try {
                alarmChannel?.invokeMethod("onPendingActionsUpdated", null)
            } catch (_: Exception) {
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
                        callback.success(
                            mapOf(
                                "status" to "selected",
                                "email" to email.trim(),
                            ),
                        )
                        return
                    }
                }
                callback.success(mapOf("status" to "cancelled"))
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
        val targetGen = if (isAlarm) alarmGen.incrementAndGet() else ambientGen.incrementAndGet()
        if (!isAlarm) {
            ambientVolume = volume
        }
        val appCacheDir = applicationContext.cacheDir
        audioExecutor.execute {
            val currentGen = if (isAlarm) alarmGen.get() else ambientGen.get()
            if (currentGen != targetGen) return@execute
            try {
                val bytes = Base64.decode(base64Wav, Base64.DEFAULT)
                val safeKey = key.replace(Regex("[^a-zA-Z0-9_-]"), "_")
                if (!appCacheDir.exists()) {
                    appCacheDir.mkdirs()
                }
                val file = File(appCacheDir, "handelha_audio_$safeKey.wav")
                if (!file.exists() || file.length().toInt() != bytes.size) {
                    val tmp = File(appCacheDir, "handelha_audio_$safeKey.tmp")
                    tmp.writeBytes(bytes)
                    if (!tmp.renameTo(file)) {
                        tmp.copyTo(file, overwrite = true)
                        tmp.delete()
                    }
                }
                val stillCurrent = (if (isAlarm) alarmGen.get() else ambientGen.get()) == targetGen
                if (!stillCurrent) return@execute

                val player = createPreparedWavPlayer(file, loop, if (isAlarm) volume else ambientVolume, isAlarm)
                synchronized(audioLock) {
                    val activeGen = if (isAlarm) alarmGen.get() else ambientGen.get()
                    if (activeGen != targetGen) {
                        try {
                            player.release()
                        } catch (_: Throwable) {
                        }
                        return@execute
                    }
                    if (isAlarm) {
                        stopAlarmPlayerLocked()
                        alarmPlayer = player
                        player.start()
                        triggerAlarmVibration(loop)
                    } else {
                        stopAmbientPlayerLocked()
                        ambientPlayer = player
                        player.start()
                    }
                }
            } catch (_: Throwable) {
            }
        }
        return true
    }

    private fun createPreparedWavPlayer(
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
        return player
    }

    private fun releaseHandledPlayer(mp: MediaPlayer, isAlarm: Boolean) {
        synchronized(audioLock) {
            try {
                mp.release()
            } catch (_: Throwable) {
            }
            if (isAlarm && alarmPlayer === mp) {
                alarmPlayer = null
            } else if (!isAlarm && ambientPlayer === mp) {
                ambientPlayer = null
            }
        }
    }

    private fun stopAmbientPlayer() {
        ambientGen.incrementAndGet()
        synchronized(audioLock) {
            stopAmbientPlayerLocked()
        }
    }

    private fun stopAmbientPlayerLocked() {
        try {
            ambientPlayer?.let { mp ->
                if (mp.isPlaying) {
                    mp.stop()
                }
                mp.release()
            }
        } catch (_: Throwable) {
        } finally {
            ambientPlayer = null
        }
    }

    private fun stopAlarmPlayer() {
        alarmGen.incrementAndGet()
        synchronized(audioLock) {
            stopAlarmPlayerLocked()
        }
    }

    private fun stopAlarmPlayerLocked() {
        try {
            alarmPlayer?.let { mp ->
                if (mp.isPlaying) {
                    mp.stop()
                }
                mp.release()
            }
        } catch (_: Throwable) {
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
        try {
            audioExecutor.shutdownNow()
        } catch (_: Throwable) {
        }
        super.onDestroy()
    }
}
