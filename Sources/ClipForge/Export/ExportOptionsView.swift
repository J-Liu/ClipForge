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
                    Text("Resolution")
                    Picker("", selection: $resolution) {
                        ForEach(ExportResolution.allCases, id: \.rawValue) { r in
                            Text(r.displayName).tag(r.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                GridRow {
                    Text("Frame rate")
                    Picker("", selection: $frameRate) {
                        ForEach(ExportFrameRate.allCases, id: \.rawValue) { r in
                            Text(r.displayName).tag(r.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
                GridRow {
                    Text("Format")
                    Picker("", selection: $format) {
                        ForEach(ExportFormat.allCases, id: \.rawValue) { f in
                            Text(f.displayName).tag(f.rawValue)
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

