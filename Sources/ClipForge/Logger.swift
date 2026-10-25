// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import Foundation

class Logger {
    static let shared = Logger()

    private var logFileURL: URL?
    private var fileHandle: FileHandle?
    private let lock = NSLock()

    var isEnabled: Bool {
        get { Settings.shared.logEnabled }
        set { Settings.shared.logEnabled = newValue }
    }

    var logFilePath: String? {
        return logFileURL?.path
    }

    private init() {
        setupLogFile()
    }

    private func setupLogFile() {
        let logsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipForge/Logs", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            logFileURL = logsDirectory.appendingPathComponent("ClipForge.log")

            // Create empty file
            FileManager.default.createFile(atPath: logFileURL!.path, contents: nil, attributes: nil)
        } catch {
            print("Failed to create log directory: \(error)")
        }
    }

    func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] [\(fileName):\(line)] \(message)\n"

        if isEnabled, let handle = fileHandle ?? openFileHandle() {
            lock.lock()
            defer { lock.unlock() }

            if let data = logMessage.data(using: .utf8) {
                handle.write(data)
            }
        }

        // Always print to console in debug
        #if DEBUG
        print(logMessage, terminator: "")
        #endif
    }

    private func openFileHandle() -> FileHandle? {
        guard let url = logFileURL else { return nil }
        do {
            fileHandle = try FileHandle(forWritingTo: url)
            try fileHandle?.seekToEnd()
            return fileHandle
        } catch {
            return nil
        }
    }

    func flush() {
        lock.lock()
        defer { lock.unlock() }
        fileHandle?.synchronizeFile()
    }

    deinit {
        try? fileHandle?.close()
    }
}

// Convenience function
func Log(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.log(message, file: file, function: function, line: line)
}
