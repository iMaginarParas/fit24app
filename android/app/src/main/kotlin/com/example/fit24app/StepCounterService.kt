package com.example.fit24app

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import java.text.SimpleDateFormat
import java.util.*

class StepCounterService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var stepSensor: Sensor? = null
    private var baselineSteps: Int = -1
    private var todaySteps: Int = 0
    private val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    private lateinit var prefs: android.content.SharedPreferences

    companion object {
        const val CHANNEL_ID      = "fit24_step_counter"
        const val NOTIFICATION_ID = 1
        const val PREF_NAME       = "fit24_steps"
        const val KEY_TODAY       = "today_steps"
        const val KEY_HISTORY     = "history_"   // prefix: e.g. history_2024-01-01

        var eventSinkRef: EventChannel.EventSink? = null

        /** Start (or restart) the service safely from anywhere. */
        fun start(ctx: Context) {
            val intent = Intent(ctx, StepCounterService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(intent)
            } else {
                ctx.startService(intent)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        createNotificationChannel()

        val notification = buildNotification(prefs.getInt(KEY_TODAY, 0))

        // Use FOREGROUND_SERVICE_TYPE_HEALTH to match the manifest declaration
        // of foregroundServiceType="health". Android 14+ requires the type passed
        // here to be a subset of what is declared in AndroidManifest.xml.
        // ACTIVITY_RECOGNITION permission is already declared in the manifest and
        // will be requested at runtime before this service is started.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return

        val totalSteps = event.values[0].toInt()

        // Reset baseline at midnight
        val today = fmt.format(Date())
        val savedDate = prefs.getString("last_date", "") ?: ""
        if (savedDate != today) {
            if (savedDate.isNotEmpty()) {
                prefs.edit()
                    .putInt(KEY_HISTORY + savedDate, todaySteps)
                    .putString("last_date", today)
                    .apply()
            } else {
                prefs.edit().putString("last_date", today).apply()
            }
            baselineSteps = totalSteps
            todaySteps = 0
        }

        if (baselineSteps < 0) baselineSteps = totalSteps
        todaySteps = totalSteps - baselineSteps

        // Persist
        prefs.edit().putInt(KEY_TODAY, todaySteps).apply()

        // Push to Flutter EventChannel
        eventSinkRef?.success(todaySteps)

        // Broadcast for MainActivity BroadcastReceiver
        sendBroadcast(Intent("com.fit24app.STEPS").putExtra("steps", todaySteps))

        // Update notification text
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, buildNotification(todaySteps))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY  // Android restarts this if killed

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(steps: Int): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Fit24 · Step Tracker")
            .setContentText("$steps steps today")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .setSilent(true)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Step Counter",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Counts your steps in the background"
                setShowBadge(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }
}