package com.nouri.nouri

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Reads Android's hardware step counter.
 *
 * Hand-written rather than a pub dependency, deliberately: Slice 1 is offline
 * and the dependency list is kept as short as it can be. This is about eighty
 * lines and has no transitive reach at all.
 *
 * `TYPE_STEP_COUNTER` reports steps **since the device last booted**, not since
 * the listener was registered. That is the useful property: the OS keeps
 * counting while the app is backgrounded or closed, so a session can reconcile
 * on resume from the cumulative total rather than losing the steps it did not
 * see. It also means the counter **resets to zero on reboot**, which the Dart
 * side has to survive — see `walkStats`, which clamps a negative delta to zero
 * rather than reporting a walk that went backwards.
 *
 * Nothing is stored here. The sensor is the source of truth and the session
 * arithmetic all lives in Dart, where it is testable.
 */
class StepCounterPlugin(private val context: Context) {

    companion object {
        private const val METHOD_CHANNEL = "com.nouri.nouri/steps"
        private const val EVENT_CHANNEL = "com.nouri.nouri/steps_stream"
    }

    private val sensorManager: SensorManager? =
        context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    private val stepSensor: Sensor?
        get() = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

    private var listener: SensorEventListener? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // Reported honestly. Most emulator images have no step counter,
                // and the Dart side says so plainly rather than inventing steps.
                "isAvailable" -> result.success(stepSensor != null)
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val sensor = stepSensor
                    if (sensor == null || events == null) {
                        events?.error(
                            "no_sensor",
                            "This device has no TYPE_STEP_COUNTER sensor",
                            null,
                        )
                        return
                    }

                    val l = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent?) {
                            val value = event?.values?.firstOrNull() ?: return
                            // The sensor reports a float; the count is a whole
                            // number of steps and is sent as one.
                            events.success(value.toInt())
                        }

                        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
                    }

                    listener = l
                    // SENSOR_DELAY_UI, not FASTEST: a walk readout that updates
                    // a few times a second is already smoother than the user
                    // can walk, and the faster rates cost battery for nothing.
                    sensorManager?.registerListener(l, sensor, SensorManager.SENSOR_DELAY_UI)
                }

                override fun onCancel(arguments: Any?) {
                    listener?.let { sensorManager?.unregisterListener(it) }
                    listener = null
                }
            },
        )
    }
}
