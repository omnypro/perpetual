//
//  LoopTransitionAnalyzer.swift
//  Perpetual
//
//  Created by Bryan Veloso on 5/17/25.
//

import AVFoundation
import Accelerate
import Foundation

/// Specialized class for analyzing and debugging loop transitions
class LoopTransitionAnalyzer {
    private let audioManager: AudioManager
    private let windowSize: Int = 4096 // ~93ms at 44.1kHz
    
    init(audioManager: AudioManager) {
        self.audioManager = audioManager
    }
    
    /// Generate comprehensive debug information about the current loop transition
    func analyzeLoopTransition() -> String {
        guard let buffer = audioManager.getPCMBuffer,
              let channelData = buffer.floatChannelData else {
            return "Error: No audio buffer available"
        }
        
        let format = buffer.format
        
        let sampleRate = Float(format.sampleRate)
        let channels = Int(format.channelCount)
        let channelSamples = channelData[0]
        
        // Calculate frame positions
        let loopEndFrame = Int(audioManager.loopEndTime * Double(sampleRate))
        let loopStartFrame = Int(audioManager.loopStartTime * Double(sampleRate))
        let totalFrames = Int(buffer.frameLength)
        
        // Ensure we have valid frames to analyze
        guard loopStartFrame >= 0 && loopEndFrame > loopStartFrame &&
              loopEndFrame <= totalFrames else {
            return "Error: Invalid loop points for analysis"
        }
        
        // Extract samples before loop end and after loop start
        let preLoopSamples = extractSamples(from: channelSamples, startFrame: max(0, loopEndFrame - windowSize), count: min(windowSize, loopEndFrame))
        let postLoopSamples = extractSamples(from: channelSamples, startFrame: loopStartFrame, count: min(windowSize, Int(totalFrames - loopStartFrame)))
        
        // Basic metrics
        let preLoopRMS = calculateRMS(preLoopSamples)
        let postLoopRMS = calculateRMS(postLoopSamples)
        
        // Breaking up complex expression
        let rmsDifference = fabsf(preLoopRMS - postLoopRMS)
        let maxRMS = max(preLoopRMS, postLoopRMS)
        let normalizedMaxRMS = max(0.0001, maxRMS)
        let volumeChange = (rmsDifference / normalizedMaxRMS) * 100
        
        // Phase analysis
        let preLoopEndValue = preLoopSamples.last ?? 0
        let postLoopStartValue = postLoopSamples.first ?? 0
        let phaseJump = fabsf(preLoopEndValue - postLoopStartValue)
        
        // Zero crossing analysis
        let preLoopEndsAtZeroCrossing = fabsf(preLoopEndValue) < 0.01
        let postLoopStartsAtZeroCrossing = fabsf(postLoopStartValue) < 0.01
        
        // Spectral analysis
        let spectralDifference = calculateSpectralDifference(preLoopSamples, postLoopSamples)
        
        // Harmonic continuity
        let harmonicContinuity = calculateHarmonicContinuity(preLoopSamples, postLoopSamples)
        
        // RMS envelope continuity
        let envelopeContinuity = calculateEnvelopeContinuity(preLoopSamples, postLoopSamples)
        
        // Loop quality assessment
        let overallQualityScore = calculateOverallQuality(
            volumeChange: volumeChange,
            phaseJump: phaseJump,
            spectralDifference: spectralDifference,
            harmonicContinuity: harmonicContinuity,
            envelopeContinuity: envelopeContinuity
        )
        
        let qualityAssessment = qualityAssessmentString(score: overallQualityScore)
        let suggestions = generateSuggestions(
            volumeChange: volumeChange,
            phaseJump: phaseJump,
            spectralDifference: spectralDifference,
            preLoopEndsAtZeroCrossing: preLoopEndsAtZeroCrossing,
            postLoopStartsAtZeroCrossing: postLoopStartsAtZeroCrossing
        )
        
        // Format the results
        return """
        LOOP TRANSITION ANALYSIS
        -----------------------
        Loop Start: \(TimeFormatter.formatPrecise(audioManager.loopStartTime))
        Loop End: \(TimeFormatter.formatPrecise(audioManager.loopEndTime))
        Loop Duration: \(TimeFormatter.formatPrecise(audioManager.loopEndTime - audioManager.loopStartTime))
        
        TECHNICAL METRICS
        -----------------------
        Volume Change: \(String(format: "%.2f", volumeChange))% (\(volumeChange < 5 ? "Good" : "Noticeable"))
        Phase Jump: \(String(format: "%.4f", phaseJump)) (\(phaseJump < 0.1 ? "Good" : "Noticeable"))
        Zero Crossing at End: \(preLoopEndsAtZeroCrossing ? "Yes (Good)" : "No")
        Zero Crossing at Start: \(postLoopStartsAtZeroCrossing ? "Yes (Good)" : "No")
        Spectral Difference: \(String(format: "%.2f", spectralDifference * 100))% (\(spectralDifference < 0.2 ? "Good" : "Noticeable"))
        Harmonic Continuity: \(String(format: "%.2f", harmonicContinuity * 100))% (\(harmonicContinuity > 0.8 ? "Good" : "Poor"))
        Envelope Continuity: \(String(format: "%.2f", envelopeContinuity * 100))% (\(envelopeContinuity > 0.8 ? "Good" : "Poor"))
        
        QUALITY ASSESSMENT
        -----------------------
        Overall Score: \(String(format: "%.1f", overallQualityScore))/10
        Assessment: \(qualityAssessment)
        
        SUGGESTIONS
        -----------------------
        \(suggestions)
        """
    }
    
