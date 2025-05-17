//
//  DebugView.swift
//  Perpetual
//
//  Created by Bryan Veloso on 5/16/25.
//

import SwiftUI
import Combine
import Foundation

struct LoopTestView: View {
    @ObservedObject var audioManager: AudioManager
    @State private var testResults: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loop Test Status")
                .font(.headline)
            
            HStack {
                Button("Run Loop Test") {
                    runLoopTest()
                }
                .buttonStyle(.bordered)
                
                Button("Clear Results") {
                    testResults.removeAll()
                }
                .buttonStyle(.bordered)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func runLoopTest() {
        testResults.removeAll()
        addTestResult("Starting loop test...")
        
        // Test 1: Check if loop points are set
        if audioManager.loopEndTime > audioManager.loopStartTime {
            addTestResult("✓ Loop points set correctly")
            addTestResult("  Start: \(TimeFormatter.formatPrecise(audioManager.loopStartTime))")
            addTestResult("  End: \(TimeFormatter.formatPrecise(audioManager.loopEndTime))")
            addTestResult("  Duration: \(TimeFormatter.formatPrecise(audioManager.loopEndTime - audioManager.loopStartTime))")
        } else {
            addTestResult("⚠ Loop points not set properly")
        }
        
        // Test 2: Check current playback state
        addTestResult("Current position: \(TimeFormatter.formatPrecise(audioManager.currentTime))")
        addTestResult("Playing: \(audioManager.isPlaying)")
        addTestResult("Current loop: \(audioManager.currentLoopIteration)")
        
        // Test 3: Set a short loop for testing
        let testStart = audioManager.duration * 0.1
        let testEnd = audioManager.duration * 0.2
        audioManager.setLoopPoints(start: testStart, end: testEnd)
        addTestResult("Set test loop: \(TimeFormatter.formatPrecise(testStart)) to \(TimeFormatter.formatPrecise(testEnd))")
        
        // Test 4: Check if seeking works
        audioManager.seek(to: testStart)
        addTestResult("Seeked to loop start")
        
        if audioManager.isPlaying {
            addTestResult("✓ Audio is playing - monitor for seamless loops")
        } else {
            addTestResult("⚠ Not playing - press play to test looping")
        }
    }
    
    private func addTestResult(_ message: String) {
        testResults.append(message)
    }
}

// Add this to your ContentView or create a new debug tab
struct DebugView: View {
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Debug Information")
                .font(.title2)
                .fontWeight(.bold)
            
            // Audio Engine Status
            AudioEngineStatusView(audioManager: audioManager)
            
            // Loop Test
            LoopTestView(audioManager: audioManager)
            
            // Performance Monitor
            PerformanceMonitorView()
        }
        .padding()
    }
}

struct AudioEngineStatusView: View {
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audio Engine Status")
                .font(.headline)
            
            Grid(alignment: .leading) {
                GridRow {
                    Text("Playing:")
                    Text(audioManager.isPlaying ? "✓ Yes" : "• No")
                        .foregroundColor(audioManager.isPlaying ? .green : .gray)
                }
                
                GridRow {
                    Text("Current Time:")
                    Text(TimeFormatter.formatPrecise(audioManager.currentTime))
                }
                
                GridRow {
                    Text("Duration:")
                    Text(TimeFormatter.formatPrecise(audioManager.duration))
                }
                
                GridRow {
                    Text("Loop Count:")
                    Text(audioManager.loopCount == 0 ? "∞" : "\(audioManager.loopCount)")
                }
                
                GridRow {
                    Text("Loop Iteration:")
                    Text("\(audioManager.currentLoopIteration)")
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PerformanceMonitorView: View {
    @State private var cpuUsage: Double = 0
    @State private var memoryUsage: Double = 0
    @State private var performanceTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Monitor")
                .font(.headline)
            
            HStack {
                Text("CPU: \(cpuUsage, specifier: "%.1f")%")
                Spacer()
                Text("Memory: \(memoryUsage, specifier: "%.1f") MB")
            }
            .font(.caption)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
        .onAppear {
            // Start monitoring when view appears
            startPerformanceMonitoring()
        }
        .onDisappear {
            // Clean up resources when view disappears
            stopPerformanceMonitoring()
        }
    }
    
    private func startPerformanceMonitoring() {
        // Cancel any existing timer
        performanceTimer?.invalidate()
        
        // Create and store new timer
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // This is just demo data - replace with actual monitoring code
            cpuUsage = Double.random(in: 0...25)
            memoryUsage = Double.random(in: 50...200)
        }
    }
    
    private func stopPerformanceMonitoring() {
        // Invalidate and release timer
        performanceTimer?.invalidate()
        performanceTimer = nil
    }
}