import SwiftUI

/// Claude / Codex 1 サービスぶんの詳細セクション。
struct ServiceSectionView: View {
    let brand: ServiceBrand
    let result: Result<ServiceUsage, DomainError>?
    let language: AppLanguage
    let loginAction: () -> Void

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

            switch result {
            case .none:
                Text(L10n.tr("status.loading", language: language))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            case .some(.success(let usage)):
                usageBlock(usage)
            case .some(.failure(let err)):
                errorBlock(err)
            }
        }
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
