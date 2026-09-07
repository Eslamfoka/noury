package com.nouri.nouri

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        StepCounterPlugin(applicationContext)
            .register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
