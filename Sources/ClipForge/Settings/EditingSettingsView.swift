import SwiftUI
import AppKit

struct EditingSettingsView: View {
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen = false
    @AppStorage("playbackEndBehavior") private var playbackEndBehavior = "restart"
    @AppStorage("exportResolution") private var exportResolution = "original"
    @AppStorage("exportFrameRate") private var exportFrameRate = "original"
    @AppStorage("exportFormat") private var exportFormat = "mp4h264"

    var body: some View {
        Form {
            Section("Playback") {
                Toggle("Auto-play when opening a video", isOn: $autoPlayOnOpen)

                Picker("When playback ends", selection: $playbackEndBehavior) {
                    Text("Restart from beginning").tag("restart")
                    Text("Play next in folder").tag("next")
                    Text("Stop").tag("stop")
                }
                .pickerStyle(.menu)
            }

            Section("Export") {
                Picker("Resolution", selection: $exportResolution) {
                    ForEach(ExportResolution.allCases, id: \.rawValue) { r in
                        Text(r.displayName).tag(r.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Picker("Frame rate", selection: $exportFrameRate) {
                    ForEach(ExportFrameRate.allCases, id: \.rawValue) { r in
                        Text(r.displayName).tag(r.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.rawValue) { f in
                        Text(f.displayName).tag(f.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
    }
}
