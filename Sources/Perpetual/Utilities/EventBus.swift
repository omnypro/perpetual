import Foundation
import Combine

/**
 * EventBus
 *
 * A centralized event publishing system using Combine to replace NotificationCenter.
 * Provides type-safe event handling with a publisher-subscriber pattern.
 */
class EventBus {
    // Singleton instance
    static let shared = EventBus()
    
    // MARK: - Event Types
    
    /// Events that can be published throughout the app
    enum Event {
        /// Request to open a file (no associated data)
        case openFile
        
        /// Request to seek to a specific time in audio playback
        case seekToTime(TimeInterval)
        
        /// Notification that loop points have changed (no associated data)
        case loopPointsChanged
        
        /// Error occurred during audio processing
        case audioError(Error)
    }
    
    // MARK: - Publishers
    
    /// The main event publisher
    private let eventSubject = PassthroughSubject<Event, Never>()
    
    /// Public publisher for subscribing to events
    var publisher: AnyPublisher<Event, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher filtered for open file events
    var openFilePublisher: AnyPublisher<Void, Never> {
        eventSubject
            .filter { event in
                if case .openFile = event {
                    return true
                }
                return false
            }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Publisher filtered for seek time events with the time value
    var seekToTimePublisher: AnyPublisher<TimeInterval, Never> {
        eventSubject
            .compactMap { event in
                if case .seekToTime(let time) = event {
                    return time
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    /// Publisher filtered for loop points changed events
    var loopPointsChangedPublisher: AnyPublisher<Void, Never> {
        eventSubject
            .filter { event in
                if case .loopPointsChanged = event {
                    return true
                }
                return false
            }
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    /// Publisher filtered for audio error events
    var audioErrorPublisher: AnyPublisher<Error, Never> {
        eventSubject
            .compactMap { event in
                if case .audioError(let error) = event {
                    return error
                }
                return nil
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Public Methods
    
    /// Publishes an event to all subscribers
    func publish(_ event: Event) {
        eventSubject.send(event)
    }
    
    // MARK: - Convenience Methods
    
    /// Publishes an open file event
    func publishOpenFile() {
        publish(.openFile)
    }
    
    /// Publishes a seek to time event
    func publishSeekToTime(_ time: TimeInterval) {
        publish(.seekToTime(time))
    }
    
    /// Publishes a loop points changed event
    func publishLoopPointsChanged() {
        publish(.loopPointsChanged)
    }
    
    /// Publishes an audio error event
    func publishAudioError(_ error: Error) {
        publish(.audioError(error))
    }
}