    // Helper methods
    
    private func extractSamples(from buffer: UnsafePointer<Float>, startFrame: Int, count: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        samples.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress!.update(from: buffer.advanced(by: startFrame), count: count)
        }
        return samples
    }
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        var squaredSum: Float = 0
        vDSP_measqv(samples, 1, &squaredSum, vDSP_Length(samples.count))
        return sqrt(squaredSum / Float(samples.count))
    }
    
    private func calculateSpectralDifference(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // Calculate FFTs
        let preLoopFFT = calculateFFT(preLoopSamples)
        let postLoopFFT = calculateFFT(postLoopSamples)
        
        // Calculate normalized difference between spectra
        var totalDifference: Float = 0
        var totalMagnitude: Float = 0
        
        let minSize = min(preLoopFFT.count, postLoopFFT.count)
        for i in 0..<minSize {
            let diff = fabsf(preLoopFFT[i] - postLoopFFT[i])
            totalDifference += diff
            totalMagnitude += max(preLoopFFT[i], postLoopFFT[i])
        }
        
        return totalMagnitude > 0 ? totalDifference / totalMagnitude : 1.0
    }
    
    private func calculateFFT(_ samples: [Float]) -> [Float] {
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
    
    private func calculateHarmonicContinuity(_ preLoopSamples: [Float], _ postLoopSamples: [Float]) -> Float {
        // Get frequency spectra
        let preLoopFFT = calculateFFT(preLoopSamples)
        let postLoopFFT = calculateFFT(postLoopSamples)
        
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
            preEnvelope.append(calculateRMS(segment))
        }
        
        // Calculate RMS envelope for post-loop
        for i in 0..<postSegmentCount {
            let startIdx = i * segmentSize
            let endIdx = min(startIdx + segmentSize, postLoopSamples.count)
            let segment = Array(postLoopSamples[startIdx..<endIdx])
            postEnvelope.append(calculateRMS(segment))
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
                totalDiff += fabsf(preEnd[i] - postStart[i])
                totalValue += max(preEnd[i], postStart[i])
            }
            
            continuity = totalValue > 0 ? 1.0 - (totalDiff / totalValue) : 0
        }
        
        return continuity
    }
    
    private func calculateOverallQuality(
        volumeChange: Float,
        phaseJump: Float,
        spectralDifference: Float,
        harmonicContinuity: Float,
        envelopeContinuity: Float
    ) -> Float {
        // Weight factors
        let volumeWeight: Float = 0.15
        let phaseWeight: Float = 0.2
        let spectralWeight: Float = 0.25
        let harmonicWeight: Float = 0.25
        let envelopeWeight: Float = 0.15
        
        // Convert each metric to a 0-10 scale
        let volumeScore = 10.0 * (1.0 - min(1.0, volumeChange / 100.0))
        let phaseScore = 10.0 * (1.0 - min(1.0, phaseJump * 5.0))
        let spectralScore = 10.0 * (1.0 - min(1.0, spectralDifference * 2.0))
        let harmonicScore = 10.0 * harmonicContinuity
        let envelopeScore = 10.0 * envelopeContinuity
        
        // Weighted average
        return volumeWeight * volumeScore +
               phaseWeight * phaseScore +
               spectralWeight * spectralScore +
               harmonicWeight * harmonicScore +
               envelopeWeight * envelopeScore
    }
    
    private func qualityAssessmentString(score: Float) -> String {
        switch score {
        case 9.0...10.0:
            return "Perfect - Professional quality loop with no audible transition"
        case 8.0..<9.0:
            return "Excellent - Nearly imperceptible transition, suitable for all uses"
        case 7.0..<8.0:
            return "Very Good - Minor transition artifacts, but casual listeners won't notice"
        case 6.0..<7.0:
            return "Good - Acceptable transition for most uses, slight artifacts"
        case 5.0..<6.0:
            return "Fair - Noticeable transition, but not jarring"
        case 4.0..<5.0:
            return "Mediocre - Obvious transition that may be distracting"
        case 3.0..<4.0:
            return "Poor - Jarring transition with clear discontinuity"
        case 0.0..<3.0:
            return "Very Poor - Severe artifacts, unusable as a seamless loop"
        default:
            return "Invalid score"
        }
    }
    
    private func generateSuggestions(
        volumeChange: Float,
        phaseJump: Float,
        spectralDifference: Float,
        preLoopEndsAtZeroCrossing: Bool,
        postLoopStartsAtZeroCrossing: Bool
    ) -> String {
        var suggestions = [String]()
        
        if volumeChange > 10 {
            suggestions.append("- Try moving the loop points to regions with more similar volume levels")
        }
        
        if phaseJump > 0.2 && (!preLoopEndsAtZeroCrossing || !postLoopStartsAtZeroCrossing) {
            suggestions.append("- Adjust loop points to be at zero crossings to minimize pops/clicks")
        }
        
        if spectralDifference > 0.3 {
            suggestions.append("- Look for points with similar spectral content (similar instrumentation)")
        }
        
        if suggestions.isEmpty {
            return "No specific suggestions - current loop points appear to be working well!"
        } else {
            return suggestions.joined(separator: "\n")
        }
    }
}
