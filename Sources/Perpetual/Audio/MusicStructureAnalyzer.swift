import AVFoundation
import Accelerate
import Foundation
import Combine

/**
 * MusicStructureAnalyzer
 *
 * A class responsible for analyzing audio structure at a macro level to identify
 * loop points suitable for game music. Uses feature extraction, self-similarity
 * analysis, and transition quality assessment to detect optimal loop points.
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
    
    // New published properties for transition quality assessment
    @Published var loopCandidates: [LoopCandidate] = []
    @Published var transitionQuality: Float = 0
    
    // Audio features
    private var audioBuffer: AVAudioPCMBuffer? = nil
    private var audioFormat: AVAudioFormat? = nil
    private var sampleRate: Double = 44100
    private var features: [AudioFeatures] = []
    private var similarityMatrix: [[Float]]? = nil
    
    // Analysis parameters
    private let windowSize: Int = 8192  // For feature extraction
    private let hopSize: Int = 4096     // 50% overlap
    private let minSectionDuration: Double = 2.0 // Minimum section length in seconds
    private let transitionAnalysisWindowSize: Int = 4096 // For loop transition analysis
    
    // New struct to represent and rank loop candidates
    struct LoopCandidate: Identifiable {
        var id = UUID()
        var startTime: TimeInterval
        var endTime: TimeInterval
        var quality: Float
        var metrics: TransitionMetrics
        
        struct TransitionMetrics {
            var volumeChange: Float
            var phaseJump: Float
            var spectralDifference: Float
            var harmonicContinuity: Float
            var envelopeContinuity: Float
            var zeroStart: Bool
            var zeroEnd: Bool
        }
    }
    
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
            self.loopCandidates = []
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
                self.progress = 0.1 // 10% progress after loading file
            }
            
            // Extract features in chunks
            try await extractAudioFeatures(from: buffer)
            DispatchQueue.main.async { self.progress = 0.3 }
            
            // Build self-similarity matrix
            buildSimilarityMatrix()
            DispatchQueue.main.async { self.progress = 0.4 }
            
            // Detect sections
            detectSections()
            DispatchQueue.main.async { self.progress = 0.5 }
            
            // Find transition-based loop candidates
            await findOptimalLoopCandidates()
            DispatchQueue.main.async { self.progress = 0.8 }
            
            // Apply game music heuristics and select best candidate
            selectBestLoopCandidate()
            
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
                self.progress = 0.1 + progress * 0.2 // 10-30% of the analysis process
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
    
    private func buildSimilarityMatrix() -> [[Float]] {
        let featureCount = features.count
        var matrix = [[Float]](repeating: [Float](repeating: 0, count: featureCount), count: featureCount)
        
        // 1. Calculate basic similarity matrix with weighted features
        for i in 0..<featureCount {
            // Report progress
            if i % 10 == 0 {
                let progress = Double(i) / Double(featureCount)
                DispatchQueue.main.async {
                    self.progress = 0.3 + progress * 0.1
                }
            }
            
            for j in 0..<featureCount {
                // Extract features for comparison
                let rmsDiff = features[i].rms - features[j].rms
                let centroidDiff = features[i].spectralCentroid - features[j].spectralCentroid
                let fluxDiff = features[i].spectralFlux - features[j].spectralFlux
                let zcrDiff = features[i].zeroCrossingRate - features[j].zeroCrossingRate
                
                // Enhanced normalized Euclidean distance with optimized weights for game music
                // Specifically tuned to emphasize tonal and rhythmic patterns common in OSTs
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
        
        // 2. Enhance patterns in the similarity matrix to emphasize musical structure
        var enhancedMatrix = matrix
        
        // Apply a Gaussian-like filter along the diagonals to enhance pattern visibility
        // This helps identify repeating sections clearer
        let filterSize = 3
        
        // Check if we have enough features to process
        guard (2 * filterSize) < featureCount else {
            print("Not enough features to apply similarity matrix enhancement")
            return matrix
        }
        
        for i in filterSize..<(featureCount - filterSize) {
            for j in filterSize..<(featureCount - filterSize) {
                if matrix[i][j] > 0.7 {  // Only enhance already similar regions
                    // Calculate average of diagonal neighborhood
                    var sum: Float = 0
                    var count: Float = 0
                    
                    for k in -filterSize...filterSize {
                        if (i+k) >= 0 && (i+k) < featureCount &&
                           (j+k) >= 0 && (j+k) < featureCount {
                            let weight = 1.0 - abs(Float(k)) / Float(filterSize + 1)  // Higher weight for closer points
                            sum += matrix[i+k][j+k] * weight
                            count += weight
                        }
                    }
                    
                    if count > 0 {
                        // Enhance the similarity if the neighborhood is also similar
                        let avgSimilarity = sum / count
                        if avgSimilarity > 0.6 {
                            enhancedMatrix[i][j] = min(1.0, matrix[i][j] * 1.2)
                        }
                    }
                }
            }
        }
        
        // 3. Look for repeating patterns typical in game music
        // Game music often has clear AABA, ABAC, or similar patterns
        var patternCandidates: [(startA: Int, endA: Int, startB: Int, endB: Int, similarity: Float)] = []
        
        // Minimum section length to consider (in feature frames)
        let minSectionFrames = Int(minSectionDuration * sampleRate / Double(hopSize))
        // Maximum section length (typically <= 32 bars in game music)
        let maxSectionFrames = min(featureCount / 2, Int(30.0 * sampleRate / Double(hopSize)))
        
        // Search for high-similarity regions along diagonals offset from the main diagonal
        // These indicate repeating sections
        for sectionLength in stride(from: minSectionFrames, through: maxSectionFrames, by: max(1, minSectionFrames / 2)) {
            // Check various offsets - these represent the time between repeating sections
            for offset in stride(from: sectionLength, to: featureCount - sectionLength, by: max(1, minSectionFrames / 4)) {
                // Calculate average similarity along this diagonal segment
                for startA in 0..<(featureCount - offset - sectionLength) {
                    let endA = startA + sectionLength
                    let startB = startA + offset
                    let endB = startB + sectionLength
                    
                    // Skip if regions overlap
                    if endA > startB {
                        continue
                    }
                    
                    // Calculate average similarity between these two segments
                    var totalSimilarity: Float = 0
                    for i in 0..<sectionLength {
                        totalSimilarity += enhancedMatrix[startA + i][startB + i]
                    }
                    
                    let avgSimilarity = totalSimilarity / Float(sectionLength)
                    
                    // If we found a highly similar region, it's likely a repeating section
                    if avgSimilarity > 0.75 {
                        patternCandidates.append((startA, endA, startB, endB, avgSimilarity))
                    }
                }
            }
        }
        
        // 4. Analyze the pattern candidates to identify the most musical repetition structure
        if !patternCandidates.isEmpty {
            // Sort by similarity score
            patternCandidates.sort { $0.similarity > $1.similarity }
            
            print("Found \(patternCandidates.count) potential repeating patterns")
            
            // Add the top patterns as potential loop candidates
            for (idx, pattern) in patternCandidates.prefix(5).enumerated() {
                let startTimeA = features[pattern.startA].timeOffset
                let endTimeA = features[pattern.endA].timeOffset
                let startTimeB = features[pattern.startB].timeOffset
                let endTimeB = features[pattern.endB].timeOffset
                let duration = endTimeA - startTimeA
                
                print("Pattern \(idx+1): A[\(TimeFormatter.formatPrecise(startTimeA))-\(TimeFormatter.formatPrecise(endTimeA))] repeats at B[\(TimeFormatter.formatPrecise(startTimeB))-\(TimeFormatter.formatPrecise(endTimeB))], similarity: \(pattern.similarity), duration: \(TimeFormatter.formatPrecise(duration))")
                
                // Create potential loop candidates from these patterns
                // 1. A→A loop (loop the first occurrence)
                addCandidateIfValid(startTimeA, endTimeA)
                
                // 2. B→B loop (loop the second occurrence)
                addCandidateIfValid(startTimeB, endTimeB)
                
                // 3. B→A loop (loop from second back to first - common in game music)
                addCandidateIfValid(startTimeA, endTimeB)
            }
        }
        
        DispatchQueue.main.async {
            self.similarityMatrix = enhancedMatrix
        }
        
        return enhancedMatrix
    }

    /**
     * Helper method to add a candidate loop point if it's valid
     */
    private func addCandidateIfValid(_ startTime: TimeInterval, _ endTime: TimeInterval) {
        guard endTime > startTime else { return }
        
        // Check if this is a plausible loop duration
        let duration = endTime - startTime
        let totalDuration = Double(audioBuffer?.frameLength ?? 0) / sampleRate
        
        // Avoid loops that are too short or too long relative to the track
        if duration >= minSectionDuration && duration <= totalDuration * 0.8 {
            // Check for existing similar candidates
            let duplicate = loopCandidates.contains { candidate in
                abs(candidate.startTime - startTime) < 0.1 &&
                abs(candidate.endTime - endTime) < 0.1
            }
            
            if !duplicate {
                // Evaluate transition quality
                let metrics = evaluateTransitionQuality(loopStart: startTime, loopEnd: endTime)
                let quality = calculateOverallQuality(metrics: metrics)
                
                // Add as a candidate
                loopCandidates.append(LoopCandidate(
                    startTime: startTime,
                    endTime: endTime,
                    quality: quality,
                    metrics: metrics
                ))
                
                print("Added pattern-based candidate: \(TimeFormatter.formatPrecise(startTime)) to \(TimeFormatter.formatPrecise(endTime)) with quality: \(quality)")
            }
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
    
    /**
     * Improved structural analysis that finds potential loop points
     * based on repetition patterns in music, without any genre-specific assumptions.
     */
    private func findOptimalLoopCandidates() async {
        guard let buffer = audioBuffer,
              let channelData = buffer.floatChannelData else { return }
        
        let totalFrames = Int(buffer.frameLength)
        let samples = channelData[0]
        
        print("Finding optimal loop candidates...")
        
        // 1. Start with natural boundaries in the music
        // Collect all potential start and end points
        var candidateStarts: [TimeInterval] = []
        var candidateEnds: [TimeInterval] = []
        
        // Add section boundaries as candidates
        for section in sections {
            if section.startTime > 1.0 { // Avoid very beginning of track
                candidateStarts.append(section.startTime)
            }
            if section.endTime < Double(totalFrames) / sampleRate - 1.0 { // Avoid very end
                candidateEnds.append(section.endTime)
            }
        }
        
        // Add musical phrase boundaries
        let phrasePoints = findMusicalPhrasePoints()
        for point in phrasePoints {
            // Phrases that occur early in the track are good loop start points
            if point > 2.0 && point < Double(totalFrames) / sampleRate * 0.4 {
                candidateStarts.append(point)
            }
            
            // Phrases that occur later in the track are good loop end points
            if point > Double(totalFrames) / sampleRate * 0.6 {
                candidateEnds.append(point)
            }
            
            // Add all phrase points as potential candidates
            candidateStarts.append(point)
            candidateEnds.append(point)
        }
        
        // 2. Add zero crossings near section boundaries for more precise points
        for sectionTime in candidateStarts.sorted() {
            let nearbyZeroCrossings = findZeroCrossingsNear(time: sectionTime,
                                                           samples: samples,
                                                           window: 0.05) // 50ms window
            candidateStarts.append(contentsOf: nearbyZeroCrossings)
        }
        
        for sectionTime in candidateEnds.sorted() {
            let nearbyZeroCrossings = findZeroCrossingsNear(time: sectionTime,
                                                           samples: samples,
                                                           window: 0.05)
            candidateEnds.append(contentsOf: nearbyZeroCrossings)
        }
        
        // 3. Add structurally significant points based on repetition analysis
        await addRepetitionBasedCandidates(to: &candidateStarts, and: &candidateEnds)
        
        // 4. Consider intro detection - look for markers between intro and main content
        await addIntroAwareLoopPoints(to: &candidateStarts, and: &candidateEnds)
        
        // Remove duplicates and sort
        candidateStarts = Array(Set(candidateStarts)).sorted()
        candidateEnds = Array(Set(candidateEnds)).sorted()
        
        print("Found \(candidateStarts.count) candidate start points and \(candidateEnds.count) candidate end points")
        
        // 5. Evaluate all viable start/end combinations
        var loopCandidates: [LoopCandidate] = []
        let totalCombinations = candidateStarts.count * candidateEnds.count
        var progress = 0
        
        // Limit the number of combinations to evaluate to prevent freezing on large files
        let maxCombinations = 2000
        let stride = max(1, totalCombinations / maxCombinations)
        
        for (startIndex, startTime) in candidateStarts.enumerated() {
            for (endIndex, endTime) in candidateEnds.enumerated() {
                // Skip some combinations for performance if we have too many
                if totalCombinations > maxCombinations && (startIndex * candidateEnds.count + endIndex) % stride != 0 {
                    continue
                }
                
                // Report progress
                progress += 1
                if progress % 20 == 0 {
                    DispatchQueue.main.async {
                        self.progress = 0.5 + (0.3 * Double(progress) / Double(min(totalCombinations, maxCombinations)))
                    }
                }
                
                // Evaluate only valid loop regions
                if endTime > startTime &&
                   endTime - startTime >= minSectionDuration &&
                   endTime - startTime <= Double(totalFrames) / sampleRate * 0.8 {
                    
                    // Evaluate transition quality with our improved metrics
                    let metrics = evaluateTransitionQuality(loopStart: startTime, loopEnd: endTime)
                    let quality = calculateOverallQuality(metrics: metrics)
                    
                    // Add to candidates if quality is reasonable
                    if quality > 3.0 { // Only keep candidates with at least mediocre quality
                        loopCandidates.append(LoopCandidate(
                            startTime: startTime,
                            endTime: endTime,
                            quality: quality,
                            metrics: metrics
                        ))
                    }
                    
                    // Take a breath to avoid blocking the main thread
                    if progress % 50 == 0 {
                        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms pause
                    }
                }
            }
        }
        
        // 6. Post-process: boost candidates that have musical significance
        loopCandidates = boostMusicallySignificantCandidates(loopCandidates)
        
        // Sort candidates by quality
        loopCandidates.sort { $0.quality > $1.quality }
        
        // Keep only the top candidates
        let topCount = min(15, loopCandidates.count)
        if topCount > 0 {
            loopCandidates = Array(loopCandidates.prefix(topCount))
        }
        
        DispatchQueue.main.async {
            self.loopCandidates = loopCandidates
            print("Found \(loopCandidates.count) quality loop candidates")
            if let best = loopCandidates.first {
                print("Best candidate: \(TimeFormatter.formatPrecise(best.startTime)) to \(TimeFormatter.formatPrecise(best.endTime)) with quality \(best.quality)/10")
            }
        }
    }

    /**
     * Finds repetition patterns in the music and adds them as candidate loop points.
     * No genre-specific assumptions are made - just looking for repeating patterns.
     */
    private func addRepetitionBasedCandidates(to startPoints: inout [TimeInterval], and endPoints: inout [TimeInterval]) async {
        guard !features.isEmpty else { return }
        
        // 1. Use the self-similarity matrix to identify repeating sections
        if similarityMatrix == nil {
            buildSimilarityMatrix()
        }
        
        guard let matrix = similarityMatrix, !matrix.isEmpty else { return }
        
        // Look for high-similarity regions off the main diagonal
        // These indicate potential repeating sections
        let featureCount = matrix.count
        
        // Minimum section length (in frames)
        let minSectionFrames = Int(2.0 * sampleRate / Double(hopSize))
        
        // Define potential section lengths to check
        // These span from short phrases to substantial sections
        let sectionLengthsToCheck = [
            minSectionFrames,              // ~2 seconds
            minSectionFrames * 2,          // ~4 seconds
            minSectionFrames * 4,          // ~8 seconds
            minSectionFrames * 8,          // ~16 seconds
            minSectionFrames * 16          // ~32 seconds
        ].filter { $0 < featureCount / 2 } // Ensure lengths aren't too long for the track
        
        var repetitionPoints: [TimeInterval] = []
        
        // 2. For each section length, look for repeating patterns
        for sectionLength in sectionLengthsToCheck {
            // Skip rest if too short
            if sectionLength < minSectionFrames {
                continue
            }
            
            // Take a breath periodically to avoid blocking the main thread
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms pause
            
            // Check for repetition patterns by scanning the similarity matrix
            // (looking for off-diagonal regions of high similarity)
            for startA in stride(from: 0, to: featureCount - sectionLength * 2, by: max(1, sectionLength / 4)) {
                let endA = startA + sectionLength
                
                // Start searching after the first instance
                for startB in stride(from: endA + minSectionFrames/2, to: featureCount - sectionLength, by: max(1, sectionLength / 4)) {
                    let endB = startB + sectionLength
                    
                    // Calculate average similarity between these regions
                    var totalSimilarity: Float = 0
                    for offset in 0..<sectionLength {
                        if startA + offset < matrix.count && startB + offset < matrix.count {
                            totalSimilarity += matrix[startA + offset][startB + offset]
                        }
                    }
                    
                    let avgSimilarity = totalSimilarity / Float(sectionLength)
                    
                    // If we found a highly similar region, it's a repeating section
                    if avgSimilarity > 0.7 {
                        let timeA = features[startA].timeOffset
                        let timeEndA = features[endA].timeOffset
                        let timeB = features[startB].timeOffset
                        let timeEndB = features[endB].timeOffset
                        
                        print("Found repetition: \(TimeFormatter.formatPrecise(timeA))-\(TimeFormatter.formatPrecise(timeEndA)) repeats at \(TimeFormatter.formatPrecise(timeB))-\(TimeFormatter.formatPrecise(timeEndB)), similarity: \(avgSimilarity)")
                        
                        // Add all these points as potential candidates
                        repetitionPoints.append(timeA)
                        repetitionPoints.append(timeEndA)
                        repetitionPoints.append(timeB)
                        repetitionPoints.append(timeEndB)
                        
                        // Add special candidates that loop from repetition back to original
                        startPoints.append(timeA)
                        endPoints.append(timeEndB)
                        
                        // Also consider looping just the repeated section
                        startPoints.append(timeB)
                        endPoints.append(timeEndB)
                    }
                }
            }
        }
        
        // Add repetition points to both candidate lists
        startPoints.append(contentsOf: repetitionPoints)
        endPoints.append(contentsOf: repetitionPoints)
    }

    /**
     * Detects potential intro sections and adds appropriate loop points.
     * This is structure-aware but not genre-specific.
     */
    private func addIntroAwareLoopPoints(to startPoints: inout [TimeInterval], and endPoints: inout [TimeInterval]) async {
        guard let buffer = audioBuffer else { return }
        
        let trackDuration = Double(buffer.frameLength) / sampleRate
        
        // Early exit for very short tracks
        if trackDuration < 10.0 {
            return
        }
        
        // 1. Look for change in energy level that might indicate end of intro
        // Analyze first 30% of track for energy changes
        let firstThirdFeatures = features.prefix(Int(Double(features.count) * 0.3))
        var energyProfile = firstThirdFeatures.map { $0.rms }
        
        // Smooth the energy profile
        let windowSize = 8
        var smoothedEnergy = [Float](repeating: 0, count: energyProfile.count)
        
        for i in windowSize..<(energyProfile.count - windowSize) {
            var sum: Float = 0
            for j in -windowSize...windowSize {
                if i+j >= 0 && i+j < energyProfile.count {
                    sum += energyProfile[i+j]
                }
            }
            smoothedEnergy[i] = sum / Float(windowSize * 2 + 1)
        }
        
        // Take a breath
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms pause
        
        // 2. Find significant energy transitions
        var potentialIntroBoundaries: [TimeInterval] = []
        
        for i in windowSize..<(smoothedEnergy.count - windowSize) {
            let currentEnergy = smoothedEnergy[i]
            let prevEnergy = smoothedEnergy[i-windowSize]
            
            // Look for significant increases in energy (common at end of intro)
            let relativeIncrease = (currentEnergy - prevEnergy) / max(0.001, prevEnergy)
            
            if relativeIncrease > 0.5 && // 50% increase in energy
               i > windowSize * 3 && // Not too early in track
               i < smoothedEnergy.count - windowSize * 3 { // Not too late
                
                let timePoint = firstThirdFeatures.dropFirst(i).first?.timeOffset ?? 0
                
                // Only add if it's a reasonable intro length (between 4-45 seconds)
                if timePoint > 4.0 && timePoint < min(45.0, trackDuration * 0.3) {
                    potentialIntroBoundaries.append(timePoint)
                    print("Potential intro end at \(TimeFormatter.formatPrecise(timePoint)) with energy increase of \(relativeIncrease * 100)%")
                }
            }
        }
        
        // 3. Add potential intro boundaries to start points
        if !potentialIntroBoundaries.isEmpty {
            for introEnd in potentialIntroBoundaries {
                // Add the intro boundary as a start point
                startPoints.append(introEnd)
                
                // Also add potential loop from end back to intro boundary
                if trackDuration - introEnd > minSectionDuration * 2 {
                    let potentialEndPoint = trackDuration - 1.0
                    endPoints.append(potentialEndPoint)
                    
                    print("Added potential intro-aware loop: \(TimeFormatter.formatPrecise(introEnd)) to \(TimeFormatter.formatPrecise(potentialEndPoint))")
                }
            }
        } else {
            // No clear intro detected, try some common intro lengths
            let commonIntroLengths = [8.0, 16.0, 24.0, 32.0]
            
            for length in commonIntroLengths {
                if length < trackDuration * 0.3 {
                    startPoints.append(length)
                    
                    if trackDuration - length > minSectionDuration * 2 {
                        endPoints.append(trackDuration - 1.0)
                    }
                }
            }
        }
    }

    /**
     * Boost the scores of candidates that are likely to be musically significant
     * based on universal musical principles.
     */
    private func boostMusicallySignificantCandidates(_ candidates: [LoopCandidate]) -> [LoopCandidate] {
        guard let buffer = audioBuffer, !candidates.isEmpty else { return candidates }
        
        let trackDuration = Double(buffer.frameLength) / sampleRate
        let adjustmentThreshold = 1.5 // How much we can adjust scores
        
        return candidates.map { candidate in
            var newCandidate = candidate
            var scoreAdjustment: Float = 0
            
            // 1. Favor loops where start point is at a phrase boundary
            let phrasePoints = findMusicalPhrasePoints()
            
            // Check if start point is at/near a phrase boundary
            let isStartAtPhrase = phrasePoints.contains { abs($0 - candidate.startTime) < 0.1 }
            if isStartAtPhrase {
                scoreAdjustment += 0.5
            }
            
            // 2. Prefer loops that aren't too short or too long
            let loopDuration = candidate.endTime - candidate.startTime
            let durationRatio = loopDuration / trackDuration
            
            // Ideal: between 25-75% of track length
            if durationRatio >= 0.25 && durationRatio <= 0.75 {
                scoreAdjustment += 0.3
            } else if durationRatio < 0.1 || durationRatio > 0.9 {
                // Penalize extremely short or long loops
                scoreAdjustment -= 0.4
            }
            
            // 3. Boost candidates with very good harmonic or envelope continuity
            // These are the most perceptually important factors
            if candidate.metrics.harmonicContinuity > 0.7 {
                scoreAdjustment += 0.5
            }
            
            if candidate.metrics.envelopeContinuity > 0.7 {
                scoreAdjustment += 0.4
            }
            
            // 4. Significantly boost candidates with zero crossings
            if candidate.metrics.zeroStart && candidate.metrics.zeroEnd {
                scoreAdjustment += 0.7
            }
            
            // 5. Harshly penalize large volume changes - these are very noticeable
            if candidate.metrics.volumeChange > 50 {
                scoreAdjustment -= 0.8
            }
            
            // Apply adjustment, ensuring we stay within 0-10 range
            newCandidate.quality = max(0, min(10, candidate.quality + scoreAdjustment))
            
            return newCandidate
        }
    }
    
    /**
     * Find zero crossings near a specific time point
     */
    private func findZeroCrossingsNear(time: TimeInterval, samples: UnsafePointer<Float>, window: TimeInterval) -> [TimeInterval] {
        guard let buffer = audioBuffer else { return [] }
        
        let framePos = Int(time * sampleRate)
        let windowFrames = Int(window * sampleRate)
        let startFrame = max(0, framePos - windowFrames/2)
        let endFrame = min(Int(buffer.frameLength), framePos + windowFrames/2)
        var zeroCrossings: [TimeInterval] = []
        
        // Check for zero crossings
        for i in startFrame..<endFrame-1 {
            if (samples[i] >= 0 && samples[i+1] < 0) ||
               (samples[i] < 0 && samples[i+1] >= 0) {
                // Linear interpolation to find precise zero crossing
                let t = -samples[i] / (samples[i+1] - samples[i])
                let frameExact = Double(i) + Double(t)
                let timeExact = frameExact / sampleRate
                zeroCrossings.append(timeExact)
            }
        }
        
        return zeroCrossings
    }
    
    /**
     * Identify phrase boundaries based on spectral flux and RMS changes
     */
    private func findPhraseBoundaries() -> [TimeInterval] {
        guard !features.isEmpty else { return [] }
        
        var boundaries: [TimeInterval] = []
        let windowSize = 4 // Look 4 frames before and after
        
        // Look for significant changes in spectral flux (musical events)
        if features.count > (windowSize * 2 + 1) {
            for i in windowSize..<(features.count - windowSize) {
                // Calculate average features before and after
                var fluxBefore: Float = 0
                var rmsBefore: Float = 0
                var fluxAfter: Float = 0
                var rmsAfter: Float = 0
                
                for j in 1...windowSize {
                    fluxBefore += features[i-j].spectralFlux
                    rmsBefore += features[i-j].rms
                    fluxAfter += features[i+j].spectralFlux
                    rmsAfter += features[i+j].rms
                }
                
                fluxBefore /= Float(windowSize)
                rmsBefore /= Float(windowSize)
                fluxAfter /= Float(windowSize)
                rmsAfter /= Float(windowSize)
                
                // Calculate relative differences
                let fluxDiff = abs(fluxAfter - fluxBefore) / max(0.001, (fluxAfter + fluxBefore) / 2)
                let rmsDiff = abs(rmsAfter - rmsBefore) / max(0.001, (rmsAfter + rmsBefore) / 2)
                
                // If there's a change in either flux or RMS, mark it as a phrase boundary
                // Using a lower threshold to find more candidates
                if fluxDiff > 0.3 || rmsDiff > 0.3 {
                    boundaries.append(features[i].timeOffset)
                }
            }
        }
        
        return boundaries
    }
    
    /**
     * Improved loop transition analysis that focuses on musical coherence
     * rather than just acoustic similarity. This works for any musical style.
     */
    private func evaluateTransitionQuality(loopStart: TimeInterval, loopEnd: TimeInterval) -> LoopCandidate.TransitionMetrics {
        guard let buffer = audioBuffer,
              let channelData = buffer.floatChannelData else {
            return createDefaultMetrics(poor: true)
        }
        
        let samples = channelData[0]
        let loopStartFrame = Int(loopStart * sampleRate)
        let loopEndFrame = Int(loopEnd * sampleRate)
        let totalFrames = Int(buffer.frameLength)
        
        // Ensure frames are valid
        guard loopStartFrame >= 0 && loopEndFrame > loopStartFrame &&
              loopEndFrame < totalFrames else {
            return createDefaultMetrics(poor: true)
        }
        
        // Extract samples for analysis - using longer windows for better context
        let analysisWindowSize = Int(sampleRate * 0.5)  // 0.5 second window
        
        let preLoopSamples = extractSamples(from: samples,
                                         startFrame: max(0, loopEndFrame - analysisWindowSize),
                                         count: min(analysisWindowSize, loopEndFrame))
        
        let postLoopSamples = extractSamples(from: samples,
                                          startFrame: loopStartFrame,
                                          count: min(analysisWindowSize, totalFrames - loopStartFrame))
        
        // Basic acoustic metrics
        let preLoopRMS = calculateRMS(samples: preLoopSamples)
        let postLoopRMS = calculateRMS(samples: postLoopSamples)
        
        let volumeChange = abs(preLoopRMS - postLoopRMS) / max(0.0001, max(preLoopRMS, postLoopRMS)) * 100
        
        // Phase analysis
        let preLoopEndValue = preLoopSamples.last ?? 0
        let postLoopStartValue = postLoopSamples.first ?? 0
        let phaseJump = abs(preLoopEndValue - postLoopStartValue)
        
        // Zero crossing check
        let zeroEnd = abs(preLoopEndValue) < 0.01
        let zeroStart = abs(postLoopStartValue) < 0.01
        
        // Enhanced spectral analysis focusing on perceptually important bands
        let spectralDifference = calculateEnhancedSpectralDifference(preLoopSamples, postLoopSamples)
        
        // Improved harmonic continuity analysis
        let harmonicContinuity = calculateEnhancedHarmonicContinuity(preLoopSamples, postLoopSamples)
        
        // Enhanced envelope continuity with focus on attack transients
        let envelopeContinuity = calculateEnhancedEnvelopeContinuity(preLoopSamples, postLoopSamples)
        
        return LoopCandidate.TransitionMetrics(
            volumeChange: volumeChange,
            phaseJump: phaseJump,
            spectralDifference: spectralDifference,
            harmonicContinuity: harmonicContinuity,
            envelopeContinuity: envelopeContinuity,
            zeroStart: zeroStart,
            zeroEnd: zeroEnd
        )
    }

    /**
     * Helper to create default metrics when analysis cannot be performed
     */
    private func createDefaultMetrics(poor: Bool) -> LoopCandidate.TransitionMetrics {
        return LoopCandidate.TransitionMetrics(
            volumeChange: poor ? 100.0 : 0.0,
            phaseJump: poor ? 1.0 : 0.0,
            spectralDifference: poor ? 1.0 : 0.0,
            harmonicContinuity: poor ? 0.0 : 1.0,
            envelopeContinuity: poor ? 0.0 : 1.0,
            zeroStart: false,
            zeroEnd: false
        )
    }

    /**
     * Enhanced spectral difference calculation that weights frequency bands
     * according to their perceptual importance.
     */
    private func calculateEnhancedSpectralDifference(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // Calculate FFTs
        let preLoopFFT = calculateFFTMagnitudes(preLoopSamples)
        let postLoopFFT = calculateFFTMagnitudes(postLoopSamples)
        
        // Compare frequency content with perceptual weighting
        let minSize = min(preLoopFFT.count, postLoopFFT.count)
        
        // Define perceptual bands (approximate for 44.1kHz)
        // Bass: 0-300Hz, Low-Mid: 300-1000Hz, Mid: 1000-3000Hz, Hi: 3000+Hz
        let bassRange = minSize / 70    // ~300Hz
        let lowMidRange = minSize / 20  // ~1000Hz
        let midRange = minSize / 7      // ~3000Hz
        
        // Initialize band differences and magnitudes
        var bassDiff: Float = 0
        var bassMag: Float = 0
        var lowMidDiff: Float = 0
        var lowMidMag: Float = 0
        var midDiff: Float = 0
        var midMag: Float = 0
        var highDiff: Float = 0
        var highMag: Float = 0
        
        // Bass range (fundamental notes, most important for tonality)
        for i in 1..<bassRange {
            bassDiff += abs(preLoopFFT[i] - postLoopFFT[i])
            bassMag += max(preLoopFFT[i], postLoopFFT[i])
        }
        
        // Low-mid range (strong harmonic presence)
        for i in bassRange..<lowMidRange {
            lowMidDiff += abs(preLoopFFT[i] - postLoopFFT[i])
            lowMidMag += max(preLoopFFT[i], postLoopFFT[i])
        }
        
        // Mid range (vocals, leads, important for timbre)
        for i in lowMidRange..<midRange {
            midDiff += abs(preLoopFFT[i] - postLoopFFT[i])
            midMag += max(preLoopFFT[i], postLoopFFT[i])
        }
        
        // High range (cymbals, ambience, less important for loop continuity)
        for i in midRange..<minSize {
            highDiff += abs(preLoopFFT[i] - postLoopFFT[i])
            highMag += max(preLoopFFT[i], postLoopFFT[i])
        }
        
        // Calculate band-specific scores (0-1, lower is better)
        let bassScore = bassMag > 0 ? bassDiff / bassMag : 1.0
        let lowMidScore = lowMidMag > 0 ? lowMidDiff / lowMidMag : 1.0
        let midScore = midMag > 0 ? midDiff / midMag : 1.0
        let highScore = highMag > 0 ? highDiff / highMag : 1.0
        
        // Weighted average with greater emphasis on bass and low-mid
        // These bands contain most of the musical information
        let weightedDifference = (bassScore * 0.4) +
                                 (lowMidScore * 0.3) +
                                 (midScore * 0.2) +
                                 (highScore * 0.1)
        
        return weightedDifference
    }

    /**
     * Enhanced harmonic continuity analysis that focuses on
     * musical relationships between the loop end and start.
     */
    private func calculateEnhancedHarmonicContinuity(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // Generate chromagram if possible (frequency domain representation of pitch classes)
        let preChroma = generateChromagram(preLoopSamples)
        let postChroma = generateChromagram(postLoopSamples)
        
        // If chromagram generation failed, use simpler correlation method
        if preChroma.isEmpty || postChroma.isEmpty {
            return calculateHarmonicContinuity(preLoopSamples, postLoopSamples)
        }
        
        // Get average chromagram for the last portion of pre-loop
        // and first portion of post-loop (these represent the harmonic context)
        let preContext = averageChromaFrames(preChroma.suffix(3))
        let postContext = averageChromaFrames(postChroma.prefix(3))
        
        // 1. Basic chromagram correlation
        var correlation: Float = 0
        var normPre: Float = 0
        var normPost: Float = 0
        
        for bin in 0..<12 {
            correlation += preContext[bin] * postContext[bin]
            normPre += preContext[bin] * preContext[bin]
            normPost += postContext[bin] * postContext[bin]
        }
        
        let basicCorrelation = (normPre > 0 && normPost > 0) ?
                               correlation / sqrt(normPre * normPost) : 0
        
        // 2. Harmonic function analysis
        var harmonicScore: Float = 0
        
        // Find strongest pitch classes
        let preStrong = findStrongPitchClasses(preContext)
        let postStrong = findStrongPitchClasses(postContext)
        
        // Check for perfect matches and musically compatible pitch classes
        let perfectMatches = Set(preStrong).intersection(Set(postStrong))
        
        // If we have direct pitch class matches, that's ideal
        if !perfectMatches.isEmpty {
            harmonicScore = 1.0
        } else {
            // Check for harmonically compatible pitch classes
            for prePitch in preStrong {
                for postPitch in postStrong {
                    // Calculate interval between pitch classes
                    let interval = abs(prePitch - postPitch) % 12
                    
                    // Score higher for consonant intervals (perfect 5th = 7, perfect 4th = 5)
                    if interval == 7 || interval == 5 {
                        harmonicScore += 0.8  // Strong harmonic relationship
                    } else if interval == 4 || interval == 3 {
                        harmonicScore += 0.6  // Major/minor third
                    } else if interval == 9 || interval == 8 {
                        harmonicScore += 0.4  // Major/minor sixth
                    } else {
                        harmonicScore += 0.2  // Other intervals
                    }
                }
            }
            
            // Normalize
            if !preStrong.isEmpty && !postStrong.isEmpty {
                harmonicScore /= Float(preStrong.count * postStrong.count)
            }
        }
        
        // Combined score with emphasis on basic correlation
        return (basicCorrelation * 0.7) + (harmonicScore * 0.3)
    }

    /**
     * Helper to find the strongest pitch classes in a chroma vector
     */
    private func findStrongPitchClasses(_ chroma: [Float]) -> [Int] {
        guard !chroma.isEmpty else { return [] }
        
        // Find maximum value in chroma
        let maxVal = chroma.max() ?? 0
        
        // Use scaled threshold based on maximum
        let threshold = maxVal * 0.6  // Consider pitch classes at least 60% as strong as maximum
        
        // Return indices of strong pitch classes
        return chroma.indices.filter { chroma[$0] >= threshold }
    }

    /**
     * Helper to average multiple chroma frames
     */
    private func averageChromaFrames(_ frames: ArraySlice<[Float]>) -> [Float] {
        var result = [Float](repeating: 0, count: 12)
        
        if frames.isEmpty {
            return result
        }
        
        for frame in frames {
            for i in 0..<min(12, frame.count) {
                result[i] += frame[i]
            }
        }
        
        // Normalize
        for i in 0..<12 {
            result[i] /= Float(frames.count)
        }
        
        return result
    }

    /**
     * Enhanced envelope continuity analysis that focuses on the rhythmic
     * flow between loop end and start.
     */
    private func calculateEnhancedEnvelopeContinuity(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // Use smaller window for detailed envelope analysis
        let windowSize = 256  // ~6ms at 44.1kHz
        
        // Calculate number of windows
        let preWindowCount = preLoopSamples.count / windowSize
        let postWindowCount = postLoopSamples.count / windowSize
        
        guard preWindowCount > 0 && postWindowCount > 0 else { return 0 }
        
        // Extract amplitude envelopes
        var preEnvelope = [Float]()
        var postEnvelope = [Float]()
        
        for i in 0..<preWindowCount {
            let start = i * windowSize
            let end = min(start + windowSize, preLoopSamples.count)
            preEnvelope.append(calculateRMS(samples: Array(preLoopSamples[start..<end])))
        }
        
        for i in 0..<postWindowCount {
            let start = i * windowSize
            let end = min(start + windowSize, postLoopSamples.count)
            postEnvelope.append(calculateRMS(samples: Array(postLoopSamples[start..<end])))
        }
        
        // 1. Calculate envelope shape continuity (how smoothly the amplitude flows)
        let compareLength = min(5, min(preEnvelope.count, postEnvelope.count))
        
        if compareLength <= 1 {
            return 0.5  // Not enough data for good analysis, return neutral score
        }
        
        let preEndEnvelope = Array(preEnvelope.suffix(compareLength))
        let postStartEnvelope = Array(postEnvelope.prefix(compareLength))
        
        var shapeErrorSum: Float = 0
        var totalMagnitude: Float = 0
        
        for i in 0..<compareLength {
            shapeErrorSum += abs(preEndEnvelope[i] - postStartEnvelope[i])
            totalMagnitude += max(preEndEnvelope[i], postStartEnvelope[i])
        }
        
        // Basic envelope continuity score
        let basicContinuity = totalMagnitude > 0 ? 1.0 - (shapeErrorSum / totalMagnitude) : 0
        
        // 2. Calculate envelope derivative continuity (how the rate of change flows)
        var preDerivative = [Float]()
        var postDerivative = [Float]()
        
        for i in 1..<preEndEnvelope.count {
            preDerivative.append(preEndEnvelope[i] - preEndEnvelope[i-1])
        }
        
        for i in 1..<postStartEnvelope.count {
            postDerivative.append(postStartEnvelope[i] - postStartEnvelope[i-1])
        }
        
        if preDerivative.isEmpty || postDerivative.isEmpty {
            return basicContinuity  // Not enough data for derivative analysis
        }
        
        // Compare derivatives (how amplitude changes across boundary)
        let preLastDerivative = preDerivative.last!
        let postFirstDerivative = postDerivative.first!
        
        // Normalize to a 0-1 scale (1 = perfect match)
        let maxDerivativeMagnitude = max(abs(preLastDerivative), abs(postFirstDerivative))
        let derivativeContinuity = maxDerivativeMagnitude > 0 ?
                                  1.0 - (abs(preLastDerivative - postFirstDerivative) / maxDerivativeMagnitude) : 1.0
        
        // Combined score with more emphasis on basic continuity
        return (basicContinuity * 0.7) + (derivativeContinuity * 0.3)
    }
    
    /**
     * Extract samples from buffer for analysis
     */
    private func extractSamples(from buffer: UnsafePointer<Float>, startFrame: Int, count: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        samples.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress!.update(from: buffer.advanced(by: startFrame), count: count)
        }
        return samples
    }
    
    /**
     * Calculate spectral difference between two sample arrays
     */
    private func calculateTransitionSpectralDifference(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // Calculate FFTs
        let preLoopFFT = calculateTransitionFFT(preLoopSamples)
        let postLoopFFT = calculateTransitionFFT(postLoopSamples)
        
        // Calculate normalized difference between spectra
        var totalDifference: Float = 0
        var totalMagnitude: Float = 0
        
        let minSize = min(preLoopFFT.count, postLoopFFT.count)
        for i in 0..<minSize {
            let diff = abs(preLoopFFT[i] - postLoopFFT[i])
            totalDifference += diff
            totalMagnitude += max(preLoopFFT[i], postLoopFFT[i])
        }
        
        return totalMagnitude > 0 ? totalDifference / totalMagnitude : 1.0
    }
    
    /**
     * Calculate FFT for transition analysis
     */
    private func calculateTransitionFFT(_ samples: [Float]) -> [Float] {
        // Pad to power of 2 if needed
        let nextPowerOf2 = Int(pow(2, ceil(log2(Float(samples.count)))))
        var paddedSamples = samples
        if paddedSamples.count < nextPowerOf2 {
            paddedSamples.append(contentsOf: [Float](repeating: 0, count: nextPowerOf2 - samples.count))
        }
        
        // Apply window function
        var windowedSamples = [Float](repeating: 0, count: paddedSamples.count)
        vDSP_hann_window(&windowedSamples, vDSP_Length(paddedSamples.count), Int32(0))
        vDSP_vmul(paddedSamples, 1, windowedSamples, 1, &windowedSamples, 1, vDSP_Length(paddedSamples.count))
        
        // Setup FFT
        let log2n = vDSP_Length(log2(Float(paddedSamples.count)))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        var realp = [Float](repeating: 0, count: paddedSamples.count/2)
        var imagp = [Float](repeating: 0, count: paddedSamples.count/2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        // Convert to split complex format
        windowedSamples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: paddedSamples.count/2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(paddedSamples.count/2))
            }
        }
        
        // Perform forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: paddedSamples.count/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(paddedSamples.count/2))
        
        // Cleanup
        vDSP_destroy_fftsetup(fftSetup)
        
        return magnitudes
    }
    
    /**
     * Improved harmonic analysis that evaluates not just spectral overlap but musical coherence.
     * Uses chromagram-based analysis to detect harmonic compatibility between loop points.
     */
    private func calculateHarmonicContinuity(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // 1. Generate chromagrams (12-bin pitch class profiles) for both segments
        let preChroma = generateChromagram(preLoopSamples)
        let postChroma = generateChromagram(postLoopSamples)
        
        // If chromagram generation failed, fall back to original method
        if preChroma.isEmpty || postChroma.isEmpty {
            return calculateHarmonicContinuity(preLoopSamples, postLoopSamples)
        }
        
        // 2. Calculate harmonic vector correlation
        var correlation: Float = 0
        var normPre: Float = 0
        var normPost: Float = 0
        
        // Calculate correlation between the last frame of the first segment and
        // the first frame of the second segment
        let preLastFrame = preChroma.last!
        let postFirstFrame = postChroma.first!
        
        for i in 0..<12 {
            correlation += preLastFrame[i] * postFirstFrame[i]
            normPre += preLastFrame[i] * preLastFrame[i]
            normPost += postFirstFrame[i] * postFirstFrame[i]
        }
        
        // Normalized correlation
        let frameCorrelation = (normPre > 0 && normPost > 0) ?
                               correlation / sqrt(normPre * normPost) : 0
        
        // 3. Calculate harmonic progression correlation (key context)
        var contextCorrelation: Float = 0
        
        // Use up to 3 frames from each side to establish harmonic context
        let preContextSize = min(3, preChroma.count)
        let postContextSize = min(3, postChroma.count)
        
        if preContextSize > 0 && postContextSize > 0 {
            // Average the chroma frames to get harmonic context
            var preContext = [Float](repeating: 0, count: 12)
            var postContext = [Float](repeating: 0, count: 12)
            
            for i in preChroma.count - preContextSize..<preChroma.count {
                for bin in 0..<12 {
                    preContext[bin] += preChroma[i][bin]
                }
            }
            
            for i in 0..<postContextSize {
                for bin in 0..<12 {
                    postContext[bin] += postChroma[i][bin]
                }
            }
            
            // Normalize
            for bin in 0..<12 {
                preContext[bin] /= Float(preContextSize)
                postContext[bin] /= Float(postContextSize)
            }
            
            // Calculate correlation of contexts
            var ctxCorr: Float = 0
            var ctxNormPre: Float = 0
            var ctxNormPost: Float = 0
            
            for bin in 0..<12 {
                ctxCorr += preContext[bin] * postContext[bin]
                ctxNormPre += preContext[bin] * preContext[bin]
                ctxNormPost += postContext[bin] * postContext[bin]
            }
            
            contextCorrelation = (ctxNormPre > 0 && ctxNormPost > 0) ?
                                 ctxCorr / sqrt(ctxNormPre * ctxNormPost) : 0
        }
        
        // 4. Combine frame and context correlations
        // Direct transition is more important, but context matters for musicality
        let combinedScore = (frameCorrelation * 0.7) + (contextCorrelation * 0.3)
        
        // 5. Apply musically-informed heuristics
        var finalScore = combinedScore
        
        // Check if either context has a very strong tonal center
        let preMaxTone = preLastFrame.max() ?? 0
        let postMaxTone = postFirstFrame.max() ?? 0
        
        // If one side has very strong tonal presence but the other doesn't,
        // that's usually an indicator of poor transition
        if (preMaxTone > 0.5 && postMaxTone < 0.2) ||
           (postMaxTone > 0.5 && preMaxTone < 0.2) {
            finalScore *= 0.7
        }
        
        // Boost score if the maximum tonal elements are harmonically related
        // (e.g., perfect fifth = 7 semitones, major third = 4 semitones)
        if preMaxTone > 0.3 && postMaxTone > 0.3 {
            let preMaxIndex = preLastFrame.firstIndex(of: preMaxTone) ?? 0
            let postMaxIndex = postFirstFrame.firstIndex(of: postMaxTone) ?? 0
            
            let interval = abs(preMaxIndex - postMaxIndex)
            let harmonicIntervals = [0, 4, 5, 7, 9] // Unison, M3, P4, P5, M6
            
            if harmonicIntervals.contains(interval % 12) {
                finalScore = min(1.0, finalScore * 1.2)
            }
        }
        
        return finalScore
    }

    /**
     * Generates a chromagram (12-bin pitch class profile) from audio samples.
     * Each chromatogram has 12 bins representing the 12 semitones of the chromatic scale.
     * Returns an array of chroma frames.
     */
    private func generateChromagram(_ samples: [Float]) -> [[Float]] {
        // Ensure we have enough samples
        guard samples.count >= 1024 else { return [] }
        
        // Number of frames to process
        let frameSize = 2048
        let hopSize = 1024
        let nFrames = (samples.count - frameSize) / hopSize + 1
        
        // Early return if we don't have enough data
        if nFrames <= 0 {
            return []
        }
        
        var chromagram = [[Float]](repeating: [Float](repeating: 0, count: 12), count: nFrames)
        
        for frameIndex in 0..<nFrames {
            let startIdx = frameIndex * hopSize
            let endIdx = min(startIdx + frameSize, samples.count)
            var frameSamples = Array(samples[startIdx..<endIdx])
            
            // Zero-pad if needed
            while frameSamples.count < frameSize {
                frameSamples.append(0)
            }
            
            // Apply Hann window
            for i in 0..<frameSamples.count {
                let windowFactor = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(frameSamples.count - 1)))
                frameSamples[i] *= windowFactor
            }
            
            // Compute FFT
            let magnitudes = calculateFFTMagnitudes(frameSamples)
            
            // Map FFT bins to chromatic scale (12 pitch classes)
            mapFFTToChroma(magnitudes, outputChroma: &chromagram[frameIndex])
        }
        
        return chromagram
    }

    /**
     * Helper function to calculate FFT magnitudes
     */
    private func calculateFFTMagnitudes(_ samples: [Float]) -> [Float] {
        // Setup FFT
        let log2n = vDSP_Length(log2(Float(samples.count)))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        // Prepare for split complex FFT
        var realp = [Float](repeating: 0, count: samples.count/2)
        var imagp = [Float](repeating: 0, count: samples.count/2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        // Convert to split complex format
        samples.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: samples.count/2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(samples.count/2))
            }
        }
        
        // Perform forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
        
        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: samples.count/2)
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(samples.count/2))
        
        // Clean up
        vDSP_destroy_fftsetup(fftSetup)
        
        return magnitudes
    }

    /**
     * Maps FFT magnitude spectrum to chromagram (12 pitch classes)
     */
    private func mapFFTToChroma(_ magnitudes: [Float], outputChroma: inout [Float]) {
        // Reset chroma values
        for i in 0..<12 {
            outputChroma[i] = 0
        }
        
        // Reference frequency for A4 (MIDI note 69)
        let A4 = 440.0
        
        // Calculate frequencies for each FFT bin
        let binCount = magnitudes.count
        let nyquistFreq = sampleRate / 2.0
        
        // Map each FFT bin to a pitch class (0-11)
        for bin in 1..<binCount {
            let frequency = (Double(bin) / Double(binCount)) * nyquistFreq
            
            // Skip very low and very high frequencies
            if frequency < 20.0 || frequency > 8000.0 {
                continue
            }
            
            // Convert frequency to MIDI note number
            let noteNumber = 12 * log2(frequency / A4) + 69
            
            // Skip invalid notes
            if noteNumber < 0 {
                continue
            }
            
            // Map to pitch class (0-11)
            let pitchClass = Int(round(noteNumber).truncatingRemainder(dividingBy: 12))
            
            // Add magnitude to corresponding pitch class
            // Weight higher frequencies lower to emphasize bass notes
            let weight = 1.0 / sqrt(frequency)
            outputChroma[pitchClass] += magnitudes[bin] * Float(weight)
        }
        
        // Normalize
        let maxVal = outputChroma.max() ?? 1.0
        if maxVal > 0 {
            for i in 0..<12 {
                outputChroma[i] /= maxVal
            }
        }
    }
    
    /**
     * Calculate envelope continuity between two sample arrays
     */
    private func calculateEnvelopeContinuity(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // Divide samples into small segments and compare RMS values
        let segmentSize = 128 // ~3ms at 44.1kHz
        let preSegmentCount = preLoopSamples.count / segmentSize
        let postSegmentCount = postLoopSamples.count / segmentSize
        
        guard preSegmentCount > 0 && postSegmentCount > 0 else { return 0 }
        
        var preEnvelope = [Float]()
        var postEnvelope = [Float]()
        
        // Calculate RMS envelope for pre-loop
        for i in 0..<preSegmentCount {
            let startIdx = i * segmentSize
            let endIdx = min(startIdx + segmentSize, preLoopSamples.count)
            let segment = Array(preLoopSamples[startIdx..<endIdx])
            preEnvelope.append(calculateRMS(samples: segment))
        }
        
        // Calculate RMS envelope for post-loop
        for i in 0..<postSegmentCount {
            let startIdx = i * segmentSize
            let endIdx = min(startIdx + segmentSize, postLoopSamples.count)
            let segment = Array(postLoopSamples[startIdx..<endIdx])
            postEnvelope.append(calculateRMS(samples: segment))
        }
        
        // Compare the end of pre-envelope with start of post-envelope
        let comparisonLength = min(3, min(preEnvelope.count, postEnvelope.count))
        var continuity: Float = 1.0
        
        if comparisonLength > 0 {
            let preEnd = Array(preEnvelope.suffix(comparisonLength))
            let postStart = Array(postEnvelope.prefix(comparisonLength))
            
            var totalDiff: Float = 0
            var totalValue: Float = 0
            
            for i in 0..<comparisonLength {
                totalDiff += abs(preEnd[i] - postStart[i])
                totalValue += max(preEnd[i], postStart[i])
            }
            
            continuity = totalValue > 0 ? 1.0 - (totalDiff / totalValue) : 0
        }
        
        return continuity
    }
    
    /**
     * Improved quality metric calculation with perceptual weighting.
     * This provides a better score that aligns with human perception of loop quality.
     */
    private func calculateOverallQuality(metrics: LoopCandidate.TransitionMetrics) -> Float {
        // Revised weights focusing on perceptually important factors
        let volumeWeight: Float = 0.20    // Increased (very noticeable)
        let phaseWeight: Float = 0.15     // Decreased (less perceptually important)
        let spectralWeight: Float = 0.15  // Decreased (less perceptually important)
        let harmonicWeight: Float = 0.30  // Increased (crucial for musical coherence)
        let envelopeWeight: Float = 0.20  // Increased (important for rhythm continuity)
        
        // Volume score - severe penalty for large changes
        let volumeScore: Float
        if metrics.volumeChange < 10 {
            volumeScore = 10.0  // Virtually perfect
        } else if metrics.volumeChange < 30 {
            volumeScore = 10.0 - (metrics.volumeChange - 10) / 2.0  // Gradual penalty
        } else if metrics.volumeChange < 60 {
            volumeScore = 5.0 - (metrics.volumeChange - 30) / 10.0  // Steeper penalty
        } else {
            volumeScore = max(0.0, 2.0 - (metrics.volumeChange - 60) / 20.0)  // Very poor
        }
        
        // Phase jump - exponential penalty for discontinuities
        let phaseScore = 10.0 * exp(-metrics.phaseJump * 10.0)
        
        // Spectral difference - progressive penalty
        let spectralScore: Float
        if metrics.spectralDifference < 0.3 {
            spectralScore = 10.0 - metrics.spectralDifference * 20.0  // Mild penalty
        } else if metrics.spectralDifference < 0.7 {
            spectralScore = 4.0 - (metrics.spectralDifference - 0.3) * 7.5  // Steeper penalty
        } else {
            spectralScore = max(0.0, 1.0 - (metrics.spectralDifference - 0.7) * 3.3)  // Very poor
        }
        
        // Harmonic continuity - reward high values
        let harmonicScore: Float
        if metrics.harmonicContinuity > 0.8 {
            harmonicScore = 10.0  // Perfect score for excellent continuity
        } else if metrics.harmonicContinuity > 0.5 {
            harmonicScore = 7.0 + (metrics.harmonicContinuity - 0.5) * 10.0  // Bonus for good scores
        } else if metrics.harmonicContinuity > 0.3 {
            harmonicScore = 4.0 + (metrics.harmonicContinuity - 0.3) * 15.0  // Mid range
        } else {
            harmonicScore = metrics.harmonicContinuity * 13.3  // Poor range
        }
        
        // Envelope continuity - similar emphasis to harmonic
        let envelopeScore: Float
        if metrics.envelopeContinuity > 0.7 {
            envelopeScore = 10.0  // Perfect score
        } else if metrics.envelopeContinuity > 0.4 {
            envelopeScore = 7.0 + (metrics.envelopeContinuity - 0.4) * 10.0  // Good range
        } else {
            envelopeScore = metrics.envelopeContinuity * 17.5  // Poor range
        }
        
        // Bonus for zero crossings
        let zeroBonus: Float
        if metrics.zeroStart && metrics.zeroEnd {
            zeroBonus = 1.0  // Both start and end at zero crossing
        } else if metrics.zeroStart || metrics.zeroEnd {
            zeroBonus = 0.5  // Either start or end at zero crossing
        } else {
            zeroBonus = 0.0  // No zero crossings
        }
        
        // Detailed per-metric scores for debugging
        print("Quality component scores:")
        print("  Volume Score: \(volumeScore)/10 (weight: \(volumeWeight))")
        print("  Phase Score: \(phaseScore)/10 (weight: \(phaseWeight))")
        print("  Spectral Score: \(spectralScore)/10 (weight: \(spectralWeight))")
        print("  Harmonic Score: \(harmonicScore)/10 (weight: \(harmonicWeight))")
        print("  Envelope Score: \(envelopeScore)/10 (weight: \(envelopeWeight))")
        print("  Zero Crossing Bonus: \(zeroBonus)")
        
        // Weighted score calculation
        let weightedScore = volumeWeight * volumeScore +
                          phaseWeight * phaseScore +
                          spectralWeight * spectralScore +
                          harmonicWeight * harmonicScore +
                          envelopeWeight * envelopeScore +
                          zeroBonus
        
        // Ensure score is within 0-10 range
        let finalScore = max(0.0, min(10.0, weightedScore))
        
        print("Final quality score: \(finalScore)/10")
        
        return finalScore
    }
    
    /**
     * Enhanced loop candidate selection with perceptually weighted scoring
     * that prioritizes musical coherence over simple acoustic similarity.
     */
    private func selectBestLoopCandidate() {
        guard !loopCandidates.isEmpty else {
            // Fallback to traditional section-based approach if no good candidates
            findGameMusicLoopPoints()
            return
        }
        
        // Apply enhanced game music specific heuristics to the candidates
        var scoredCandidates = loopCandidates.map { candidate -> (LoopCandidate, Float) in
            // Start with the base quality score
            var score = candidate.quality
            let metrics = candidate.metrics
            
            // 1. Apply perceptually weighted adjustments
            
            // Extreme volume changes are very noticeable and problematic
            if metrics.volumeChange > 30 {
                // Apply a stronger penalty for large volume changes
                score -= (metrics.volumeChange - 30) / 10
            }
            
            // Phase jump is critically important - exponential penalty for large jumps
            if metrics.phaseJump > 0.1 {
                // Stronger penalty for phase discontinuities
                score -= pow(metrics.phaseJump * 5, 2)
            }
            
            // Zero crossing bonus - more important than in original implementation
            if metrics.zeroStart && metrics.zeroEnd {
                score += 2.0 // Significant bonus for perfect zero crossings
            } else if metrics.zeroStart || metrics.zeroEnd {
                score += 0.5 // Small bonus for partial zero crossing
            }
            
            // Harmonic continuity is crucial for musical coherence
            if metrics.harmonicContinuity < 0.3 {
                // Severe penalty for poor harmonic continuity
                score -= (0.3 - metrics.harmonicContinuity) * 15
            } else {
                // Bonus for good harmonic continuity
                score += (metrics.harmonicContinuity - 0.3) * 5
            }
            
            // 2. Structural alignment bonuses
            
            // Bonus for aligning with phrase boundaries (from our new detection)
            let phraseBoundaries = findMusicalPhrasePoints()
            
            let startAligned = phraseBoundaries.contains { abs($0 - candidate.startTime) < 0.1 }
            let endAligned = phraseBoundaries.contains { abs($0 - candidate.endTime) < 0.1 }
            
            if startAligned {
                score += 2.0  // Significant bonus for phrase alignment
                print("Candidate at \(TimeFormatter.formatPrecise(candidate.startTime)) aligns with phrase boundary")
            }
            
            if endAligned {
                score += 1.5  // Bonus for end alignment (slightly less important than start)
                print("Candidate at \(TimeFormatter.formatPrecise(candidate.endTime)) aligns with phrase boundary")
            }
            
            // 3. Duration-based adjustments
            
            // Favor musically plausible durations
            let duration = candidate.endTime - candidate.startTime
            let totalDuration = Double(audioBuffer?.frameLength ?? 0) / sampleRate
            
            // Most game music loops are between 20-60% of the total duration
            let normalizedDuration = duration / totalDuration
            
            if normalizedDuration < 0.1 {
                // Penalty for extremely short loops (likely too short to be musical)
                score -= 3.0
                print("Candidate duration \(TimeFormatter.formatPrecise(duration)) is very short (penalty applied)")
            } else if normalizedDuration > 0.7 {
                // Penalty for very long loops (often means we're just looping the whole track)
                score -= 2.0
                print("Candidate duration \(TimeFormatter.formatPrecise(duration)) is very long (penalty applied)")
            } else if normalizedDuration >= 0.2 && normalizedDuration <= 0.6 {
                // Ideal range bonus
                score += 1.0
                print("Candidate duration \(TimeFormatter.formatPrecise(duration)) is in ideal range (bonus applied)")
            }
            
            // 4. Musical timing heuristics - prefer loops with durations that are likely
            // to be musically coherent (common bar counts in game music)
            
            // Estimate tempo from phrase boundaries if available
            if phraseBoundaries.count >= 2 {
                let estimatedBeatsPerSecond = estimateTempoFromPhrases(phraseBoundaries)
                
                if estimatedBeatsPerSecond > 0 {
                    // Most game music is in 4/4 or other multiples of 4
                    // Check if loop duration is close to a multiple of 4 beats
                    let durationInBeats = duration * estimatedBeatsPerSecond
                    let nearestMultipleOf4 = round(durationInBeats / 4) * 4
                    
                    // Calculate how close we are to an exact musical phrase
                    let beatError = abs(durationInBeats - nearestMultipleOf4)
                    
                    if beatError < 0.25 {
                        // Very close to exact musical timing - major bonus
                        score += 3.0
                        print("Candidate duration \(TimeFormatter.formatPrecise(duration)) aligns with musical timing at \(Int(nearestMultipleOf4)) beats")
                    } else if beatError < 0.5 {
                        // Close to musical timing - moderate bonus
                        score += 1.5
                    }
                }
            }
            
            return (candidate, score)
        }
        
        // Sort by adjusted score
        scoredCandidates.sort { $0.1 > $1.1 }
        
        // Print the top candidates for debugging
        print("Top loop candidates after enhanced scoring:")
        for i in 0..<min(3, scoredCandidates.count) {
            let (candidate, score) = scoredCandidates[i]
            print("Rank \(i+1): \(TimeFormatter.formatPrecise(candidate.startTime)) → \(TimeFormatter.formatPrecise(candidate.endTime)), Score: \(score), Original quality: \(candidate.quality)")
        }
        
        // Select best candidate
        if let (bestCandidate, adjustedScore) = scoredCandidates.first {
            DispatchQueue.main.async {
                self.suggestedLoopStart = bestCandidate.startTime
                self.suggestedLoopEnd = bestCandidate.endTime
                self.transitionQuality = bestCandidate.quality  // Keep original quality for consistency
                
                print("Selected best loop: \(TimeFormatter.formatPrecise(bestCandidate.startTime)) to \(TimeFormatter.formatPrecise(bestCandidate.endTime))")
                print("Original quality: \(bestCandidate.quality)/10, Adjusted score: \(adjustedScore)")
                print("Metrics: Volume change: \(bestCandidate.metrics.volumeChange)%, Phase jump: \(bestCandidate.metrics.phaseJump)")
                print("Harmonic continuity: \(bestCandidate.metrics.harmonicContinuity * 100)%, Spectral difference: \(bestCandidate.metrics.spectralDifference * 100)%")
            }
        } else {
            // Fallback to traditional approach
            findGameMusicLoopPoints()
        }
    }

    /**
     * Estimates tempo in beats per second from detected phrase boundaries
     */
    private func estimateTempoFromPhrases(_ phraseBoundaries: [TimeInterval]) -> Double {
        guard phraseBoundaries.count >= 2 else { return 0 }
        
        // Calculate intervals between consecutive phrase boundaries
        var intervals: [TimeInterval] = []
        for i in 0..<phraseBoundaries.count-1 {
            intervals.append(phraseBoundaries[i+1] - phraseBoundaries[i])
        }
        
        // Group similar intervals to find the most common one
        let intervalTolerance = 0.1  // 10% tolerance for interval matching
        var intervalGroups: [TimeInterval: Int] = [:]
        
        for interval in intervals {
            var matched = false
            
            for (groupInterval, count) in intervalGroups {
                // Check if this interval matches an existing group
                if abs(interval - groupInterval) / groupInterval < intervalTolerance {
                    intervalGroups[groupInterval] = count + 1
                    matched = true
                    break
                }
            }
            
            if !matched {
                intervalGroups[interval] = 1
            }
        }
        
        // Find the most common interval
        var mostCommonInterval: TimeInterval = 0
        var maxCount = 0
        
        for (interval, count) in intervalGroups {
            if count > maxCount {
                maxCount = count
                mostCommonInterval = interval
            }
        }
        
        // Only use the result if it's sufficiently consistent
        if maxCount >= max(2, intervals.count / 3) {
            // Most phrase boundaries are likely to be 4 or 8 beats apart in game music
            // We'll assume 4 beats between phrases as a conservative estimate
            let beatsPerPhrase = 4.0
            let beatsPerSecond = beatsPerPhrase / mostCommonInterval
            
            // Sanity check - most game music is between 60-180 BPM
            if beatsPerSecond * 60 >= 60 && beatsPerSecond * 60 <= 180 {
                print("Estimated tempo: \(beatsPerSecond * 60) BPM")
                return beatsPerSecond
            }
        }
        
        return 0  // Could not reliably estimate tempo
    }
    
    /**
     * Detects fade-outs in the audio and adjusts loop points to exclude them.
     * (Existing fallback method kept for compatibility)
     */
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
        
        // Check for fade-out
        let adjustedLoopEnd = checkForFadeOut(loopEnd)
        
        // Update the suggested values
        DispatchQueue.main.async {
            self.suggestedLoopStart = introEnd
            self.suggestedLoopEnd = adjustedLoopEnd
            self.progress = 1.0
            print("Final loop suggestion: \(TimeFormatter.formatPrecise(introEnd)) to \(TimeFormatter.formatPrecise(adjustedLoopEnd))")
        }
    }
    
    /**
     * Checks for a fade-out at the end of the track and returns an adjusted loop end point.
     * (Existing method kept for compatibility)
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
                
                // Get RMS values for the last 30% of the track
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
                
                // Check for a simple fade-out pattern
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
     * Enhanced musical phrase detection that works for any style of music.
     * Detects natural boundaries in musical structure where loops would sound most natural.
     */
    private func findMusicalPhrasePoints() -> [TimeInterval] {
        guard !features.isEmpty else { return [] }
        
        var phraseBoundaries: [TimeInterval] = []
        let windowSize = 12 // Looking at ~0.25 seconds with our hop size
        
        // 1. Detect changes in musical features that indicate transitions
        if features.count > (windowSize * 2 + 1) {
            for i in windowSize..<(features.count - windowSize) {
                // Calculate average features before and after this point
                var fluxBefore: Float = 0
                var rmsBefore: Float = 0
                var fluxAfter: Float = 0
                var rmsAfter: Float = 0
                
                for j in 1...windowSize {
                    fluxBefore += features[i-j].spectralFlux
                    rmsBefore += features[i-j].rms
                    fluxAfter += features[i+j].spectralFlux
                    rmsAfter += features[i+j].rms
                }
                
                // Average values
                fluxBefore /= Float(windowSize)
                rmsBefore /= Float(windowSize)
                fluxAfter /= Float(windowSize)
                rmsAfter /= Float(windowSize)
                
                // Calculate relative differences (percentages)
                let fluxDiff = abs(fluxAfter - fluxBefore) / max(0.001, (fluxAfter + fluxBefore) / 2)
                let rmsDiff = abs(rmsAfter - rmsBefore) / max(0.001, (rmsAfter + rmsBefore) / 2)
                
                // Significant changes indicate potential phrase boundaries
                // Use inclusive thresholds so we detect more candidates for evaluation
                if fluxDiff > 0.3 || rmsDiff > 0.25 {
                    phraseBoundaries.append(features[i].timeOffset)
                }
            }
        }
        
        // 2. Add additional boundaries at silence or near-silence points
        // These often indicate natural phrase breaks
        for i in 5..<(features.count - 5) {
            // Check if this is a local RMS minimum (quieter than neighbors)
            if features[i].rms < 0.05 &&  // Very quiet
               features[i].rms < features[i-1].rms &&
               features[i].rms < features[i+1].rms {
                phraseBoundaries.append(features[i].timeOffset)
            }
        }
        
        // 3. Filter out boundaries that are too close to each other
        phraseBoundaries = filterCloseTimePoints(phraseBoundaries, minDistance: 2.0)
        
        return phraseBoundaries
    }

    /**
     * Filters time points that are too close to each other,
     * keeping only the most significant ones.
     */
    private func filterCloseTimePoints(_ timePoints: [TimeInterval], minDistance: TimeInterval) -> [TimeInterval] {
        guard !timePoints.isEmpty else { return [] }
        
        var filteredPoints: [TimeInterval] = []
        var sortedPoints = timePoints.sorted()
        
        // Always keep the first point
        filteredPoints.append(sortedPoints[0])
        
        for point in sortedPoints.dropFirst() {
            if let lastPoint = filteredPoints.last, point - lastPoint >= minDistance {
                filteredPoints.append(point)
            }
        }
        
        return filteredPoints
    }

    /**
     * Estimates the beat interval using autocorrelation of the onset strength curve.
     * Returns the estimated number of frames per beat.
     */
    private func estimateBeatInterval(_ onsetStrength: [Float]) -> Int {
        let maxLag = min(onsetStrength.count / 2, 500) // Limit search range
        let minBPM = 60.0 // Minimum beats per minute to consider
        let maxBPM = 200.0 // Maximum beats per minute to consider
        
        // Convert BPM range to frame lags based on feature extraction rate
        let framesPerSecond = sampleRate / Double(hopSize)
        let minLag = Int(60.0 / maxBPM * framesPerSecond)
        let searchMaxLag = Int(60.0 / minBPM * framesPerSecond)
        let actualMaxLag = min(maxLag, searchMaxLag)
        
        // Calculate autocorrelation
        var autocorrelation = [Float](repeating: 0, count: actualMaxLag)
        
        for lag in minLag..<actualMaxLag {
            var sum: Float = 0
            var normFactor: Float = 0
            
            for i in 0..<(onsetStrength.count - lag) {
                sum += onsetStrength[i] * onsetStrength[i + lag]
                normFactor += onsetStrength[i] * onsetStrength[i] +
                              onsetStrength[i + lag] * onsetStrength[i + lag]
            }
            
            // Normalized autocorrelation
            autocorrelation[lag] = normFactor > 0 ? 2 * sum / normFactor : 0
        }
        
        // Find peaks in autocorrelation function
        var peakLags: [(lag: Int, value: Float)] = []
        
        for lag in (minLag + 1)..<(actualMaxLag - 1) {
            if autocorrelation[lag] > autocorrelation[lag - 1] &&
               autocorrelation[lag] > autocorrelation[lag + 1] &&
               autocorrelation[lag] > 0.5 { // Threshold for significant correlation
                peakLags.append((lag, autocorrelation[lag]))
            }
        }
        
        // Sort by correlation value
        peakLags.sort { $0.value > $1.value }
        
        // Return the highest correlation lag as our beat interval estimate
        if let bestLag = peakLags.first {
            return bestLag.lag
        }
        
        return 0 // No reliable beat interval found
    }
}
