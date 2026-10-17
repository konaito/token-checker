import SwiftUI
import AppKit

struct UsagePopoverView: View {
    @Bindable var viewModel: UsageViewModel
    @Bindable var languageStore: LanguageStore
    @ObservedObject var launchAtLogin: LaunchAtLoginStore

    private var language: AppLanguage { languageStore.selectedLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            serviceSection(.claude)
            Divider()
            serviceSection(.codex)

            Divider()
            settingsBlock
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("Token Checker")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
    }

    private func serviceSection(_ brand: ServiceBrand) -> some View {
        ServiceSectionView(
            brand: brand,
            result: viewModel.snapshot.result(for: brand),
            language: language,
            loginAction: { viewModel.openLogin(brand) }
        )
    }

    private var settingsBlock: some View {
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

    private var footer: some View {
        HStack {
            if viewModel.snapshot.fetchedAt > .distantPast {
                Text(L10n.format(
                    "footer.updated_at",
                    language: language,
                    L10n.shortTime(viewModel.snapshot.fetchedAt, language: language)
                ))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                Task { await viewModel.refresh() }
            } label: {
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("footer.refresh_now", language: language))

            Button(L10n.tr("footer.quit", language: language)) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }
}
