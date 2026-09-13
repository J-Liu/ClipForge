// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import SwiftUI

struct ExportOptionsView: View {
    @AppStorage("exportResolution") private var resolution = "original"
    @AppStorage("exportFrameRate") private var frameRate = "original"
    @AppStorage("exportFormat") private var format = "mp4h264"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text(L("export.resolution"))
                    Picker("", selection: $resolution) {
                        ForEach(ExportResolution.allCases, id: \.rawValue) { r in
                            Text(r.localizedName).tag(r.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                GridRow {
                    Text(L("export.frameRate"))
                    Picker("", selection: $frameRate) {
                        ForEach(ExportFrameRate.allCases, id: \.rawValue) { r in
                            Text(r.localizedName).tag(r.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                GridRow {
                    Text(L("export.format"))
                    Picker("", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.rawValue) { f in
                            Text(f.localizedName).tag(f.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
