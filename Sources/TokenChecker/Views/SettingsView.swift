import SwiftUI

/// ポップオーバーの歯車ボタンから開く設定シート。
struct SettingsView: View {
    @Bindable var viewModel: UsageViewModel
    @Bindable var languageStore: LanguageStore
    @ObservedObject var launchAtLogin: LaunchAtLoginStore
    @Environment(\.dismiss) private var dismiss

    private var language: AppLanguage { languageStore.selectedLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("settings.title", language: language))
                .font(.system(size: 14, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                settingRow("settings.refresh_interval") {
                    Picker("", selection: $viewModel.pollingInterval) {
                        ForEach(PollingInterval.allCases) { interval in
                            Text(interval.label(language: language)).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                settingRow("settings.language") {
                    Picker("", selection: $languageStore.selectedLanguage) {
                        ForEach(AppLanguage.allCases) { option in
                            Text(L10n.tr(option.displayKey, language: option)).tag(option)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                settingRow("settings.launch_at_login") {
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { _ in launchAtLogin.toggle() }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
            }

            HStack {
                Spacer()
                Button(L10n.tr("settings.done", language: language)) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear { launchAtLogin.refresh() }
    }

    /// 左にラベル、右に操作部品を置く設定行。
    private func settingRow<Control: View>(
        _ labelKey: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack {
            Text(L10n.tr(labelKey, language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            control()
        }
    }
}
