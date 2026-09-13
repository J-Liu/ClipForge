import SwiftUI
import AppKit

struct RecordingSettingsView: View {
    @AppStorage("recordingMode") private var recordingMode = "fullScreen"
    @AppStorage("recordingButtonStyle") private var recordingButtonStyle = "modePicker"
    @AppStorage("captureSystemAudio") private var captureSystemAudio = true
    @AppStorage("captureMicrophone") private var captureMicrophone = true
    @AppStorage("frameRate") private var frameRate = 30
    @AppStorage("videoCodec") private var videoCodec = "h264"
    @AppStorage("microphoneGain") private var microphoneGain = 1.0

    @State private var outputPath: String = Settings.shared.recordingOutputDirectory.path

    var body: some View {
        Form {
            Section("Default Mode") {
                Picker("Recording mode", selection: $recordingMode) {
                    Text("Full Screen").tag("fullScreen")
                    Text("Window").tag("window")
                    Text("Region").tag("region")
                }
                .pickerStyle(.menu)

                Picker("Button style", selection: $recordingButtonStyle) {
                    Text("Pick mode, then press").tag("modePicker")
                    Text("Menu items start directly").tag("directAction")
                }
                .pickerStyle(.menu)
            }

            Section("Audio") {
                Toggle("Capture system audio", isOn: $captureSystemAudio)
                Toggle("Capture microphone", isOn: $captureMicrophone)
                VStack(alignment: .leading) {
                    HStack {
                        Text("Microphone gain")
                        Spacer()
                        Text(String(format: "%.1f×", microphoneGain))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $microphoneGain, in: 0.5...30.0)
                }
            }

            Section("Video") {
                Picker("Frame rate", selection: $frameRate) {
                    Text("30 fps").tag(30)
                    Text("60 fps").tag(60)
                }
                .pickerStyle(.menu)

                Picker("Codec", selection: $videoCodec) {
                    Text("H.264").tag("h264")
                    Text("H.265 / HEVC").tag("h265")
                }
                .pickerStyle(.menu)
            }

            Section("Output Folder") {
                HStack {
                    Text(outputPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.allowsMultipleSelection = false
                        panel.directoryURL = Settings.shared.recordingOutputDirectory
                        if panel.runModal() == .OK, let url = panel.url {
                            Settings.shared.recordingOutputDirectory = url
                            outputPath = url.path
                        }
                    }
                    Button("Reveal") {
                        NSWorkspace.shared.selectFile(nil,
                            inFileViewerRootedAtPath: Settings.shared.recordingOutputDirectory.path)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
