import SwiftUI

/// Claude / Codex 1 サービスぶんの詳細セクション。
struct ServiceSectionView: View {
    let brand: ServiceBrand
    let state: ServiceState
    let language: AppLanguage
    let loginAction: () -> Void
    /// 切り替え中のアカウント。その行にスピナーを出し、ほかの行は押せなくする。
    let switchingEmail: String?
    let switchError: DomainError?
    let switchAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: brand.symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(brand.title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    loginAction()
                } label: {
                    Image(systemName: "person.badge.key")
                }
                .buttonStyle(.borderless)
                .help(L10n.format("service.login.help", language: language, brand.title))
            }

            if let active = state.active {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                    Text(active.email)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundStyle(.secondary)
                usageBlock(active.usage)
                if state.accounts.count > 1 {
                    Divider().opacity(0.5)
                    ForEach(state.accounts.dropFirst()) { account in
                        inactiveRow(account)
                    }
                }
                if let switchError {
                    Text(switchError.localizedDescription(language: language))
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if let error = state.error {
                errorBlock(error)
            } else {
                Text(L10n.tr("status.loading", language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 過去にアクティブだったアカウント。最後に取得できた値を 1 行で出し、クリックで切り替える。
    private func inactiveRow(_ account: AccountUsage) -> some View {
        Button {
            switchAction(account.email)
        } label: {
            HStack {
                Text(account.email)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if switchingEmail == account.email {
                    ProgressView().controlSize(.mini)
                } else {
                    Text(summary(account.usage))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(switchingEmail != nil)
        .help(L10n.tr("account.switch_hint", language: language) + "\n"
              + L10n.format("account.fetched_at", language: language, L10n.shortDateTime(account.fetchedAt, language: language)))
    }

    /// 「5時間 28% · 週次 26%」。リセット時刻を過ぎた枠は古い値を出さず「リセット済」にする。
    private func summary(_ usage: ServiceUsage) -> String {
        let windows: [(String, RateLimit?)] = [
            (L10n.tr("window.five_hour", language: language), usage.fiveHour),
            (L10n.tr("window.weekly", language: language), usage.weekly),
        ]
        return windows.map { label, limit in
            guard let limit else { return "\(label) –" }
            if limit.resetsAt <= Date() {
                return "\(label) \(L10n.tr("account.reset_done", language: language))"
            }
            return "\(label) \(limit.percent)%"
        }
        .joined(separator: " · ")
    }

    @ViewBuilder
    private func usageBlock(_ usage: ServiceUsage) -> some View {
        if let five = usage.fiveHour {
            limitRow(label: L10n.tr("window.five_hour", language: language), limit: five)
        } else {
            Text(L10n.tr("window.five_hour.no_data", language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }

        if let weekly = usage.weekly {
            secondaryRow(label: L10n.tr("window.weekly", language: language), limit: weekly)
        }
        if let sonnet = usage.weeklySonnet {
            secondaryRow(label: L10n.tr("window.weekly_sonnet", language: language), limit: sonnet)
        }
    }

    private func limitRow(label: String, limit: RateLimit) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(limit.percent)%")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.usage(limit.utilization))
            Text("/ \(label)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(resetLabel(limit.resetsAt))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private func secondaryRow(label: String, limit: RateLimit) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(limit.percent)%")
                .font(.system(size: 11))
                .foregroundStyle(Color.usage(limit.utilization))
        }
    }

    private func errorBlock(_ err: DomainError) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(L10n.tr("error.fetch_failed", language: language))
                    .font(.system(size: 12, weight: .medium))
            }
            Text(err.localizedDescription(language: language))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func resetLabel(_ date: Date) -> String {
        let now = Date()
        if date <= now { return L10n.tr("reset.soon", language: language) }
        let f = DateComponentsFormatter()
        var calendar = Calendar.current
        calendar.locale = language.locale
        f.calendar = calendar
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        let rel = f.string(from: now, to: date) ?? "—"
        let absolute = L10n.shortTime(date, language: language)
        return L10n.format("reset.remaining", language: language, rel, absolute)
    }
}
