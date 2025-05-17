import AVFoundation
import Accelerate
import Foundation
import Combine

/**
 * MusicStructureAnalyzer
 *
 * A class responsible for analyzing audio structure at a macro level to identify
 * loop points suitable for game music. Uses feature extraction and self-similarity
 * analysis to detect major compositional sections.
 *
 * Key features:
 * - Macro-level audio analysis with large time windows
 * - Self-similarity matrix visualization
 * - Game music pattern recognition
 * - Automatic detection of intro and looping sections
 */
class MusicStructureAnalyzer: ObservableObject {
    // Analysis results
    @Published var sections: [AudioSection] = []
    @Published var suggestedLoopStart: TimeInterval = 0
    @Published var suggestedLoopEnd: TimeInterval = 0
    
    // Analysis state
    @Published var isAnalyzing: Bool = false
    @Published var progress: Double = 0
    @Published var error: Error? = nil
    
    // Audio features
    private var audioBuffer: AVAudioPCMBuffer? = nil
    private var audioFormat: AVAudioFormat? = nil
    private var sampleRate: Double = 44100
    private var features: [AudioFeatures] = []
    private var similarityMatrix: [[Float]]? = nil
    
    // Analysis parameters
    private let windowSize: Int = 8192  // Smaller for better temporal resolution
    private let hopSize: Int = 4096     // 50% overlap still
    private let minSectionDuration: Double = 2.0 // Allow shorter sections for game music
    
    struct AudioFeatures {
        var timeOffset: TimeInterval
        var rms: Float
        var spectralCentroid: Float
        var spectralFlux: Float
        var zeroCrossingRate: Float
    }
    
    struct AudioSection: Identifiable {
        var id = UUID()
        var startTime: TimeInterval
        var endTime: TimeInterval
        var type: SectionType
        var confidence: Float
        
        enum SectionType {
            case intro
            case loop
            case transition
            case outro
        }
    }
    
    /**
     * Analyzes an audio file to find its structure and suggest optimal loop points.
     *
     * - Parameter url: The URL of the audio file to analyze
     * - Throws: Error if analysis fails
     */
    func analyzeAudioFile(_ url: URL) async throws {
        // Reset state
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.progress = 0
            self.error = nil
            self.sections = []
        }
        
        do {
            // Load audio file
            let audioFile = try AVAudioFile(forReading: url)
            let processingFormat = audioFile.processingFormat
            
            DispatchQueue.main.async {
                self.sampleRate = processingFormat.sampleRate
                self.audioFormat = processingFormat
            }
            
            // Load entire file into buffer for analysis
            let frameCount = audioFile.length
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat,
                                              frameCapacity: AVAudioFrameCount(frameCount)) else {
                throw NSError(domain: "MusicStructureAnalyzer", code: 1, userInfo:
                             [NSLocalizedDescriptionKey: "Failed to create audio buffer"])
            }
            
            try audioFile.read(into: buffer)
            
            DispatchQueue.main.async {
                self.audioBuffer = buffer
            }
            
            // Extract features in chunks
            try await extractAudioFeatures(from: buffer)
            
            // Build self-similarity matrix
            buildSimilarityMatrix()
            
            // Detect sections
            detectSections()
            
