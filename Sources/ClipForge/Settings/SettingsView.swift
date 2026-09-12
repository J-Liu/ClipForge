import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }

            RecordingSettingsView()
                .tabItem { Label("Recording", systemImage: "record.circle") }

            EditingSettingsView()
                .tabItem { Label("Editing", systemImage: "scissors") }
        }
        .padding(20)
        .frame(width: 520, height: 420)
    }
}

