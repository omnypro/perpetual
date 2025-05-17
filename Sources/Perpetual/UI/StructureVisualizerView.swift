//
//  StructureVisualizerView.swift
//  Perpetual
//
//  Created by Bryan Veloso on 5/17/25.
//

import SwiftUI
import AVFoundation
import Combine

/**
 * StructureVisualizerView
 *
 * A view component for visualizing the results of music structure analysis.
 * Displays detected sections, suggested loop points, and provides controls
 * for applying detected loops to the audio playback.
 */
struct StructureVisualizerView: View {
    @ObservedObject var analyzer: MusicStructureAnalyzer
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 16) {
            if analyzer.isAnalyzing {
                // Show progress during analysis
                ProgressView(value: analyzer.progress) {
                    Text("Analyzing Structure: \(Int(analyzer.progress * 100))%")
                }
                .progressViewStyle(.linear)
                .padding()
            } else if !analyzer.sections.isEmpty {
                // Structure visualization
                StructureView(sections: analyzer.sections,
                             currentTime: audioManager.currentTime,
                             duration: audioManager.duration,
                             suggestedLoopStart: analyzer.suggestedLoopStart,
                             suggestedLoopEnd: analyzer.suggestedLoopEnd,
                             loopStartTime: $audioManager.loopStartTime,
                             loopEndTime: $audioManager.loopEndTime)
                    .frame(height: 80)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(8)
                
                // Controls for applying suggested loop points
                HStack {
                    Text("Suggested Loop Points:")
                        .font(.caption)
                    
                    Text("Start: \(TimeFormatter.formatPrecise(analyzer.suggestedLoopStart))")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("End: \(TimeFormatter.formatPrecise(analyzer.suggestedLoopEnd))")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Button("Apply Suggested") {
                        audioManager.setLoopPoints(start: analyzer.suggestedLoopStart,
                                                  end: analyzer.suggestedLoopEnd)
                        // Publish event to notify other components
                        EventBus.shared.publishLoopPointsChanged()
                    }
                    .buttonStyle(.bordered)
                    .disabled(analyzer.suggestedLoopStart >= analyzer.suggestedLoopEnd)
                }
                
                // A/B testing controls
                HStack {
                    Button("Test Original") {
                        audioManager.stop()
                        audioManager.setLoopPoints(start: 0, end: audioManager.duration)
                        audioManager.play()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Test Loop") {
                        audioManager.stop()
                        audioManager.seek(to: analyzer.suggestedLoopStart)
                        audioManager.setLoopPoints(start: analyzer.suggestedLoopStart,
                                                  end: analyzer.suggestedLoopEnd)
                        audioManager.play()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Text("Loop Duration: \(TimeFormatter.formatStandard(analyzer.suggestedLoopEnd - analyzer.suggestedLoopStart))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if analyzer.error != nil {
                // Error state
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Analysis failed: \(analyzer.error?.localizedDescription ?? "Unknown error")")
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        if let audioFile = audioManager.audioFile {
                            Task {
                                try? await analyzer.analyzeAudioFile(audioFile.url)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            } else {
                // Empty state
                VStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Structure analysis will appear here")
                        .foregroundColor(.secondary)
                    if audioManager.audioFile != nil {
                        Button("Analyze Structure") {
                            if let audioFile = audioManager.audioFile {
                                Task {
                                    try? await analyzer.analyzeAudioFile(audioFile.url)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
        }
    }
}

/**
 * StructureView
 *
 * A visualization component that renders the detected sections and loop points
 * as an interactive timeline.
 */
struct StructureView: View {
    let sections: [MusicStructureAnalyzer.AudioSection]
    let currentTime: TimeInterval
    let duration: TimeInterval
    let suggestedLoopStart: TimeInterval
    let suggestedLoopEnd: TimeInterval
    @Binding var loopStartTime: TimeInterval
    @Binding var loopEndTime: TimeInterval
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                
                // Sections
                ForEach(sections) { section in
                    let startX = (section.startTime / duration) * geometry.size.width
                    let width = ((section.endTime - section.startTime) / duration) * geometry.size.width
                    
                    Rectangle()
                        .fill(sectionColor(section.type, confidence: section.confidence))
                        .frame(width: max(1, width))
                        .position(x: startX + width/2, y: geometry.size.height/2)
                }
                
                // Suggested loop points
                if suggestedLoopStart < suggestedLoopEnd {
                    // Start marker
                    Rectangle()
                        .fill(Color.green.opacity(0.8))
                        .frame(width: 2, height: geometry.size.height)
                        .position(x: (suggestedLoopStart / duration) * geometry.size.width,
                                 y: geometry.size.height/2)
                    
                    // End marker
                    Rectangle()
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: 2, height: geometry.size.height)
                        .position(x: (suggestedLoopEnd / duration) * geometry.size.width,
                                 y: geometry.size.height/2)
                    
                    // Suggested region
                    Rectangle()
                        .fill(Color.yellow.opacity(0.2))
                        .frame(width: ((suggestedLoopEnd - suggestedLoopStart) / duration) * geometry.size.width)
                        .position(x: ((suggestedLoopStart + suggestedLoopEnd) / 2 / duration) * geometry.size.width,
                                 y: geometry.size.height/2)
                }
                
                // Current position indicator
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: geometry.size.height)
                    .position(x: (currentTime / duration) * geometry.size.width,
                             y: geometry.size.height/2)
            }
            .cornerRadius(8)
            .overlay(
                // Section boundaries
                ForEach(sections) { section in
                    let x = (section.startTime / duration) * geometry.size.width
                    
                    VStack {
                        Text("\(TimeFormatter.formatStandard(section.startTime))")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                        Rectangle()
                            .fill(Color.white.opacity(0.7))
                            .frame(width: 1, height: 8)
                    }
                    .position(x: x, y: 12)
                }
            )
            .onTapGesture { location in
                // Seek to tapped position
                let newTime = (location.x / geometry.size.width) * duration
                EventBus.shared.publishSeekToTime(newTime)
            }
        }
    }
    
    private func sectionColor(_ type: MusicStructureAnalyzer.AudioSection.SectionType, confidence: Float) -> Color {
        switch type {
        case .intro:
            return Color.blue.opacity(0.6 + Double(confidence) * 0.4)
        case .loop:
            return Color.purple.opacity(0.6 + Double(confidence) * 0.4)
        case .transition:
            return Color.green.opacity(0.6 + Double(confidence) * 0.4)
        case .outro:
            return Color.orange.opacity(0.6 + Double(confidence) * 0.4)
        }
    }
}

/**
 * SimilarityMatrixView
 *
 * A visualization of the self-similarity matrix as a heat map.
 * Useful for debugging and understanding the structure analysis.
 */
struct SimilarityMatrixView: View {
    @ObservedObject var analyzer: MusicStructureAnalyzer
    
    var body: some View {
        VStack {
            Text("Self-Similarity Matrix")
                .font(.headline)
            
            if let image = analyzer.generateSimilarityMatrixVisualization() {
                Image(image, scale: 1.0, label: Text("Similarity Matrix"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300, maxHeight: 300)
            } else {
                Text("Matrix not available")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
