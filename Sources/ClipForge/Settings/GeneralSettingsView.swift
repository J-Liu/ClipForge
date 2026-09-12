import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("quitAfterLastWindowClosed") private var quitAfterLastWindowClosed = false
    @AppStorage("dontHideWindow") private var dontHideWindow = false
    @AppStorage("countdownSeconds") private var countdownSeconds = 3

    var body: some View {
        Form {
            Section {
                Toggle("Quit after closing the last window",
                       isOn: $quitAfterLastWindowClosed)
            }

            Section {
                Toggle("Don't hide the main window during recording",
                       isOn: $dontHideWindow)
            }

            Section {
                Picker("Countdown before recording", selection: $countdownSeconds) {
                    Text("None").tag(0)
                    Text("3 seconds").tag(3)
                    Text("5 seconds").tag(5)
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
    }
}

