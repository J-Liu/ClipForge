// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

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
    @AppStorage("recordingFormat") private var recordingFormat = "mp4"
    @AppStorage("showsCursor") private var showsCursor = true
    @AppStorage("dontHideWindow") private var dontHideWindow = false

    @State private var outputPath: String = Settings.shared.recordingOutputDirectory.path

    var body: some View {
        Form {
            Section(L("settings.recording.defaultMode")) {
                Picker(L("settings.recording.mode"), selection: $recordingMode) {
                    Text(L("settings.recording.mode.fullScreen")).tag("fullScreen")
                    Text(L("settings.recording.mode.window")).tag("window")
                    Text(L("settings.recording.mode.region")).tag("region")
                }
                .pickerStyle(.menu)

                Picker(L("settings.recording.buttonStyle"), selection: $recordingButtonStyle) {
                    Text(L("settings.recording.buttonStyle.modePicker")).tag("modePicker")
                    Text(L("settings.recording.buttonStyle.directAction")).tag("directAction")
                }
                .pickerStyle(.menu)
            }

            Section(L("settings.recording.audio")) {
                Toggle(L("settings.recording.captureSystemAudio"), isOn: $captureSystemAudio)
                Toggle(L("settings.recording.captureMicrophone"), isOn: $captureMicrophone)

                VStack(alignment: .leading) {
                    HStack {
                        Text(L("settings.recording.microphoneGain"))
                        Spacer()
                        Text(String(format: "%.1f×", microphoneGain))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $microphoneGain, in: 0.5...30.0)
                }
                .disabled(!captureMicrophone)
            }

            Section(L("settings.recording.video")) {
                Picker(L("settings.recording.frameRate"), selection: $frameRate) {
                    Text(L("settings.recording.30fps")).tag(30)
                    Text(L("settings.recording.60fps")).tag(60)
                }
                .pickerStyle(.menu)

                Picker(L("settings.recording.codec"), selection: $videoCodec) {
                    Text(L("settings.recording.h264")).tag("h264")
                    Text(L("settings.recording.h265")).tag("h265")
                }
                .pickerStyle(.menu)

                Picker(L("settings.recording.format"), selection: $recordingFormat) {
                    Text(L("settings.recording.mp4")).tag("mp4")
                    Text(L("settings.recording.mov")).tag("mov")
                }
                .pickerStyle(.menu)

                Toggle(L("settings.recording.showCursor"), isOn: $showsCursor)
            }

            Section(L("settings.recording.window")) {
                Toggle(L("settings.recording.dontHideMainWindow"), isOn: $dontHideWindow)
            }

            Section(L("settings.recording.outputFolder")) {
                HStack {
                    Text(outputPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("settings.recording.choose")) {
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
                    Button(L("settings.recording.reveal")) {
                        NSWorkspace.shared.selectFile(nil,
                            inFileViewerRootedAtPath: Settings.shared.recordingOutputDirectory.path)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
