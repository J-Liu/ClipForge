import SwiftUI

struct EditingSettingsView: View {
    @AppStorage("autoPlayOnOpen") private var autoPlayOnOpen = true
    @AppStorage("playbackEndBehavior") private var playbackEndBehavior = "restart"
    @AppStorage("exportResolution") private var exportResolution = "original"
    @AppStorage("exportFrameRate") private var exportFrameRate = "original"

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
                    Text("Original").tag("original")
                    Text("1080p").tag("1080p")
                    Text("720p").tag("720p")
                }
                .pickerStyle(.menu)

                Picker("Frame rate", selection: $exportFrameRate) {
                    Text("Original").tag("original")
                    Text("30 fps").tag("30")
                    Text("60 fps").tag("60")
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
    }
}

