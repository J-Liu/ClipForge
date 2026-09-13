// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright © 2026 Jia Liu

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var localization = LocalizationManager.shared
    @AppStorage("quitAfterLastWindowClosed") private var quitAfterLastWindowClosed = false
    @AppStorage("dontHideWindow") private var dontHideWindow = false
    @AppStorage("countdownSeconds") private var countdownSeconds = 3

    var body: some View {
        Form {
            Section {
                Picker(L("settings.general.language"), selection: $localization.currentLanguage) {
                    ForEach(Language.allCases, id: \.self) { lang in
                        Text(lang.nativeName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(L("settings.general.quitAfterLastWindow"),
                       isOn: $quitAfterLastWindowClosed)
            }

            Section {
                Toggle(L("settings.general.dontHideWindow"),
                       isOn: $dontHideWindow)
            }

            Section {
                Picker(L("settings.general.countdown"), selection: $countdownSeconds) {
                    Text(L("settings.general.countdown.none")).tag(0)
                    Text(L("settings.general.countdown.3seconds")).tag(3)
                    Text(L("settings.general.countdown.5seconds")).tag(5)
                }
                .pickerStyle(.menu)
            }
        }
        .formStyle(.grouped)
    }
}
