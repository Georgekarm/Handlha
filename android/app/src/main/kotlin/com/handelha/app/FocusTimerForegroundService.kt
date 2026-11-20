package com.handelha.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class FocusTimerForegroundService : Service() {
    companion object {
        private const val CHANNEL_ID = "handelha_focus_timer_v1"
        private const val NOTIFICATION_ID = 94020
        const val ACTION_START_OR_UPDATE = "com.handelha.app.ACTION_FOCUS_TIMER_UPDATE"
        const val ACTION_STOP = "com.handelha.app.ACTION_FOCUS_TIMER_STOP"
        const val EXTRA_TITLE = "extra_focus_title"
        const val EXTRA_SUBTITLE = "extra_focus_subtitle"
        const val EXTRA_IS_EN = "extra_focus_is_en"

        fun startOrUpdate(
            context: Context,
            title: String,
            subtitle: String,
            isEn: Boolean,
        ) {
            val appContext = context.applicationContext
            val intent = Intent(appContext, FocusTimerForegroundService::class.java).apply {
                action = ACTION_START_OR_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_SUBTITLE, subtitle)
                putExtra(EXTRA_IS_EN, isEn)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appContext.startForegroundService(intent)
                } else {
                    appContext.startService(intent)
                }
            } catch (_: Exception) {
            }
        }

        fun stop(context: Context) {
            val appContext = context.applicationContext
            try {
                appContext.stopService(Intent(appContext, FocusTimerForegroundService::class.java))
            } catch (_: Exception) {
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        val isEn = intent?.getBooleanExtra(EXTRA_IS_EN, false) ?: false
        val title = intent?.getStringExtra(EXTRA_TITLE)?.takeIf { it.isNotBlank() }
            ?: if (isEn) "Handelha Focus Session" else "جلسة تركيز هندلها"
        val subtitle = intent?.getStringExtra(EXTRA_SUBTITLE)?.takeIf { it.isNotBlank() }
            ?: if (isEn) "Focus timer in progress" else "مؤقت التركيز شغّال"

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (nm != null) {
            ensureChannel(nm, isEn)
        }

        val notification = buildNotification(title, subtitle)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForegroundCompat()
        super.onDestroy()
    }

    private fun stopForegroundCompat() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
    }

    private fun buildNotification(title: String, subtitle: String): Notification {
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val contentPi = PendingIntent.getActivity(this, NOTIFICATION_ID, openAppIntent, piFlags)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_handelha)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setContentIntent(contentPi)
            .build()
    }

    private fun ensureChannel(nm: NotificationManager, isEn: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                if (isEn) "Handelha Focus Timer" else "مؤقت تركيز هندلها",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = if (isEn) {
                    "Keeps your focus timer and calm soundscapes running accurately in the background"
                } else {
                    "يحافظ على دقة مؤقت التركيز والأصوات الهادئة في الخلفية"
                }
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                setSound(null, null)
                enableVibration(false)
            }
            nm.createNotificationChannel(channel)
        }
    }
}
