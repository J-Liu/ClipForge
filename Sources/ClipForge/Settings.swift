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
        static let captureSystemAudio = "captureSystemAudio"
        static let captureMicrophone = "captureMicrophone"
        static let frameRate = "frameRate"
        static let videoCodec = "videoCodec"
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

    var captureSystemAudio: Bool {
        get {
            if defaults.object(forKey: Key.captureSystemAudio) == nil { return true }
            return defaults.bool(forKey: Key.captureSystemAudio)
        }
        set { defaults.set(newValue, forKey: Key.captureSystemAudio) }
    }

    var captureMicrophone: Bool {
        get {
            if defaults.object(forKey: Key.captureMicrophone) == nil { return true }
            return defaults.bool(forKey: Key.captureMicrophone)
        }
        set { defaults.set(newValue, forKey: Key.captureMicrophone) }
    }

    var frameRate: Int {
        get {
            let v = defaults.integer(forKey: Key.frameRate)
            return v > 0 ? v : 30
        }
        set { defaults.set(newValue, forKey: Key.frameRate) }
    }

    var videoCodec: String {
        get { defaults.string(forKey: Key.videoCodec) ?? "h264" }
        set { defaults.set(newValue, forKey: Key.videoCodec) }
    }

    var autoPlayOnOpen: Bool {
        get {
            if defaults.object(forKey: "autoPlayOnOpen") == nil { return false }
            return defaults.bool(forKey: "autoPlayOnOpen")
        }
        set { defaults.set(newValue, forKey: "autoPlayOnOpen") }
    }

    var volume: Float {
        get {
            if defaults.object(forKey: "volume") == nil { return 0.5 }
            return defaults.float(forKey: "volume")
        }
        set { defaults.set(newValue, forKey: "volume") }
    }

    var isMuted: Bool {
        get { defaults.bool(forKey: "isMuted") }
        set { defaults.set(newValue, forKey: "isMuted") }
    }

    var recordingOutputDirectory: URL {
        get {
            if let path = defaults.string(forKey: "recordingOutputDirectory") {
                return URL(fileURLWithPath: path)
            }
            // Default: ~/Movies/ClipForge/
            let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            return movies.appendingPathComponent("ClipForge", isDirectory: true)
        }
        set {
            defaults.set(newValue.path, forKey: "recordingOutputDirectory")
        }
    }
}
