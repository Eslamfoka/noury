package com.nouri.nouri

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var dnd: DndPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        StepCounterPlugin(applicationContext)
            .register(flutterEngine.dartExecutor.binaryMessenger)

        // Held so the activity can be handed over and taken back: opening the
        // Do-Not-Disturb settings screen needs an Activity, and starting it
        // from the application context instead puts it in its own task, where
        // coming back lands the user outside Nouri.
        dnd = DndPlugin(applicationContext).also {
            it.activity = this
            it.register(flutterEngine.dartExecutor.binaryMessenger)
        }
    }

    override fun onDestroy() {
        dnd?.activity = null
        dnd = null
        super.onDestroy()
    }
}
