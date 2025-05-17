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
    
    private func buildSimilarityMatrix() {
        let featureCount = features.count
        var matrix = [[Float]](repeating: [Float](repeating: 0, count: featureCount), count: featureCount)
        
        for i in 0..<featureCount {
            // Report progress
            if i % 10 == 0 {
                let progress = Double(i) / Double(featureCount)
                DispatchQueue.main.async {
                    self.progress = 0.3 + progress * 0.1 // 30-40% of analysis
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
    
    /**
     * NEW METHOD: Find optimal loop candidates based on transition quality
     * This evaluates many potential transitions rather than just section boundaries
     */
    private func findOptimalLoopCandidates() async {
        guard let buffer = audioBuffer,
              let channelData = buffer.floatChannelData else { return }
        
        let totalFrames = Int(buffer.frameLength)
        let samples = channelData[0]
        
        // 1. Start with section boundaries as initial candidates
        var candidateStarts: [TimeInterval] = []
        var candidateEnds: [TimeInterval] = []
        
        // Add section boundaries
        for section in sections {
            if section.startTime > 1.0 { // Avoid very beginning of track
                candidateStarts.append(section.startTime)
            }
            if section.endTime < Double(totalFrames) / sampleRate - 1.0 { // Avoid very end
                candidateEnds.append(section.endTime)
            }
        }
        
        // 2. Add zero crossings near section boundaries for more precise points
        for sectionTime in candidateStarts {
            let nearbyZeroCrossings = findZeroCrossingsNear(time: sectionTime,
                                                           samples: samples,
                                                           window: 0.1) // 100ms window
            candidateStarts.append(contentsOf: nearbyZeroCrossings)
        }
        
        for sectionTime in candidateEnds {
            let nearbyZeroCrossings = findZeroCrossingsNear(time: sectionTime,
                                                           samples: samples,
                                                           window: 0.1)
            candidateEnds.append(contentsOf: nearbyZeroCrossings)
        }
        
        // 3. Add additional musical event points (phrase boundaries)
        let phrasePoints = findPhraseBoundaries()
        candidateStarts.append(contentsOf: phrasePoints)
        candidateEnds.append(contentsOf: phrasePoints)
        
        // Remove duplicates and sort
        candidateStarts = Array(Set(candidateStarts)).sorted()
        candidateEnds = Array(Set(candidateEnds)).sorted()
        
        print("Found \(candidateStarts.count) candidate start points and \(candidateEnds.count) candidate end points")
        
        // 4. Evaluate all viable start/end combinations
        var loopCandidates: [LoopCandidate] = []
        let totalCombinations = candidateStarts.count * candidateEnds.count
        var progress = 0
        
        // Limit the number of combinations to evaluate to prevent freezing on large files
        let maxCombinations = 1000
        let stride = max(1, totalCombinations / maxCombinations)
        
        for (startIndex, startTime) in candidateStarts.enumerated() {
            for (endIndex, endTime) in candidateEnds.enumerated() {
                // Skip some combinations for performance if we have too many
                if totalCombinations > maxCombinations && (startIndex * candidateEnds.count + endIndex) % stride != 0 {
                    continue
                }
                
                // Report progress
                progress += 1
                if progress % 10 == 0 {
                    DispatchQueue.main.async {
                        self.progress = 0.5 + (0.3 * Double(progress) / Double(min(totalCombinations, maxCombinations)))
                    }
                }
                
                // Evaluate only valid loop regions
                if endTime > startTime &&
                   endTime - startTime >= minSectionDuration &&
                   endTime - startTime <= Double(totalFrames) / sampleRate * 0.8 {
                    
                    // Evaluate transition quality
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
        
        // Sort candidates by quality
        loopCandidates.sort { $0.quality > $1.quality }
        
        // Keep only the top candidates
        let topCount = min(10, loopCandidates.count)
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
     * Evaluates transition quality between loop end and loop start
     */
    private func evaluateTransitionQuality(loopStart: TimeInterval, loopEnd: TimeInterval) -> LoopCandidate.TransitionMetrics {
        guard let buffer = audioBuffer,
              let channelData = buffer.floatChannelData else {
            return LoopCandidate.TransitionMetrics(
                volumeChange: 1.0,
                phaseJump: 1.0,
                spectralDifference: 1.0,
                harmonicContinuity: 0.0,
                envelopeContinuity: 0.0,
                zeroStart: false,
                zeroEnd: false
            )
        }
        
        let samples = channelData[0]
        let loopStartFrame = Int(loopStart * sampleRate)
        let loopEndFrame = Int(loopEnd * sampleRate)
        let totalFrames = Int(buffer.frameLength)
        
        // Ensure frames are valid
        guard loopStartFrame >= 0 && loopEndFrame > loopStartFrame &&
              loopEndFrame < totalFrames else {
            return LoopCandidate.TransitionMetrics(
                volumeChange: 1.0,
                phaseJump: 1.0,
                spectralDifference: 1.0,
                harmonicContinuity: 0.0,
                envelopeContinuity: 0.0,
                zeroStart: false,
                zeroEnd: false
            )
        }
        
        // Extract samples around loop points
        let preLoopSamples = extractSamples(from: samples,
                                         startFrame: max(0, loopEndFrame - transitionAnalysisWindowSize),
                                         count: min(transitionAnalysisWindowSize, loopEndFrame))
        
        let postLoopSamples = extractSamples(from: samples,
                                          startFrame: loopStartFrame,
                                          count: min(transitionAnalysisWindowSize, totalFrames - loopStartFrame))
        
        // Volume change analysis
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
        
        // Spectral analysis
        let spectralDifference = calculateTransitionSpectralDifference(preLoopSamples, postLoopSamples)
        
        // Harmonic continuity
        let harmonicContinuity = calculateHarmonicContinuity(preLoopSamples, postLoopSamples)
        
        // Envelope continuity
        let envelopeContinuity = calculateEnvelopeContinuity(preLoopSamples, postLoopSamples)
        
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
     * Calculate harmonic continuity between two sample arrays
     */
    private func calculateHarmonicContinuity(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // Get frequency spectra
        let preLoopFFT = calculateTransitionFFT(preLoopSamples)
        let postLoopFFT = calculateTransitionFFT(postLoopSamples)
        
        // Focus on lower frequencies (harmonics)
        let harmonicRange = min(preLoopFFT.count, postLoopFFT.count) / 4
        
        // Find correlation between harmonic content
        var correlation: Float = 0
        var normPre: Float = 0
        var normPost: Float = 0
        
        for i in 0..<harmonicRange {
            correlation += preLoopFFT[i] * postLoopFFT[i]
            normPre += preLoopFFT[i] * preLoopFFT[i]
            normPost += postLoopFFT[i] * postLoopFFT[i]
        }
        
        let normalization = sqrt(normPre * normPost)
        return normalization > 0 ? correlation / normalization : 0
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
     * Calculate overall quality score from transition metrics
     */
    private func calculateOverallQuality(metrics: LoopCandidate.TransitionMetrics) -> Float {
        // Weight factors
        let volumeWeight: Float = 0.15
        let phaseWeight: Float = 0.2
        let spectralWeight: Float = 0.25
        let harmonicWeight: Float = 0.25
        let envelopeWeight: Float = 0.15
        
        // Convert each metric to a 0-10 scale
        let volumeScore = 10.0 * (1.0 - min(1.0, metrics.volumeChange / 100.0))
        let phaseScore = 10.0 * (1.0 - min(1.0, metrics.phaseJump * 5.0))
        let spectralScore = 10.0 * (1.0 - min(1.0, metrics.spectralDifference * 2.0))
        let harmonicScore = 10.0 * metrics.harmonicContinuity
        let envelopeScore = 10.0 * metrics.envelopeContinuity
        
        // Bonus for zero crossings
        let zeroBonus: Float = (metrics.zeroStart && metrics.zeroEnd) ? 1.0 : 0.0
        
        // Weighted average
        return volumeWeight * volumeScore +
               phaseWeight * phaseScore +
               spectralWeight * spectralScore +
               harmonicWeight * harmonicScore +
               envelopeWeight * envelopeScore +
               zeroBonus
    }
    
    /**
     * Select the best loop candidate based on transition quality and structure
     */
    private func selectBestLoopCandidate() {
        guard !loopCandidates.isEmpty else {
            // Fallback to traditional section-based approach if no good candidates
            findGameMusicLoopPoints()
            return
        }
        
        // Apply game music specific heuristics to the candidates
        
        // Prefer candidates that align with structural boundaries
        var scoredCandidates = loopCandidates.map { candidate -> (LoopCandidate, Float) in
            var score = candidate.quality
            
            // Bonus for aligning with section boundaries
            for section in sections {
                // If the start aligns with a section start
                if abs(candidate.startTime - section.startTime) < 0.1 {
                    score += 1.0
                }
                
                // If the end aligns with a section end
                if abs(candidate.endTime - section.endTime) < 0.1 {
                    score += 1.0
                }
            }
            
            // Bonus for candidates with appropriate duration (not too short or long)
            let duration = candidate.endTime - candidate.startTime
            let totalDuration = Double(audioBuffer?.frameLength ?? 0) / sampleRate
            
            // Ideal loop is between 20% and 60% of total duration
            let idealRatio = min(1.0, max(0.0, (duration / totalDuration - 0.2) / 0.4))
            score += Float(idealRatio) * 2.0
            
            // Penalty for very long loops (prefer concise loops)
            if duration > totalDuration * 0.7 {
                score -= 2.0
            }
            
            return (candidate, score)
        }
        
        // Sort by adjusted score
        scoredCandidates.sort { $0.1 > $1.1 }
        
        // Select best candidate
        if let bestCandidate = scoredCandidates.first?.0 {
            DispatchQueue.main.async {
                self.suggestedLoopStart = bestCandidate.startTime
                self.suggestedLoopEnd = bestCandidate.endTime
                self.transitionQuality = bestCandidate.quality
                
                print("Selected best loop: \(TimeFormatter.formatPrecise(bestCandidate.startTime)) to \(TimeFormatter.formatPrecise(bestCandidate.endTime))")
                print("Transition quality: \(bestCandidate.quality)/10")
                print("Volume change: \(bestCandidate.metrics.volumeChange)%")
                print("Phase jump: \(bestCandidate.metrics.phaseJump)")
                print("Spectral difference: \(bestCandidate.metrics.spectralDifference * 100)%")
                print("Harmonic continuity: \(bestCandidate.metrics.harmonicContinuity * 100)%")
            }
        } else {
            // Fallback to traditional approach
            findGameMusicLoopPoints()
        }
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
}
