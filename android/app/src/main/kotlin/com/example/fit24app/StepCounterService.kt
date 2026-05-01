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
    private var externalSteps: Int = 0
    private var lastSavedDate: String = ""
    private val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply {
        timeZone = TimeZone.getDefault()
    }
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

        /** Update the today's steps from external source like Health Connect */
        fun updateExternalSteps(ctx: Context, steps: Int) {
            val intent = Intent(ctx, StepCounterService::class.java).apply {
                action = "UPDATE_STEPS"
                putExtra("external_steps", steps)
            }
            ctx.startService(intent)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        createNotificationChannel()

        // Load persisted state
        todaySteps = prefs.getInt(KEY_TODAY, 0)
        baselineSteps = prefs.getInt("baseline_steps", -1)
        externalSteps = prefs.getInt("external_steps", 0)
        lastSavedDate = prefs.getString("last_date", "") ?: ""

        val notification = buildNotification(todaySteps)

        // Use FOREGROUND_SERVICE_TYPE_HEALTH to match the manifest declaration
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
        if (lastSavedDate != today) {
            if (lastSavedDate.isNotEmpty()) {
                prefs.edit()
                    .putInt(KEY_HISTORY + lastSavedDate, todaySteps)
                    .putString("last_date", today)
                    .putInt("baseline_steps", totalSteps)
                    .putInt("external_steps", 0)
                    .putInt(KEY_TODAY, 0)
                    .apply()
            } else {
                prefs.edit()
                    .putString("last_date", today)
                    .putInt("baseline_steps", totalSteps)
                    .apply()
            }
            baselineSteps = totalSteps
            todaySteps = 0
            externalSteps = 0
            lastSavedDate = today
            return // Skip further logic for the first event of a new day
        }

        if (baselineSteps < 0) {
            // Initial setup or first run after clear
            baselineSteps = totalSteps - (todaySteps - externalSteps)
            prefs.edit().putInt("baseline_steps", baselineSteps).apply()
        } else if (totalSteps < baselineSteps) {
            // SENSOR RESET (Phone Reboot)
            // We adjust baseline so that todaySteps remains the same
            baselineSteps = totalSteps - (todaySteps - externalSteps)
            prefs.edit().putInt("baseline_steps", baselineSteps).apply()
        }
        
        val localSteps = (totalSteps - baselineSteps).coerceAtLeast(0)
        val calculatedSteps = if (externalSteps > localSteps) externalSteps else localSteps

        // Only update if steps increased (prevents jitter or weird resets)
        if (calculatedSteps > todaySteps || (calculatedSteps == 0 && todaySteps == 0)) {
            todaySteps = calculatedSteps
            
            // Persist
            prefs.edit().putInt(KEY_TODAY, todaySteps).apply()

            // Push to Flutter EventChannel
            eventSinkRef?.success(todaySteps)

            // Broadcast for MainActivity
            val intent = Intent("com.fit24app.STEPS")
            intent.putExtra("steps", todaySteps)
            intent.setPackage(packageName)
            sendBroadcast(intent)

            // Update notification text
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .notify(NOTIFICATION_ID, buildNotification(todaySteps))
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "UPDATE_STEPS") {
            val steps = intent.getIntExtra("external_steps", 0)
            if (steps > externalSteps) {
                externalSteps = steps
                
                // Recalculate todaySteps with new external baseline
                val sManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                val sCounter = sManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
                // We don't have the current sensor value here easily without registering,
                // but todaySteps will be updated on the next sensor event anyway.
                // For now, just update the notification if todaySteps increased.
                val totalSteps = prefs.getInt(KEY_TODAY, 0) // fallback to last known
                if (externalSteps > totalSteps) {
                    todaySteps = externalSteps
                    prefs.edit()
                        .putInt(KEY_TODAY, todaySteps)
                        .putInt("external_steps", externalSteps)
                        .apply()
                    eventSinkRef?.success(todaySteps)
                    
                    val bIntent = Intent("com.fit24app.STEPS")
                    bIntent.putExtra("steps", todaySteps)
                    bIntent.setPackage(packageName)
                    sendBroadcast(bIntent)

                    (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                        .notify(NOTIFICATION_ID, buildNotification(todaySteps))
                }
            }
        }
        return START_STICKY  // Android restarts this if killed
    }

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