            // Apply game music heuristics to find optimal loop points
            findGameMusicLoopPoints()
            
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.progress = 1.0
            }
        } catch {
            DispatchQueue.main.async {
                self.isAnalyzing = false
                self.error = error
            }
            throw error
        }
    }
    
    private func extractAudioFeatures(from buffer: AVAudioPCMBuffer) async throws {
        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "MusicStructureAnalyzer", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "No channel data in buffer"])
        }
        
        // Get samples from the first channel
        let samples = channelData[0]
        let totalFrames = Int(buffer.frameLength)
        
        // Extract features with larger windows for macro analysis
        var features: [AudioFeatures] = []
        let totalWindows = (totalFrames - windowSize) / hopSize + 1
        
        for windowIndex in 0..<totalWindows {
            // Report progress
            let progress = Double(windowIndex) / Double(totalWindows)
            DispatchQueue.main.async {
                self.progress = progress * 0.5 // First half of the analysis process
            }
            
            // Process in batches to avoid blocking the main thread
            if windowIndex % 10 == 0 {
                try await Task.sleep(nanoseconds: 1_000_000) // 1ms pause
            }
            
            let startFrame = windowIndex * hopSize
            let timeOffset = Double(startFrame) / sampleRate
            
            // Extract features for this window
            let windowSamples = Array(UnsafeBufferPointer(start: samples.advanced(by: startFrame), count: windowSize))
            
            // Calculate features
            let rms = calculateRMS(samples: windowSamples)
            let spectralCentroid = calculateSpectralCentroid(samples: windowSamples, sampleRate: Float(sampleRate))
            let spectralFlux = windowIndex > 0 ?
                calculateSpectralFlux(current: windowSamples, previous: Array(UnsafeBufferPointer(start: samples.advanced(by: (windowIndex-1) * hopSize), count: windowSize))) : 0
            let zcr = calculateZeroCrossingRate(samples: windowSamples)
            
            // Store features
            features.append(AudioFeatures(
                timeOffset: timeOffset,
                rms: rms,
                spectralCentroid: spectralCentroid,
                spectralFlux: spectralFlux,
                zeroCrossingRate: zcr
            ))
        }
        
        DispatchQueue.main.async {
            self.features = features
        }
    }
    
    private func calculateRMS(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        
        // Square all values
        var squaredSamples = [Float](repeating: 0, count: samples.count)
        vDSP_vsq(samples, 1, &squaredSamples, 1, vDSP_Length(samples.count))
        
        // Calculate mean
        var mean: Float = 0
        vDSP_meanv(squaredSamples, 1, &mean, vDSP_Length(samples.count))
        
        return sqrt(mean)
    }

    private func calculateSpectralCentroid(samples: [Float], sampleRate: Float) -> Float {
        // Setup FFT
        let log2n = vDSP_Length(log2(Float(samples.count)))
        let fftSize = Int(1 << log2n)
        
        // Zero-pad if needed
        var paddedSamples = samples
        if samples.count < fftSize {
            paddedSamples.append(contentsOf: [Float](repeating: 0, count: fftSize - samples.count))
        }
        
        // Apply window function
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&windowedSamples, vDSP_Length(fftSize), Int32(0))
        vDSP_vmul(paddedSamples, 1, windowedSamples, 1, &windowedSamples, 1, vDSP_Length(fftSize))
        
        // Prepare FFT
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        var realp = [Float](repeating: 0, count: fftSize/2)
        var imagp = [Float](repeating: 0, count: fftSize/2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        // Convert to split complex format
        windowedSamples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize/2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize/2))
            }
        }
        
        // Perform forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
        
        // Calculate centroid
        var sum: Float = 0
        var weightedSum: Float = 0
        
        for bin in 0..<fftSize/2 {
            let frequency = Float(bin) * sampleRate / Float(fftSize)
            sum += magnitudes[bin]
            weightedSum += frequency * magnitudes[bin]
        }
        
        vDSP_destroy_fftsetup(fftSetup)
        
        return sum > 0 ? weightedSum / sum : 0
    }

    private func calculateSpectralFlux(current: [Float], previous: [Float]) -> Float {
        // Setup FFT
        let log2n = vDSP_Length(log2(Float(current.count)))
        let fftSize = Int(1 << log2n)
        
        // Calculate magnitude spectra for both windows
        let currentMagnitudes = calculateMagnitudeSpectrum(samples: current, fftSize: fftSize)
        let previousMagnitudes = calculateMagnitudeSpectrum(samples: previous, fftSize: fftSize)
        
        // Calculate spectral flux (squared difference between magnitude spectra)
        var diff = [Float](repeating: 0, count: currentMagnitudes.count)
        vDSP_vsub(previousMagnitudes, 1, currentMagnitudes, 1, &diff, 1, vDSP_Length(currentMagnitudes.count))
        
        // Rectify - keep only increases in energy (half-wave rectification)
        for i in 0..<diff.count {
            diff[i] = max(0, diff[i])
        }
        
        // Sum the differences
        var sum: Float = 0
        vDSP_sve(diff, 1, &sum, vDSP_Length(diff.count))
        
        return sum
    }

    private func calculateMagnitudeSpectrum(samples: [Float], fftSize: Int) -> [Float] {
        // Apply window function
        var windowedSamples = [Float](repeating: 0, count: fftSize)
        let samplesCount = min(samples.count, fftSize)
        
        // Copy samples to windowed buffer
        samples.withUnsafeBufferPointer { ptr in
            windowedSamples.withUnsafeMutableBufferPointer { dst in
                dst.baseAddress!.update(from: ptr.baseAddress!, count: samplesCount)
            }
        }
        
        // Apply Hann window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(0))
        vDSP_vmul(windowedSamples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))
        
        // Prepare FFT
        let log2n = vDSP_Length(log2(Float(fftSize)))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        var realp = [Float](repeating: 0, count: fftSize/2)
        var imagp = [Float](repeating: 0, count: fftSize/2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        // Convert to split complex format
        windowedSamples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize/2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize/2))
            }
        }
        
        // Perform forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
        
        vDSP_destroy_fftsetup(fftSetup)
        
        return magnitudes
    }

    private func calculateZeroCrossingRate(samples: [Float]) -> Float {
        var count: Int = 0
        
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i-1] < 0) || (samples[i] < 0 && samples[i-1] >= 0) {
                count += 1
            }
        }
        
        return Float(count) / Float(samples.count)
    }
    
    private func buildSimilarityMatrix() {
        let featureCount = features.count
        var matrix = [[Float]](repeating: [Float](repeating: 0, count: featureCount), count: featureCount)
        
        for i in 0..<featureCount {
            // Report progress
            if i % 10 == 0 {
                let progress = Double(i) / Double(featureCount)
                DispatchQueue.main.async {
                    self.progress = 0.5 + progress * 0.25 // Second quarter of analysis
                }
            }
            
            for j in 0..<featureCount {
                // Calculate Euclidean distance between feature vectors - adjusted weights
                let rmsDiff = features[i].rms - features[j].rms
                let centroidDiff = features[i].spectralCentroid - features[j].spectralCentroid
                let fluxDiff = features[i].spectralFlux - features[j].spectralFlux
                let zcrDiff = features[i].zeroCrossingRate - features[j].zeroCrossingRate

                // Enhanced normalized Euclidean distance with larger weights on flux
                // Spectral flux is very sensitive to musical changes
                let distance = sqrt(
                    pow(rmsDiff * 1.5, 2) +        // Volume changes
                    pow(centroidDiff * 1.0, 2) +   // Timbre changes
                    pow(fluxDiff * 3.0, 2) +       // Heavily emphasize spectral changes
                    pow(zcrDiff * 0.5, 2)          // Noise vs. tone
                )
                
                // Convert distance to similarity (higher value = more similar)
                matrix[i][j] = 1.0 - min(1.0, distance / 2.0)
            }
        }
        
        DispatchQueue.main.async {
            self.similarityMatrix = matrix
        }
    }

    private func detectSections() {
        // Instead of relying on the similarity matrix, let's use direct feature analysis
        guard !features.isEmpty else { return }
        
        // We'll track large changes in spectral flux and RMS
        var changePoints: [Int] = []
        let halfWindowSize = 4 // Look 4 frames before and after
        
        print("Analyzing \(features.count) feature frames for direct changes")
        
        // 1. Look for significant changes in spectral flux and RMS
        if features.count > (halfWindowSize * 2 + 1) {
            for i in halfWindowSize..<(features.count - halfWindowSize) {
                // Calculate average features before and after
                var fluxBefore: Float = 0
                var rmsBefore: Float = 0
                var fluxAfter: Float = 0
                var rmsAfter: Float = 0
                
                for j in 1...halfWindowSize {
                    fluxBefore += features[i-j].spectralFlux
                    rmsBefore += features[i-j].rms
                    fluxAfter += features[i+j].spectralFlux
                    rmsAfter += features[i+j].rms
                }
                
                fluxBefore /= Float(halfWindowSize)
                rmsBefore /= Float(halfWindowSize)
                fluxAfter /= Float(halfWindowSize)
                rmsAfter /= Float(halfWindowSize)
                
                // Calculate relative differences
                let fluxDiff = abs(fluxAfter - fluxBefore) / max(0.001, (fluxAfter + fluxBefore) / 2)
                let rmsDiff = abs(rmsAfter - rmsBefore) / max(0.001, (rmsAfter + rmsBefore) / 2)
                
                // If there's a significant change in either flux or RMS, mark it
                if fluxDiff > 0.5 || rmsDiff > 0.4 {
                    changePoints.append(i)
                }
            }
        }
        
        print("Found \(changePoints.count) raw change points")
        
        // 2. Merge change points that are too close
        let minFrameDistance = Int(minSectionDuration * sampleRate / Double(hopSize))
        var filteredChangePoints: [Int] = []
        
        if !changePoints.isEmpty {
            filteredChangePoints.append(changePoints[0])
            
            for point in changePoints.dropFirst() {
                if let lastPoint = filteredChangePoints.last, point - lastPoint >= minFrameDistance {
                    filteredChangePoints.append(point)
                }
            }
        }
        
        print("After filtering, keeping \(filteredChangePoints.count) change points")
        
        // 3. If we still don't have enough sections, force division
        if filteredChangePoints.count < 2 && features.count > 20 {
            print("Not enough change points detected - forcing divisions")
            
            // Divide into 3 roughly equal parts as a fallback
            let third = features.count / 3
            if third >= minFrameDistance {
                filteredChangePoints = [third, third * 2]
                print("Forced division into 3 parts at indices \(third) and \(third * 2)")
            }
        }
        
        // 4. Convert to time boundaries
        var boundaries: [TimeInterval] = filteredChangePoints.map { features[$0].timeOffset }
        
        // Always include start and end points
        boundaries.insert(0, at: 0)
        if let audioBuffer = audioBuffer {
            let duration = Double(audioBuffer.frameLength) / sampleRate
            if !boundaries.contains(where: { abs($0 - duration) < 0.1 }) {
                boundaries.append(duration)
            }
        }
        
        // Sort boundaries (just in case)
        boundaries.sort()
        
        // 5. Create sections
        var detectedSections: [AudioSection] = []
        for i in 0..<(boundaries.count - 1) {
            let startTime = boundaries[i]
            let endTime = boundaries[i+1]
            
            // Only add if section is long enough
            if endTime - startTime >= minSectionDuration {
                // Determine section type
                let type: AudioSection.SectionType
                if i == 0 {
                    type = .intro
                } else if i == boundaries.count - 2 {
                    type = .outro
                } else {
                    type = .loop
                }
                
                detectedSections.append(AudioSection(
                    id: UUID(),
                    startTime: startTime,
                    endTime: endTime,
                    type: type,
                    confidence: 0.7
                ))
            }
        }
        
        print("Detected \(detectedSections.count) sections:")
        for section in detectedSections {
            print("Section from \(section.startTime) to \(section.endTime), type: \(section.type), confidence: \(section.confidence)")
        }
        
        DispatchQueue.main.async {
            self.sections = detectedSections
        }
    }

    private func findPeaks(in signal: [Float], minDistance: Int, threshold: Float) -> [Int] {
        var peaks: [Int] = []
        
        // Find all peaks
        for i in 2..<signal.count-2 {
            // More robust peak detection - check 2 points in each direction
            if signal[i] > signal[i-1] && signal[i] > signal[i-2] &&
               signal[i] > signal[i+1] && signal[i] > signal[i+2] &&
               signal[i] > threshold {
                peaks.append(i)
            }
        }
        
        print("Found \(peaks.count) potential peaks with threshold \(threshold)")
        
        // Filter peaks by minimum distance and prominence
        var filteredPeaks: [Int] = []
        
        if !peaks.isEmpty {
            // Sort peaks by amplitude (highest first)
            let sortedPeaks = peaks.sorted { signal[$0] > signal[$1] }
            
            // Add the strongest peak first
            filteredPeaks.append(sortedPeaks[0])
            
            // Add other peaks if they're far enough from existing ones
            for peak in sortedPeaks[1...] {
                let isFarEnough = filteredPeaks.allSatisfy { abs(peak - $0) >= minDistance }
                if isFarEnough {
                    filteredPeaks.append(peak)
                }
            }
            
            // Sort by position (ascending)
            filteredPeaks.sort()
        }
        
        print("After filtering, keeping \(filteredPeaks.count) peaks")
        
        return filteredPeaks
    }

    private func findGameMusicLoopPoints() {
        // Reset values
        var introEnd: TimeInterval = 0
        var loopEnd: TimeInterval = 0
        
        if sections.isEmpty {
            // No detected sections - use fallback
            if let audioBuffer = audioBuffer {
                let duration = Double(audioBuffer.frameLength) / sampleRate
                // Default to 1/3 strategy - common pattern in music
                introEnd = duration / 3
                loopEnd = duration
            }
        } else if sections.count == 1 {
            // Only one section - suggest dividing it
            let section = sections[0]
            introEnd = section.startTime + (section.endTime - section.startTime) / 3
            loopEnd = section.endTime
        } else {
            // Multiple sections
            // Assume first section is intro, set loop end to track end
            introEnd = sections[0].endTime
            loopEnd = sections.last!.endTime
        }
        
        print("Initial loop suggestion: \(TimeFormatter.formatPrecise(introEnd)) to \(TimeFormatter.formatPrecise(loopEnd))")
        
        // CRITICAL CHANGE: Do fade-out detection BEFORE setting the suggested values
        let adjustedLoopEnd = checkForFadeOut(loopEnd)
        
        // Now update the suggested values, after the fade-out check
        DispatchQueue.main.async {
            self.suggestedLoopStart = introEnd
            self.suggestedLoopEnd = adjustedLoopEnd
            self.progress = 1.0
            print("Final loop suggestion: \(TimeFormatter.formatPrecise(introEnd)) to \(TimeFormatter.formatPrecise(adjustedLoopEnd))")
        }
    }
    
    /**
     * Generates a visualization of the self-similarity matrix as an image.
     * This can be used to debug and fine-tune the analysis process.
     *
     * - Returns: CGImage containing the visualization, or nil if matrix isn't available
     */
    func generateSimilarityMatrixVisualization() -> CGImage? {
        guard let matrix = similarityMatrix, !matrix.isEmpty else { return nil }
        
        let size = matrix.count
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        // Draw matrix values as grayscale pixels
        for i in 0..<size {
            for j in 0..<size {
                let similarity = CGFloat(matrix[i][j])
                let color = CGColor(red: similarity, green: similarity, blue: similarity, alpha: 1.0)
                context.setFillColor(color)
                context.fill(CGRect(x: j, y: i, width: 1, height: 1))
            }
        }
        
        return context.makeImage()
    }
    
    /**
     * Detects fade-outs in the audio and adjusts loop points to exclude them.
     *
     * Game music often ends with fade-outs that should be excluded from loops.
     * This function analyzes the amplitude envelope to find the start of any fade-out
     * and ensures the loop end point is set before it begins.
     */
    private func detectAndAvoidFadeOut() {
        guard !features.isEmpty else {
            print("No features available for fade-out detection")
            return
        }
        
        // Only analyze if we have a suggested loop end near the track end
        if let audioBuffer = audioBuffer {
            let duration = Double(audioBuffer.frameLength) / sampleRate
            let endThreshold = duration * 0.9 // Only check if loop end is in last 10% of track
            
            print("FADE-OUT CHECK: Track duration: \(duration), loop end: \(suggestedLoopEnd), threshold: \(endThreshold)")
            
            if suggestedLoopEnd > endThreshold {
                print("Loop end is near track end, checking for fade-out...")
                
                // Get RMS values for the last 25% of the track - increased from 20%
                let analysisStart = Int(Double(features.count) * 0.75)
                var rmsValues: [Float] = []
                
                for i in analysisStart..<features.count {
                    rmsValues.append(features[i].rms)
                }
                
                // No data to analyze
                guard !rmsValues.isEmpty else {
                    print("No RMS values available in the analysis window")
                    return
                }
                
                print("Analyzing \(rmsValues.count) RMS values for fade-out detection")
                
                // Additional debug: print the RMS values for manual inspection
                for (i, rms) in rmsValues.enumerated() {
                    if i % 5 == 0 { // Print every 5th value to avoid log spam
                        print("RMS[\(i)]: \(rms)")
                    }
                }
                
                // Check if there's a consistent decrease in amplitude toward the end
                let isFadeOut = isFadeOutPattern(rmsValues)
                
                if isFadeOut {
                    // Find where the fade-out begins
                    let fadeOutIndex = findFadeOutStart(rmsValues)
                    if fadeOutIndex >= 0 {
                        // Convert to the actual feature index
                        let actualFeatureIndex = analysisStart + fadeOutIndex
                        // Get the time position
                        let fadeOutStartTime = features[actualFeatureIndex].timeOffset
                        
                        print("Fade-out detected! Moving loop end from \(TimeFormatter.formatPrecise(suggestedLoopEnd)) to \(TimeFormatter.formatPrecise(fadeOutStartTime))")
                        
                        // Adjust the loop end to be before the fade-out starts
                        DispatchQueue.main.async {
                            self.suggestedLoopEnd = fadeOutStartTime
                        }
                    } else {
                        print("Couldn't determine fade-out start position")
                    }
                } else {
                    print("No fade-out pattern detected at end of track")
                }
            } else {
                print("Loop end is not near track end, skipping fade-out check")
            }
        }
    }

    /**
     * Determines if an array of RMS values exhibits a fade-out pattern.
     *
     * - Parameter rmsValues: Array of RMS (amplitude) values
     * - Returns: True if a fade-out pattern is detected
     */
    private func isFadeOutPattern(_ rmsValues: [Float]) -> Bool {
        // Need enough data to analyze
        guard rmsValues.count > 5 else {
            print("Not enough RMS values for fade-out analysis")
            return false
        }
        
        // Compare average of first half to average of second half
        let halfPoint = rmsValues.count / 2
        let firstHalfAvg = rmsValues[0..<halfPoint].reduce(0, +) / Float(halfPoint)
        let secondHalfAvg = rmsValues[halfPoint..<rmsValues.count].reduce(0, +) / Float(rmsValues.count - halfPoint)
        
        // If second half is significantly softer than first half, it's likely a fade-out
        let ratio = secondHalfAvg / firstHalfAvg
        print("Fade-out analysis: first half avg = \(firstHalfAvg), second half avg = \(secondHalfAvg), ratio = \(ratio)")
        
        // Count how many decreasing steps we have
        var decreaseCount = 0
        for i in 1..<rmsValues.count {
            if rmsValues[i] < rmsValues[i-1] * 0.97 { // More sensitive - 3% drop instead of 5%
                decreaseCount += 1
            }
        }
        
        let decreaseRatio = Float(decreaseCount) / Float(rmsValues.count - 1)
        print("Decrease ratio: \(decreaseRatio) (\(decreaseCount) decreases in \(rmsValues.count-1) steps)")
        
        // Look for a trend of decreasing values at the very end (last 25%)
        let endQuarterStart = Int(Float(rmsValues.count) * 0.75)
        var endDecreaseTrend = true
        if rmsValues.count > 4 && endQuarterStart < rmsValues.count - 3 {
            for i in endQuarterStart..<(rmsValues.count-3) {
                // Check if values are generally decreasing in this window
                if rmsValues[i] <= rmsValues[i+2] { // Allow some minor fluctuations
                    endDecreaseTrend = false
                    break
                }
            }
        }
        
        // Modified thresholds for game music and added end trend check
        return ratio < 0.85 || decreaseRatio > 0.5 || endDecreaseTrend
    }
    
    /**
     * Finds the starting point of a fade-out in an array of RMS values.
     *
     * - Parameter rmsValues: Array of RMS (amplitude) values
     * - Returns: Index where the fade-out begins, or -1 if not found
     */
    private func findFadeOutStart(_ rmsValues: [Float]) -> Int {
        guard rmsValues.count > 5 else { return -1 }
        
        // First, smooth the RMS values to reduce noise
        var smoothedRMS = [Float](repeating: 0, count: rmsValues.count)
        let windowSize = 2 // Smaller window for more precise detection
        
        for i in 0..<rmsValues.count {
            var sum: Float = 0
            var count = 0
            
            for j in max(0, i - windowSize)...min(rmsValues.count - 1, i + windowSize) {
                sum += rmsValues[j]
                count += 1
            }
            
            smoothedRMS[i] = sum / Float(count)
        }
        
        // Calculate the global maximum amplitude
        guard let maxRMS = smoothedRMS.max() else { return -1 }
        
        // Look for consistent amplitude drop
        var maxDropIndex = -1
        var maxDropAmount: Float = 0
        
        // Find the point with the largest percentage drop
        for i in 1..<smoothedRMS.count {
            let drop = smoothedRMS[i-1] - smoothedRMS[i]
            let dropPercentage = drop / smoothedRMS[i-1]
            
            if dropPercentage > maxDropAmount && dropPercentage > 0.05 { // 5% drop threshold
                maxDropAmount = dropPercentage
                maxDropIndex = i-1 // Point before the drop
            }
        }
        
        if maxDropIndex > 0 {
            print("Found significant drop at index \(maxDropIndex) (drop: \(maxDropAmount * 100)%)")
            return maxDropIndex
        }
        
        // If no single big drop, look for the start of a consistent downward trend
        for i in 1..<smoothedRMS.count-3 {
            // Check if we have several decreasing values in a row
            if smoothedRMS[i] > smoothedRMS[i+1] &&
               smoothedRMS[i+1] > smoothedRMS[i+2] &&
               smoothedRMS[i+2] > smoothedRMS[i+3] {
                print("Found downward trend starting at index \(i)")
                return i
            }
        }
        
        // If no clear fade start found, use 80% mark (more conservative)
        let defaultIndex = Int(Float(rmsValues.count) * 0.8)
        print("No clear fade start found, using default at 80% mark (index \(defaultIndex))")
        return defaultIndex
    }
    
    /**
     * Checks for a fade-out at the end of the track and returns an adjusted loop end point.
     *
     * @param proposedEnd The initially proposed loop end time
     * @return An adjusted loop end time that avoids any fade-out
     */
    private func checkForFadeOut(_ proposedEnd: TimeInterval) -> TimeInterval {
        guard !features.isEmpty else {
            print("No features available for fade-out detection")
            return proposedEnd
        }
        
        // Only analyze if we have a proposed end near the track end
        if let audioBuffer = audioBuffer {
            let duration = Double(audioBuffer.frameLength) / sampleRate
            let endThreshold = duration * 0.85 // Check if end is in last 15% of track
            
            print("FADE-OUT CHECK: Track duration: \(duration), proposed end: \(proposedEnd), threshold: \(endThreshold)")
            
            if proposedEnd > endThreshold {
                print("Loop end is near track end, checking for fade-out...")
                
                // Get RMS values for the last 30% of the track - increase for short tracks
                let analysisStart = Int(Double(features.count) * 0.7)
                var rmsValues: [Float] = []
                
                for i in analysisStart..<features.count {
                    rmsValues.append(features[i].rms)
                }
                
                // No data to analyze
                guard !rmsValues.isEmpty else {
                    print("No RMS values available in the analysis window")
                    return proposedEnd
                }
                
                print("Analyzing \(rmsValues.count) RMS values for fade-out detection")
                
                // Check for a very simple fade-out pattern - just look for decreasing volume at end
                var lastQuarterAvg: Float = 0
                var finalFewAvg: Float = 0
                
                let lastQuarterStart = Int(Double(rmsValues.count) * 0.75)
                if lastQuarterStart < rmsValues.count {
                    lastQuarterAvg = rmsValues[0..<lastQuarterStart].reduce(0, +) / Float(lastQuarterStart)
                    finalFewAvg = rmsValues[lastQuarterStart..<rmsValues.count].reduce(0, +) / Float(rmsValues.count - lastQuarterStart)
                    
                    print("Last quarter average: \(lastQuarterAvg), Final few average: \(finalFewAvg)")
                    
                    // If final part is more than 10% quieter than the rest, it's likely a fade-out
                    if finalFewAvg < lastQuarterAvg * 0.9 {
                        // This is a fade-out! Find a good cutoff point
                        
                        // Simple approach: go back from the end until we find a point that's not too quiet
                        for i in (0..<rmsValues.count).reversed() {
                            if rmsValues[i] > finalFewAvg * 1.5 {
                                let actualFeatureIndex = analysisStart + i
                                if actualFeatureIndex < features.count {
                                    let fadeOutStartTime = features[actualFeatureIndex].timeOffset
                                    print("Fade-out detected! Moving loop end from \(TimeFormatter.formatPrecise(proposedEnd)) to \(TimeFormatter.formatPrecise(fadeOutStartTime))")
                                    return fadeOutStartTime
                                }
                            }
                        }
                        
                        // If we couldn't find a clear point, just use 80% of the track
                        let safeEnd = duration * 0.8
                        print("Fade-out detected but no clear start found. Using 80% point: \(TimeFormatter.formatPrecise(safeEnd))")
                        return safeEnd
                    }
                }
                
                print("No clear fade-out pattern detected")
            } else {
                print("Loop end is not near track end, skipping fade-out check")
            }
        }
        
        return proposedEnd
    }
}
