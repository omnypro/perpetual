import AVFoundation
import Combine

class AudioManager: ObservableObject {
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var displayLink: CVDisplayLink?
    
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
        
        isPlaying = true
        scheduleBuffer(buffer)
        playerNode.play()
        
        // Start position tracking
        startTrackingPosition()
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopTrackingPosition()
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        currentTime = 0
        currentLoopIteration = 0
        stopTrackingPosition()
    }
    
    func setLoopPoints(start: TimeInterval, end: TimeInterval) {
        loopStartTime = max(0, min(start, duration))
        loopEndTime = max(loopStartTime, min(end, duration))
    }
    
    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        currentTime = clampedTime
        
        if isPlaying {
            // Restart playback from new position
            playerNode.stop()
            scheduleFromTime(clampedTime)
            playerNode.play()
        }
    }
    
    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer) {
        let startFrame = AVAudioFramePosition(loopStartTime * sampleRate)
        scheduleFromFrame(startFrame)
    }
    
    private func scheduleFromTime(_ time: TimeInterval) {
        let frame = AVAudioFramePosition(time * sampleRate)
        scheduleFromFrame(frame)
    }
    
    private func scheduleFromFrame(_ startFrame: AVAudioFramePosition) {
        guard let buffer = audioBuffer else { return }
        
        let loopStartFrame = AVAudioFramePosition(loopStartTime * sampleRate)
        let loopEndFrame = AVAudioFramePosition(loopEndTime * sampleRate)
        let loopFrameCount = AVAudioFrameCount(loopEndFrame - loopStartFrame)
        
        // Create buffer for current loop segment
        guard let loopBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: loopFrameCount) else { return }
        
        // Copy audio data for current loop
        let sourceChannels = Int(buffer.format.channelCount)
        for channel in 0..<sourceChannels {
            let sourcePtr = buffer.floatChannelData![channel]
            let destPtr = loopBuffer.floatChannelData![channel]
            destPtr.update(from: sourcePtr + Int(loopStartFrame), count: Int(loopFrameCount))
        }
        loopBuffer.frameLength = loopFrameCount
        
        // Schedule with loop-aware completion handler
        playerNode.scheduleBuffer(loopBuffer, at: nil, options: [], completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.handleBufferCompletion()
            }
        })
    }
    
    private func handleBufferCompletion() {
        guard isPlaying else { return }
        
        currentLoopIteration += 1
        
        // Check if we should continue looping
        if loopCount == 0 || currentLoopIteration < loopCount {
            // Schedule next loop
            currentTime = loopStartTime
            scheduleFromTime(loopStartTime)
        } else {
            // Stop looping
            stop()
        }
    }
    
    private func startTrackingPosition() {
        // Use Timer for position updates (simpler than CVDisplayLink for this use case)
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
        positionTimer?.tolerance = 0.005 // Allow 5ms tolerance for better performance
    }
    
    private func stopTrackingPosition() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
    
    private func updateCurrentTime() {
        guard isPlaying else { return }
        
        // Calculate current playback position
        guard let lastRenderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) else {
            return
        }
        
        let sampleTime = playerTime.sampleTime
        let sessionSampleRate = audioEngine.mainMixerNode.outputFormat(forBus: 0).sampleRate
        
        // Calculate elapsed time since loop start
        let totalElapsedTime = Double(sampleTime) / sessionSampleRate
        let loopDuration = loopEndTime - loopStartTime
        
        // Calculate position within current loop
        let positionInLoop = totalElapsedTime.truncatingRemainder(dividingBy: loopDuration)
        let currentPosition = loopStartTime + positionInLoop
        
        DispatchQueue.main.async {
            self.currentTime = currentPosition
        }
    }
}
