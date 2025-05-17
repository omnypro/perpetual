import AVFoundation
import Combine

/**
 * AudioManager
 *
 * A class responsible for audio playback with seamless, sample-accurate looping.
 * Uses AVAudioEngine and buffer-based playback to achieve perfect loops without
 * audible gaps or artifacts at loop points.
 *
 * Key features:
 * - Sample-accurate loop point control
 * - Buffer-based playback for seamless transitions
 * - High-precision position tracking
 * - Support for infinite or counted loops
 */
class AudioManager: ObservableObject {
    /// The core audio processing engine
    private let audioEngine = AVAudioEngine()
    
    /// Node responsible for audio playback
    private let playerNode = AVAudioPlayerNode()
    
    /// Reference to the currently loaded audio file
    private var _audioFile: AVAudioFile?
    
    /// Current audio file URL
    private var _audioFileURL: URL?
    
    /// Access to the currently loaded audio file
    var audioFile: AVAudioFile? {
        return _audioFile
    }
    
    /// Access to the current audio file URL
    var audioFileURL: URL? {
        return _audioFileURL
    }
    
    // MARK: - Published Properties
    
    /// Indicates whether audio is currently playing
    @Published var isPlaying = false
    
    /// Current playback position in seconds
    @Published var currentTime: TimeInterval = 0
    
    /// Total duration of the loaded audio in seconds
    @Published var duration: TimeInterval = 0
    
    /// Start point of the loop in seconds
    @Published var loopStartTime: TimeInterval = 0
    
    /// End point of the loop in seconds
    @Published var loopEndTime: TimeInterval = 0
    
    /// Number of times to repeat the loop (0 = infinite)
    @Published var loopCount: Int = 0
    
    /// Current iteration of the loop during playback
    @Published var currentLoopIteration: Int = 0
    
    /// Most recent error encountered during file operations
    @Published var lastError: Error?
    
    // MARK: - Private Properties
    
    /// Buffer containing the entire audio file for seamless looping
    private var audioBuffer: AVAudioPCMBuffer?
    
    /// Provides access to the audio buffer for analysis
    var getPCMBuffer: AVAudioPCMBuffer? {
        return audioBuffer
    }
    
    /// Sample rate of the loaded audio file
    private var sampleRate: Double = 44100
    
    /// Timer for tracking playback position
    private var positionTimer: Timer?
    
    /// Reference time when playback started
    private var playbackStartTime: TimeInterval = 0
    
    /// Time position when playback was paused
    private var pausedTime: TimeInterval = 0
    
    /// Most recent loop start time for position calculations
    private var lastLoopStartTime: TimeInterval = 0
    
    /// System time when playback started/resumed
    private var systemStartTime: CFTimeInterval = 0
    
    // MARK: - Error Types
    
    /// Errors specific to the AudioManager
    enum AudioManagerError: Error, LocalizedError {
        case fileLoadFailed
        case bufferCreationFailed
        case emptyFile
        case invalidFormat
        case readError(Error)
        case engineStartFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .fileLoadFailed:
                return "Failed to load audio file"
            case .bufferCreationFailed:
                return "Failed to create audio buffer"
            case .emptyFile:
                return "Audio file is empty"
            case .invalidFormat:
                return "Audio file has an unsupported format"
            case .readError(let error):
                return "Failed to read audio data: \(error.localizedDescription)"
            case .engineStartFailed(let error):
                return "Failed to start audio engine: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Lifecycle
    
    /**
     * Initializes the AudioManager and sets up the audio engine.
     */
    init() {
        setupAudioEngine()
    }
    
    /**
     * Cleans up resources when the manager is deallocated.
     */
    deinit {
        positionTimer?.invalidate()
        audioEngine.stop()
    }
    
    // MARK: - Audio Engine Setup
    
