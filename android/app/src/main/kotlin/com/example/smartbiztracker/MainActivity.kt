package com.example.smartbiztracker

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.smartbiztracker_new.PerformanceOptimizationManager

class MainActivity : FlutterFragmentActivity() {
    private lateinit var performanceManager: PerformanceOptimizationManager
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize performance optimization manager
        performanceManager = PerformanceOptimizationManager(flutterEngine)
        performanceManager.initialize()
    }
}
