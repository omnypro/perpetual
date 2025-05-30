import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import Combine
import Foundation

struct ContentView: View {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var structureAnalyzer = MusicStructureAnalyzer()
    @State private var selectedFile: AVAudioFile?
    @State private var showingFilePicker = false
    @State private var selectedTab = 0 // Add this to track tab selection
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()
            
            // Tab View for Player and Debug
            TabView(selection: $selectedTab) {
                // Main Player Tab
                VStack(spacing: 20) {
                    if selectedFile != nil {
                        PlayerView(audioManager: audioManager, audioFile: $selectedFile)
                    } else {
                        EmptyStateView {
                            showingFilePicker = true
                        }
                    }
                    Spacer()
                }
                .tabItem {
                    Image(systemName: "waveform.path.ecg")
                    Text("Player")
                }
                .tag(0)
                
                // Debug Tab
                if selectedFile != nil {
                    DebugView(audioManager: audioManager)
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Debug")
                        }
                        .tag(1)
                    
                    // Structure Analysis Tab
                    StructureVisualizerView(analyzer: structureAnalyzer, audioManager: audioManager)
                        .tabItem {
                            Image(systemName: "waveform.path")
                            Text("Structure")
                        }
                        .tag(2)
                }
            }
        }
        .padding()
        .onAppear {
            setupEventSubscriptions()
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.audio, UTType.mp3, UTType.wav, UTType.aiff],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let file = files.first {
                    // Ensure we have access to the file
                    _ = file.startAccessingSecurityScopedResource()
                    defer { file.stopAccessingSecurityScopedResource() }
                    
                    loadAudioFile(url: file)
                }
            case .failure(let error):
                print("Error loading file: \(error)")
            }
        }
    }
    
    private func setupEventSubscriptions() {
        // Subscribe to open file events
        EventBus.shared.openFilePublisher
            .sink { _ in
                showingFilePicker = true
            }
            .store(in: &cancellables)
        
        // Subscribe to seek time events
        EventBus.shared.seekToTimePublisher
            .sink { time in
                audioManager.seek(to: time)
            }
            .store(in: &cancellables)
        
        // Subscribe to loop points changed events
        EventBus.shared.loopPointsChangedPublisher
            .sink { _ in
                audioManager.setLoopPoints(start: audioManager.loopStartTime, end: audioManager.loopEndTime)
            }
            .store(in: &cancellables)
            
        // Subscribe to audio error events (optional)
        EventBus.shared.audioErrorPublisher
            .sink { error in
                print("Audio error: \(error.localizedDescription)")
                // Could implement UI feedback for errors here
            }
            .store(in: &cancellables)
    }
    
    private func loadAudioFile(url: URL) {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            selectedFile = audioFile
            try audioManager.loadAudioFile(url: url)
        } catch {
            print("Error loading audio file: \(error)")
            // Could add user-facing error handling here
        }
    }
}

struct HeaderView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Perpetual")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Perfect Music Loops")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Placeholder for app icon - you can add actual icon later
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.white)
                        .font(.title)
                )
        }
        .padding(.vertical)
    }
}

struct PlayerView: View {
    @ObservedObject var audioManager: AudioManager
    @Binding var audioFile: AVAudioFile?
    
    var body: some View {
        VStack(spacing: 24) {
            // Track info
            TrackInfoView(audioFile: audioFile)
            
            // Waveform
            WaveformView(
                audioFile: $audioFile,
                currentTime: $audioManager.currentTime,
                loopStartTime: $audioManager.loopStartTime,
                loopEndTime: $audioManager.loopEndTime,
                duration: $audioManager.duration
            )
            .frame(height: 120)
            .background(Color.black)
            .cornerRadius(8)
            
            // Transport controls
            TransportControlsView(audioManager: audioManager)
            
            // Loop controls
            LoopControlsView(audioManager: audioManager)
        }
    }
}

struct EmptyStateView: View {
    let onOpenFile: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Audio File Selected")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Choose an audio file to create perfect loops")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Button("Open Audio File") {
                onOpenFile()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TrackInfoView: View {
    let audioFile: AVAudioFile?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(filename)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(formatDuration())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Add metadata display here if needed
        }
        .padding(.horizontal)
    }
    
    private var filename: String {
        audioFile?.url.lastPathComponent ?? "Unknown Track"
    }
    
    private func formatDuration() -> String {
        guard let file = audioFile else { return "00:00" }
        let duration = Double(file.length) / file.processingFormat.sampleRate
        return TimeFormatter.formatStandard(duration)
    }
}

struct TransportControlsView: View {
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        HStack(spacing: 24) {
            Button(action: audioManager.stop) {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .disabled(!audioManager.isPlaying)
            
            Button(action: togglePlayback) {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
            
            // Time display
            VStack(alignment: .trailing, spacing: 4) {
                Text(TimeFormatter.formatStandard(audioManager.currentTime))
                    .font(.title3)
                    .fontWeight(.medium)
                Text("/ \(TimeFormatter.formatStandard(audioManager.duration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private func togglePlayback() {
        if audioManager.isPlaying {
            audioManager.pause()
        } else {
            audioManager.play()
        }
    }
}

struct LoopControlsView: View {
    @ObservedObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Loop count selector
            HStack {
                Text("Loop Count:")
                    .font(.headline)
                
                Picker("Loop Count", selection: $audioManager.loopCount) {
                    Text("∞ Infinite").tag(0)
                    ForEach(1...20, id: \.self) { count in
                        Text("\(count) times").tag(count)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                if audioManager.loopCount > 0 {
                    Text("\(audioManager.currentLoopIteration) / \(audioManager.loopCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Loop time range
            HStack {
                VStack(alignment: .leading) {
                    Text("Loop Range")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("Start: \(TimeFormatter.formatPrecise(audioManager.loopStartTime))")
                        Text("End: \(TimeFormatter.formatPrecise(audioManager.loopEndTime))")
                        Spacer()
                        Text("Duration: \(TimeFormatter.formatPrecise(audioManager.loopEndTime - audioManager.loopStartTime))")
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}
