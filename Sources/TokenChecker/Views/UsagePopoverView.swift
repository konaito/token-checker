import SwiftUI
import AppKit

struct UsagePopoverView: View {
    @Bindable var viewModel: UsageViewModel
    @Bindable var languageStore: LanguageStore
    @ObservedObject var launchAtLogin: LaunchAtLoginStore
    @State private var isShowingSettings = false

    private var language: AppLanguage { languageStore.selectedLanguage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            serviceSection(.claude)
            Divider()
            serviceSection(.codex)

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                viewModel: viewModel,
                languageStore: languageStore,
                launchAtLogin: launchAtLogin
            )
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

    /// 「更新: 5:13」。取得に失敗したサービスがあれば「(更新エラー)」を付け、詳細はツールチップに出す。
    private var updatedAtLabel: some View {
        let time = L10n.shortTime(viewModel.snapshot.fetchedAt, language: language)
        var text = L10n.format("footer.updated_at", language: language, time)
        let errors = [ServiceBrand.claude, .codex].compactMap { brand in
            viewModel.refreshErrors[brand].map { "\(brand.title): \($0.localizedDescription(language: language))" }
        }
        if !errors.isEmpty {
            text += " " + L10n.tr("footer.update_error", language: language)
        }
        return Text(text)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .help(errors.joined(separator: "\n"))
    }

    private var footer: some View {
        HStack {
            if viewModel.snapshot.fetchedAt > .distantPast {
                updatedAtLabel
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

            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help(L10n.tr("settings.title", language: language))

            Button(L10n.tr("footer.quit", language: language)) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
    }
}
