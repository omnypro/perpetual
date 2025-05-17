import Foundation

/**
 * TimeFormatter
 *
 * A utility struct for formatting time intervals in a consistent way across the app.
 * Provides various time formatting options for different UI contexts.
 */
struct TimeFormatter {
    /// Formats time interval as MM:SS (e.g., 03:45)
    /// Used for general time display in the transport controls
    static func formatStandard(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// Formats time interval as MM:SS.ms (e.g., 03:45.23)
    /// Used for precise time display in loop controls and debug views
    static func formatPrecise(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = timeInterval.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%05.2f", minutes, seconds)
    }
    
    /// Formats time interval as HH:MM:SS for longer audio files
    /// Used when dealing with audio files longer than an hour
    static func formatLong(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    /// Formats a frame count at a given sample rate as a time string
    /// Used when working directly with audio file frames
    static func formatFrameCount(_ frameCount: Int64, sampleRate: Double) -> String {
        let timeInterval = Double(frameCount) / sampleRate
        return formatStandard(timeInterval)
    }
    
    /// Returns appropriate time format based on duration
    /// Automatically selects between standard and long format
    static func formatAuto(_ timeInterval: TimeInterval) -> String {
        if timeInterval >= 3600 {
            return formatLong(timeInterval)
        } else {
            return formatStandard(timeInterval)
        }
    }
}