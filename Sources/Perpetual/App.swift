import SwiftUI
import AVFoundation

@main
struct PerpetualApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            FileCommands()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Configure audio for macOS - no AVAudioSession needed
        configureAudioForMacOS()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true  // Quit when last window closes
    }
    
    private func configureAudioForMacOS() {
        // On macOS, we don't need to configure AVAudioSession
        // The audio engine handles everything automatically
        print("Audio configured for macOS")
    }
}

struct FileCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Audio File...") {
                // Handle file opening
                NotificationCenter.default.post(name: .openFile, object: nil)
            }
            .keyboardShortcut("o")
        }
    }
}

extension Notification.Name {
    static let openFile = Notification.Name("openFile")
}
