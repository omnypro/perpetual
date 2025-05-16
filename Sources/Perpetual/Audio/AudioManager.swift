import AVFoundation
import Combine

class AudioManager: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    
    // Published properties for UI binding
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var loopStartTime: TimeInterval = 0
    @Published var loopEndTime: TimeInterval = 0
    @Published var loopCount: Int = 0 // 0 = infinite
    @Published var currentLoopIteration: Int = 0
    
    // Audio buffer for seamless looping
    private var audioBuffer: AVAudioPCMBuffer?
    private var sampleRate: Double = 44100
    private var positionTimer: Timer?
    
    // More accurate timing tracking
    private var playbackStartTime: TimeInterval = 0
    private var pausedTime: TimeInterval = 0
    private var lastLoopStartTime: TimeInterval = 0
    private var systemStartTime: CFTimeInterval = 0
    
    init() {
        setupAudioEngine()
    }
    
    deinit {
        positionTimer?.invalidate()
        audioEngine.stop()
    }
    
    private func setupAudioEngine() {
        // Connect audio components
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: nil)
        
        // Configure for low latency
        audioEngine.mainMixerNode.outputFormat(forBus: 0)
        
        // Start the engine
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func loadAudioFile(url: URL) throws {
        audioFile = try AVAudioFile(forReading: url)
        
        guard let file = audioFile else { return }
        
        // Update properties
        sampleRate = file.processingFormat.sampleRate
        duration = Double(file.length) / sampleRate
        loopEndTime = duration
        
        // Load entire file into buffer for seamless looping
        let frameCount = UInt32(file.length)
        audioBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount)
        
        guard let buffer = audioBuffer else { return }
        
        // Reset file position to beginning
        file.framePosition = 0
        try file.read(into: buffer)
        buffer.frameLength = frameCount
        
        DispatchQueue.main.async {
            self.duration = self.duration
            self.loopEndTime = self.duration
            self.currentTime = 0
            self.currentLoopIteration = 0
        }
    }
    
    func play() {
        guard !isPlaying, let buffer = audioBuffer else { return }
        
        // Determine start position based on loop settings
        let startPosition: TimeInterval
        
        if loopStartTime > 0 && loopEndTime > loopStartTime {
            // If loop points are set, start from loop start
            startPosition = loopStartTime
            currentTime = loopStartTime
        } else {
            // Otherwise start from current position or beginning
            startPosition = max(0, currentTime)
        }
        
        // Record timing for accurate tracking
        systemStartTime = CACurrentMediaTime()
        playbackStartTime = startPosition
        lastLoopStartTime = loopStartTime
        
        isPlaying = true
        scheduleFromTime(startPosition)
        playerNode.play()
        
        // Start position tracking with higher frequency
        startTrackingPosition()
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        pausedTime = currentTime
        stopTrackingPosition()
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        
        // When stopping, if loop points are set, reset to loop start
        // Otherwise reset to beginning
        if loopStartTime > 0 && loopEndTime > loopStartTime {
            currentTime = loopStartTime
        } else {
            currentTime = 0
        }
        
        currentLoopIteration = 0
        pausedTime = 0
        stopTrackingPosition()
    }
    
    func setLoopPoints(start: TimeInterval, end: TimeInterval) {
        loopStartTime = max(0, min(start, duration))
        loopEndTime = max(loopStartTime, min(end, duration))
        
        // If we're not playing and loop points are valid,
        // move current position to loop start
        if !isPlaying && loopStartTime > 0 && loopEndTime > loopStartTime {
            currentTime = loopStartTime
        }
        
        // If playing, we need to reschedule with new loop points
        if isPlaying {
            lastLoopStartTime = loopStartTime
        }
    }
    
    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        currentTime = clampedTime
        
        if isPlaying {
            // Stop current playback
            playerNode.stop()
            
            // Update timing references
            systemStartTime = CACurrentMediaTime()
            playbackStartTime = clampedTime
            lastLoopStartTime = loopStartTime
            
            // Restart from new position
            scheduleFromTime(clampedTime)
            playerNode.play()
        }
    }
    
    private func scheduleFromTime(_ time: TimeInterval) {
        guard let buffer = audioBuffer else { return }
        
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let endFrame: AVAudioFramePosition
        
        // If loop points are set, use loop end; otherwise use track end
        if loopStartTime > 0 && loopEndTime > loopStartTime && time >= loopStartTime {
            endFrame = AVAudioFramePosition(loopEndTime * sampleRate)
        } else {
            endFrame = AVAudioFramePosition(duration * sampleRate)
        }
        
        let framesToPlay = AVAudioFrameCount(endFrame - startFrame)
        
        // Don't schedule empty segments
        guard framesToPlay > 0 else { return }
        
        // Create a buffer for the segment from current position to end point
        guard let segmentBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: framesToPlay) else { return }
        
        // Copy audio data for the current segment
        let sourceChannels = Int(buffer.format.channelCount)
        for channel in 0..<sourceChannels {
            let sourcePtr = buffer.floatChannelData![channel]
            let destPtr = segmentBuffer.floatChannelData![channel]
            destPtr.update(from: sourcePtr + Int(startFrame), count: Int(framesToPlay))
        }
        segmentBuffer.frameLength = framesToPlay
        
        // Schedule with completion handler for looping
        playerNode.scheduleBuffer(segmentBuffer, at: nil, options: [], completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.handleBufferCompletion()
            }
        })
    }
    
    private func handleBufferCompletion() {
        guard isPlaying else { return }
        
        // Check if we have valid loop points
        if loopStartTime > 0 && loopEndTime > loopStartTime {
            currentLoopIteration += 1
            
            // Check if we should continue looping
            if loopCount == 0 || currentLoopIteration < loopCount {
                // Update timing for the new loop
                systemStartTime = CACurrentMediaTime()
                playbackStartTime = loopStartTime
                currentTime = loopStartTime
                
                // Schedule next loop
                scheduleFromTime(loopStartTime)
            } else {
                // Stop looping
                stop()
            }
        } else {
            // No loop points set, just stop at end
            stop()
        }
    }
    
    private func startTrackingPosition() {
        // Use a higher frequency timer for more accurate tracking
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
        positionTimer?.tolerance = 0.001 // Very tight tolerance
    }
    
    private func stopTrackingPosition() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
    
    private func updateCurrentTime() {
        guard isPlaying else { return }
        
        // Calculate time based on system time elapsed since play started
        let currentSystemTime = CACurrentMediaTime()
        let elapsedTime = currentSystemTime - systemStartTime
        
        // Calculate where we should be
        if loopStartTime > 0 && loopEndTime > loopStartTime {
            // We're in loop mode
            let loopDuration = loopEndTime - loopStartTime
            let timeSinceLoopStart = elapsedTime.truncatingRemainder(dividingBy: loopDuration)
            let calculatedTime = lastLoopStartTime + timeSinceLoopStart
            
            // Clamp to loop boundaries
            let newTime = max(loopStartTime, min(calculatedTime, loopEndTime))
            
            DispatchQueue.main.async {
                self.currentTime = newTime
            }
        } else {
            // Normal playback mode
            let calculatedTime = playbackStartTime + elapsedTime
            let newTime = max(0, min(calculatedTime, duration))
            
            DispatchQueue.main.async {
                self.currentTime = newTime
            }
        }
    }
}
