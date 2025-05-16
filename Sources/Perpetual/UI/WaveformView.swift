import SwiftUI
import AVFoundation
import Accelerate

struct WaveformView: View {
    @StateObject private var waveformData = WaveformData()
    @Binding var audioFile: AVAudioFile?
    @Binding var currentTime: TimeInterval
    @Binding var loopStartTime: TimeInterval
    @Binding var loopEndTime: TimeInterval
    @Binding var duration: TimeInterval
    
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false
    @State private var isSeekingPosition = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.black)
                
                // Waveform path
                if let waveform = waveformData.waveformPath {
                    waveform
                        .stroke(Color.cyan, lineWidth: 1.5)
                        .opacity(0.8)
                }
                
                // Loop region highlight - make more prominent
                if duration > 0 {
                    let startX = (loopStartTime / duration) * geometry.size.width
                    let endX = (loopEndTime / duration) * geometry.size.width
                    let width = max(0, endX - startX)
                    
                    Rectangle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: width)
                        .position(x: startX + width/2, y: geometry.size.height/2)
                        .overlay(
                            // Add subtle border to loop region
                            Rectangle()
                                .stroke(Color.yellow, lineWidth: 2)
                                .opacity(0.6)
                                .frame(width: width)
                                .position(x: startX + width/2, y: geometry.size.height/2)
                        )
                }
                
                // Current position indicator - make more visible
                if duration > 0 && currentTime >= 0 {
                    let positionX = (currentTime / duration) * geometry.size.width
                    
                    // Current position line with glow effect
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 3)
                        .position(x: positionX, y: geometry.size.height/2)
                        .overlay(
                            Rectangle()
                                .fill(Color.red.opacity(0.5))
                                .frame(width: 6)
                                .position(x: positionX, y: geometry.size.height/2)
                                .blur(radius: 2)
                        )
                }
                
                // Loop markers - make much more visible
                if duration > 0 {
                    // Start marker
                    LoopMarker(
                        time: $loopStartTime,
                        duration: duration,
                        geometry: geometry,
                        color: .green,
                        isDragging: $isDraggingStart,
                        label: "START"
                    )
                    
                    // End marker
                    LoopMarker(
                        time: $loopEndTime,
                        duration: duration,
                        geometry: geometry,
                        color: .orange,
                        isDragging: $isDraggingEnd,
                        label: "END"
                    )
                }
            }
            .onAppear {
                loadWaveform()
            }
            .onChange(of: audioFile) { _ in
                loadWaveform()
            }
            .onTapGesture { location in
                // Seek to tapped position
                if !isDraggingStart && !isDraggingEnd {
                    let newTime = (location.x / geometry.size.width) * duration
                    NotificationCenter.default.post(name: .seekToTime, object: newTime)
                }
            }
        }
        .aspectRatio(4, contentMode: .fit)
    }
    
    private func loadWaveform() {
        guard let file = audioFile else { return }
        waveformData.generateWaveform(from: file)
    }
}

struct LoopMarker: View {
    @Binding var time: TimeInterval
    let duration: TimeInterval
    let geometry: GeometryProxy
    let color: Color
    @Binding var isDragging: Bool
    let label: String
    
    var body: some View {
        let x = (time / duration) * geometry.size.width
        
        ZStack {
            // Vertical line
            Rectangle()
                .fill(color)
                .frame(width: 3, height: geometry.size.height)
                .overlay(
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(width: 6, height: geometry.size.height)
                        .blur(radius: 1)
                )
            
            // Top handle with label
            VStack(spacing: 4) {
                // Label
                Text(label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color)
                    .cornerRadius(4)
                
                // Handle circle
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .scaleEffect(isDragging ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isDragging)
                
                Spacer()
            }
        }
        .position(x: x, y: geometry.size.height/2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    let newX = max(0, min(value.location.x, geometry.size.width))
                    let newTime = (newX / geometry.size.width) * duration
                    time = newTime
                }
                .onEnded { _ in
                    isDragging = false
                    NotificationCenter.default.post(name: .loopPointsChanged, object: nil)
                }
        )
    }
}

class WaveformData: ObservableObject {
    @Published var waveformPath: Path?
    private let resolution: Int = 2000 // Increased for better detail
    
    func generateWaveform(from audioFile: AVAudioFile) {
        DispatchQueue.global(qos: .userInitiated).async {
            let waveform = self.generateWaveformPath(from: audioFile)
            DispatchQueue.main.async {
                self.waveformPath = waveform
            }
        }
    }
    
    private func generateWaveformPath(from audioFile: AVAudioFile) -> Path? {
        let frameCount = Int(audioFile.length)
        let samplesPerPixel = max(1, frameCount / resolution)
        
        // Reset file position
        audioFile.framePosition = 0
        
        // Read audio data
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(frameCount)) else { return nil }
        
        do {
            try audioFile.read(into: buffer)
        } catch {
            print("Error reading audio file: \(error)")
            return nil
        }
        
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else { return nil }
        
        let samples = channelData[0]
        var waveformSamples: [Float] = []
        
        // Downsample with RMS for better representation
        for i in stride(from: 0, to: frameCount, by: samplesPerPixel) {
            let endIndex = min(i + samplesPerPixel, frameCount)
            var sum: Float = 0
            var count = 0
            
            for j in i..<endIndex {
                sum += samples[j] * samples[j]
                count += 1
            }
            
            let rms = count > 0 ? sqrt(sum / Float(count)) : 0
            waveformSamples.append(rms)
        }
        
        // Create path with better scaling
        var path = Path()
        let height: CGFloat = 100
        let width: CGFloat = 400
        
        for (index, sample) in waveformSamples.enumerated() {
            let x = CGFloat(index) / CGFloat(waveformSamples.count) * width
            let normalizedSample = min(CGFloat(sample) * 2, 1.0) // Scale for better visibility
            let y = height/2 - normalizedSample * height/2
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Mirror for symmetrical waveform
        for (index, sample) in waveformSamples.enumerated().reversed() {
            let x = CGFloat(index) / CGFloat(waveformSamples.count) * width
            let normalizedSample = min(CGFloat(sample) * 2, 1.0)
            let y = height/2 + normalizedSample * height/2
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.closeSubpath()
        return path
    }
}

extension Notification.Name {
    static let seekToTime = Notification.Name("seekToTime")
    static let loopPointsChanged = Notification.Name("loopPointsChanged")
}
