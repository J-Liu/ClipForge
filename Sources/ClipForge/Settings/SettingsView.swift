// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label(L("settings.tab.general"), systemImage: "gear") }

            RecordingSettingsView()
                .tabItem { Label(L("settings.tab.recording"), systemImage: "record.circle") }

            EditingSettingsView()
                .tabItem { Label(L("settings.tab.editing"), systemImage: "scissors") }
        }
        .padding(20)
        .frame(width: 520, height: 420)
    }
}