    /**
     * Configures the audio engine and connects components.
     * Sets up the signal chain and starts the audio engine.
     *
     * - Throws: AudioManagerError if engine fails to start
     */
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
            lastError = AudioManagerError.engineStartFailed(error)
            print("Failed to start audio engine: \(error)")
        }
    }
    
    // MARK: - File Loading
    
    /**
     * Loads an audio file into memory for playback.
     *
     * Reads the entire audio file into a buffer to enable seamless looping.
     * This approach ensures no gaps occur at loop points by allowing precise 
     * buffer scheduling.
     *
     * - Parameter url: The URL of the audio file to load
     * - Throws: AudioManagerError if file cannot be loaded, buffer creation fails,
     *           the file is empty, or if reading the audio data fails
     */
    func loadAudioFile(url: URL) throws {
        // Reset error state
        lastError = nil
        
        do {
            // Create audio file object
            let file = try AVAudioFile(forReading: url)
            
            // Check that file has valid frame count
            let frameCount = file.length
            guard frameCount > 0 else {
                throw AudioManagerError.emptyFile
            }
            
            _audioFile = file
            _audioFileURL = url
            
            // Update properties
            sampleRate = file.processingFormat.sampleRate
            duration = Double(frameCount) / sampleRate
            
            // Create buffer with capacity for entire file
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, 
                                              frameCapacity: UInt32(frameCount)) else {
                throw AudioManagerError.bufferCreationFailed
            }
            
            // Reset file position and read into buffer
            file.framePosition = 0
            try file.read(into: buffer)
            buffer.frameLength = UInt32(frameCount)
            
            // Store buffer for playback
            audioBuffer = buffer
            
            // Update UI-related properties on main thread
            DispatchQueue.main.async {
                self.loopEndTime = self.duration
                self.currentTime = 0
                self.currentLoopIteration = 0
            }
        } catch let error as AudioManagerError {
            // Forward our custom errors
            lastError = error
            throw error
        } catch {
            // Wrap system errors
            let wrappedError = AudioManagerError.readError(error)
            lastError = wrappedError
            throw wrappedError
        }
    }
    
    // MARK: - Playback Control
    
    /**
     * Starts or resumes audio playback.
     *
     * If loop points are set, playback will start from the loop start point.
     * Otherwise, it starts from the current position or the beginning if at 0.
     */
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
    
    /**
     * Pauses audio playback while maintaining the current position.
     */
    func pause() {
        playerNode.pause()
        isPlaying = false
        pausedTime = currentTime
        stopTrackingPosition()
    }
    
    /**
     * Stops playback and resets position.
     *
     * If loop points are set, current position will reset to loop start.
     * Otherwise, it resets to the beginning of the track.
     */
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
    
    /**
     * Sets the loop start and end points for repeated playback.
     *
     * If not playing, updates the current position to the loop start.
     * If playing, the new loop points will take effect at the next loop iteration.
     *
     * - Parameters:
     *   - start: Loop start point in seconds
     *   - end: Loop end point in seconds
     */
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
    
    /**
     * Seeks to a specific time position in the audio.
     *
     * - Parameter time: Destination time in seconds
     */
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
    
    // MARK: - Internal Playback Functions
    
    /**
     * Schedules audio playback from a specific time position.
     *
     * Creates a buffer segment from the specified time to either the loop end
     * or the track end, depending on loop settings.
     *
     * - Parameter time: Start time in seconds
     */
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
        guard let segmentBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: framesToPlay) else {
            lastError = AudioManagerError.bufferCreationFailed
            return
        }
        
        // Copy audio data for the current segment
        let sourceChannels = Int(buffer.format.channelCount)
        for channel in 0..<sourceChannels {
            guard let sourcePtr = buffer.floatChannelData?[channel],
                  let destPtr = segmentBuffer.floatChannelData?[channel] else {
                continue
            }
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
    
    /**
     * Handles completion of buffer playback for looping.
     *
     * Called when the current buffer segment finishes playing.
     * Schedules the next segment if in loop mode, otherwise stops playback.
     */
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
    
    // MARK: - Position Tracking
    
    /**
     * Starts the timer for tracking playback position.
     *
     * Uses a high-frequency timer to achieve near sample-accurate position tracking.
     */
    private func startTrackingPosition() {
        // Use a higher frequency timer for more accurate tracking
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.updateCurrentTime()
        }
        positionTimer?.tolerance = 0.001 // Very tight tolerance
    }
    
    /**
     * Stops the position tracking timer.
     */
    private func stopTrackingPosition() {
        positionTimer?.invalidate()
        positionTimer = nil
    }
    
    /**
     * Updates the current time based on elapsed system time.
     *
     * Calculates the current playback position using precise time measurements
     * rather than relying on AVAudioPlayerNode's less accurate position reporting.
     */
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
