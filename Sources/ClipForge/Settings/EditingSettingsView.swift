// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

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
            Section(L("settings.editing.playback")) {
                Toggle(L("settings.editing.autoPlay"), isOn: $autoPlayOnOpen)

                Picker(L("settings.editing.playbackEnd"), selection: $playbackEndBehavior) {
                    Text(L("settings.editing.playbackEnd.restart")).tag("restart")
                    Text(L("settings.editing.playbackEnd.next")).tag("next")
                    Text(L("settings.editing.playbackEnd.stop")).tag("stop")
                }
                .pickerStyle(.menu)
            }

            Section(L("settings.editing.export")) {
                Picker(L("settings.editing.resolution"), selection: $exportResolution) {
                    ForEach(ExportResolution.allCases, id: \.rawValue) { r in
                        Text(r.localizedName).tag(r.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Picker(L("settings.editing.frameRate"), selection: $exportFrameRate) {
                    ForEach(ExportFrameRate.allCases, id: \.rawValue) { r in
                        Text(r.localizedName).tag(r.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Picker(L("settings.editing.format"), selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.rawValue) { f in
                        Text(f.localizedName).tag(f.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
    }
}
