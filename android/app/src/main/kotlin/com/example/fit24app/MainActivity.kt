package com.example.fit24app

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*

class MainActivity : FlutterActivity() {
    private val METHOD = "com.fit24app/steps"
    private val EVENTS = "com.fit24app/steps_stream"
    private var sink: EventChannel.EventSink? = null
    private lateinit var prefs: SharedPreferences
    private val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())

    private var hasSensor = false  // set in configureFlutterEngine, used in onRequestPermissionsResult

    companion object {
        private const val REQ_ACTIVITY     = 1001
        private const val REQ_NOTIFICATION = 1002
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            sink?.success(intent?.getIntExtra("steps", 0) ?: 0)
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        prefs = getSharedPreferences(StepCounterService.PREF_NAME, Context.MODE_PRIVATE)

        hasSensor = (getSystemService(SENSOR_SERVICE) as SensorManager)
            .getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null

        // Request permissions first — service starts only after they are granted
        if (hasSensor) requestPermissionsAndStartService()

        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTodaySteps" ->
                        result.success(prefs.getInt(StepCounterService.KEY_TODAY, 0))

                    "getHistory" -> {
                        val days = call.argument<Int>("days") ?: 7
                        val map = mutableMapOf<String, Int>()
                        val cal = Calendar.getInstance()
                        repeat(days) {
                            cal.time = Date()
                            cal.add(Calendar.DAY_OF_YEAR, -(it + 1))
                            val key = fmt.format(cal.time)
                            map[key] = prefs.getInt(StepCounterService.KEY_HISTORY + key, 0)
                        }
                        result.success(map)
                    }

                    // Called from Flutter to save Health Connect history into prefs
                    "saveHistory" -> {
                        val data = call.argument<Map<String, Int>>("data") ?: emptyMap()
                        val editor = prefs.edit()
                        data.forEach { (date, steps) ->
                            val existing = prefs.getInt(StepCounterService.KEY_HISTORY + date, 0)
                            if (steps > existing)
                                editor.putInt(StepCounterService.KEY_HISTORY + date, steps)
                        }
                        editor.apply()
                        result.success(true)
                    }

                    "hasSensor" -> result.success(hasSensor)
                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, s: EventChannel.EventSink?) {
                    sink = s
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(receiver, IntentFilter("com.fit24app.STEPS"),
                            RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(receiver, IntentFilter("com.fit24app.STEPS"))
                    }
                    sink?.success(prefs.getInt(StepCounterService.KEY_TODAY, 0))
                }
                override fun onCancel(args: Any?) {
                    sink = null
                    try { unregisterReceiver(receiver) } catch (_: Exception) {}
                }
            })
    }

    // ── Permission flow ───────────────────────────────────────────────────────

    private fun requestPermissionsAndStartService() {
        // 1. ACTIVITY_RECOGNITION — mandatory for health FGS type on Android 10+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.ACTIVITY_RECOGNITION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                    REQ_ACTIVITY
                )
                return  // continues in onRequestPermissionsResult
            }
        }

        // 2. POST_NOTIFICATIONS — required on Android 13+ for foreground notification
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQ_NOTIFICATION
                )
                return  // continues in onRequestPermissionsResult
            }
        }

        // All clear — start the service
        StepCounterService.start(this)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            // After ACTIVITY_RECOGNITION result (granted or denied), move to next check
            REQ_ACTIVITY     -> requestPermissionsAndStartService()
            // After notification result, start the service either way
            REQ_NOTIFICATION -> StepCounterService.start(this)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(receiver) } catch (_: Exception) {}
    }
}