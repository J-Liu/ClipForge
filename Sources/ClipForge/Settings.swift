import Foundation

/// The mode the record button is currently set to.
enum RecordingMode: String {
    case fullScreen
    case window
    case region
}

/// How the record button behaves: A = pick mode then press, B = menu items start directly.
enum RecordingButtonStyle: String {
    case modePicker
    case directAction
}

/// App-wide settings backed by UserDefaults.
class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let recordingMode = "recordingMode"
        static let recordingButtonStyle = "recordingButtonStyle"
        static let dontHideWindow = "dontHideWindow"
        static let countdownSeconds = "countdownSeconds"
        static let quitAfterLastWindowClosed = "quitAfterLastWindowClosed"
    }

    var recordingMode: RecordingMode {
        get {
            let raw = defaults.string(forKey: Key.recordingMode) ?? RecordingMode.fullScreen.rawValue
            return RecordingMode(rawValue: raw) ?? .fullScreen
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.recordingMode)
        }
    }

    var recordingButtonStyle: RecordingButtonStyle {
        get {
            let raw = defaults.string(forKey: Key.recordingButtonStyle) ?? RecordingButtonStyle.modePicker.rawValue
            return RecordingButtonStyle(rawValue: raw) ?? .modePicker
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.recordingButtonStyle)
        }
    }

    var dontHideWindow: Bool {
        get { defaults.bool(forKey: Key.dontHideWindow) }
        set { defaults.set(newValue, forKey: Key.dontHideWindow) }
    }

    var countdownSeconds: Int {
        get {
            let v = defaults.integer(forKey: Key.countdownSeconds)
            return v > 0 ? v : 3   // default 3
        }
        set {
            defaults.set(newValue, forKey: Key.countdownSeconds)
        }
    }

    var quitAfterLastWindowClosed: Bool {
        get { defaults.bool(forKey: Key.quitAfterLastWindowClosed) }
        set { defaults.set(newValue, forKey: Key.quitAfterLastWindowClosed) }
    }
}
