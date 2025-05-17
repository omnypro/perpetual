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
    private let windowSize: Int = 16384 // Relatively large window for macro analysis
    private let hopSize: Int = 8192     // 50% overlap for windows
    private let minSectionDuration: Double = 3.0 // Minimum section length in seconds
    
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
                // Calculate Euclidean distance between feature vectors
                let rmsDiff = features[i].rms - features[j].rms
                let centroidDiff = features[i].spectralCentroid - features[j].spectralCentroid
                let fluxDiff = features[i].spectralFlux - features[j].spectralFlux
                let zcrDiff = features[i].zeroCrossingRate - features[j].zeroCrossingRate
                
                // Normalized Euclidean distance (weighted to emphasize certain features)
                let distance = sqrt(
                    pow(rmsDiff * 2.0, 2) +        // Emphasize amplitude changes
                    pow(centroidDiff * 0.5, 2) +   // De-emphasize timbre changes
                    pow(fluxDiff, 2) +             // Normal weight for spectral changes
                    pow(zcrDiff * 0.3, 2)          // De-emphasize noise vs. tone
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
        guard let matrix = similarityMatrix, !features.isEmpty else { return }
        
        // Calculate novelty curve (diagonal cross-similarity)
        var novelty = [Float](repeating: 0, count: features.count)
        
        // Use a smaller kernel size for smaller datasets
        let maxKernelSize = 15
        let kernelSize = min(maxKernelSize, (features.count / 10)) // Adjust kernel based on data size
        
        // Make sure kernel size is at least 2 for meaningful analysis
        let safeKernelSize = max(2, kernelSize)
        
        // Skip if we don't have enough data
        guard features.count > (safeKernelSize * 2) else {
            return
        }
        
        // Process only indices where we can safely apply the kernel
        for i in safeKernelSize..<features.count-safeKernelSize {
            // Report progress
            if i % 20 == 0 {
                let progress = Double(i) / Double(features.count)
                DispatchQueue.main.async {
                    self.progress = 0.75 + progress * 0.15 // Third quarter of analysis
                }
            }
            
            var sum: Float = 0
            for k in 1...safeKernelSize {
                // Ensure all indices are within valid range
                if (i-k >= 0 && i+k < matrix.count && i-k < matrix[i].count && i+k < matrix[i].count) {
                    // Calculate checkerboard kernel at this position
                    let before = Float(matrix[i-k][i-k])
                    let after = Float(matrix[i+k][i+k])
                    let crossBefore = Float(matrix[i][i-k])
                    let crossAfter = Float(matrix[i][i+k])
                    
                    // Checkerboard pattern: high on diagonal, low on cross-points
                    sum += (before + after) - (crossBefore + crossAfter)
                }
            }
            novelty[i] = sum / Float(safeKernelSize * 2)
        }
        
        // Find peaks in novelty curve (section boundaries)
        let minDistance = Int(minSectionDuration * sampleRate / Double(hopSize))
        var peaks = findPeaks(in: novelty, minDistance: minDistance, threshold: 0.15)
        
        // Convert peak indices to time positions
        var boundaries = peaks.map { features[$0].timeOffset }
        
        // Always include start and end points
        boundaries.insert(0, at: 0)
        if let audioBuffer = audioBuffer {
            let duration = Double(audioBuffer.frameLength) / sampleRate
            boundaries.append(duration)
        }
        
        // Create sections from boundaries
        var detectedSections: [AudioSection] = []
        for i in 0..<boundaries.count-1 {
            let startTime = boundaries[i]
            let endTime = boundaries[i+1]
            
            // Determine section type (temporary)
            let type: AudioSection.SectionType = i == 0 ? .intro : .loop
            let confidence: Float = i < peaks.count ? novelty[peaks[i]] : 0.5
            
            detectedSections.append(AudioSection(
                startTime: startTime,
                endTime: endTime,
                type: type,
                confidence: confidence
            ))
        }
        
        DispatchQueue.main.async {
            self.sections = detectedSections
        }
    }

    private func findPeaks(in signal: [Float], minDistance: Int, threshold: Float) -> [Int] {
        var peaks: [Int] = []
        
        // Find all peaks
        for i in 1..<signal.count-1 {
            if signal[i] > signal[i-1] && signal[i] > signal[i+1] && signal[i] > threshold {
                peaks.append(i)
            }
        }
        
        // Filter peaks by minimum distance
        var filteredPeaks: [Int] = []
        
        if !peaks.isEmpty {
            filteredPeaks.append(peaks[0])
            
            for peak in peaks[1...] {
                if let lastPeak = filteredPeaks.last, peak - lastPeak >= minDistance {
                    filteredPeaks.append(peak)
                } else if let lastPeak = filteredPeaks.last, signal[peak] > signal[lastPeak] {
                    // Replace existing peak if new one is stronger
                    filteredPeaks[filteredPeaks.count - 1] = peak
                }
            }
        }
        
        return filteredPeaks
    }

    private func findGameMusicLoopPoints() {
        guard sections.count >= 2 else {
            // Not enough sections to determine loop points
            if let audioBuffer = audioBuffer {
                let duration = Double(audioBuffer.frameLength) / sampleRate
                DispatchQueue.main.async {
                    self.suggestedLoopStart = 0
                    self.suggestedLoopEnd = duration
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            self.progress = 0.9 // Final stage
        }
        
        // Game music heuristics:
        // 1. First section is usually an intro
        // 2. Main loop usually starts after the intro
        // 3. Many game tracks loop from 2nd section to end
        // 4. Look for high self-similarity between end and loop start
        
        // Start with a simple approach: assume first section is intro, rest is loop
        var introEnd = sections[0].endTime
        var loopEnd = sections.last!.endTime
        
        // Find the best loop point (highest similarity between loop end and potential loop start)
        if let matrix = similarityMatrix, features.count > 30 { // Ensure we have enough data
            var bestCorrelation: Float = -1
            var bestLoopStartIndex = 0
            
            // Find the feature index closest to the intro end
            let introEndIndex = features.firstIndex { $0.timeOffset >= introEnd } ?? 0
            
            // Find the feature index closest to the end
            let endIndex = features.count - 1
            
            // Ensure we have enough features for meaningful analysis
            let safeWindowSize = min(10, features.count / 4)
            
            // Only analyze if we have enough data at the end
            if endIndex >= (safeWindowSize * 2) && introEndIndex < endIndex - safeWindowSize {
                // Calculate max potential loop start index to avoid buffer overflows
                let maxStartIndex = endIndex - (safeWindowSize * 2)
                let safeIntroEndIndex = min(introEndIndex, maxStartIndex)
                
                // Check correlation between potential loop starts and the end
                for startIndex in safeIntroEndIndex..<maxStartIndex {
                    let timePosition = features[startIndex].timeOffset
                    
                    // Don't consider positions too close to the end
                    if loopEnd - timePosition < 5.0 {
                        continue
                    }
                    
                    // Calculate average similarity in a window
                    var sum: Float = 0
                    var validPoints = 0
                    
                    for offset in 0..<safeWindowSize {
                        if startIndex + offset < matrix.count && 
                           endIndex - safeWindowSize + offset < matrix[startIndex + offset].count {
                            sum += matrix[startIndex + offset][endIndex - safeWindowSize + offset]
                            validPoints += 1
                        }
                    }
                    
                    if validPoints > 0 {
                        let correlation = sum / Float(validPoints)
                        
                        if correlation > bestCorrelation {
                            bestCorrelation = correlation
                            bestLoopStartIndex = startIndex
                        }
                    }
                }
            }
            
            // Optimize loop start based on feature boundaries if correlation is good enough
            if bestCorrelation > 0.7 {
                let candidateLoopStart = features[bestLoopStartIndex].timeOffset
                
                // Find the nearest section boundary
                for section in sections {
                    if abs(section.startTime - candidateLoopStart) < 1.0 {
                        introEnd = section.startTime
                        break
                    }
                }
            }
        }
        
        // Update suggested loop points
        DispatchQueue.main.async {
            self.suggestedLoopStart = introEnd
            self.suggestedLoopEnd = loopEnd
            self.progress = 1.0
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
}
