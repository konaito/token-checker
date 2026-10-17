import Foundation

/// 1 つのレート制限ウィンドウ。
struct RateLimit: Codable, Equatable, Sendable {
    /// 0.0 〜 1.0+。1.0 で 100% 使用。たまに 1.0 を超えることがある（API 側仕様）。
    let utilization: Double
    /// ウィンドウがリセットされる時刻。
    let resetsAt: Date

    var percent: Int { Int((utilization * 100).rounded()) }
}

/// 1 サービス（Claude / Codex）の使用状況。
struct ServiceUsage: Codable, Equatable, Sendable {
    let fiveHour: RateLimit?
    let weekly: RateLimit?
    /// Claude のみ。Sonnet 専用 7d ウィンドウ。
    let weeklySonnet: RateLimit?
}

/// あるアカウントがアクティブだったときに取得できた最新の使用状況。
struct AccountUsage: Codable, Equatable, Identifiable, Sendable {
    /// アカウントの識別名。通常はメールアドレス。
    let email: String
    let usage: ServiceUsage
    let fetchedAt: Date

    var id: String { email }
}

/// 1 サービスぶんの表示状態。
struct ServiceState: Equatable, Sendable {
    /// これまでにアクティブだったアカウント。先頭が最後に取得できた (= 現在アクティブな) アカウント。
    var accounts: [AccountUsage] = []
    /// 直近の取得エラー。成功したら nil。
    var error: DomainError?

    var active: AccountUsage? { accounts.first }
}

/// 取得結果。片方が失敗しても他方は表示できるよう個別に保持。
struct UsageSnapshot: Equatable, Sendable {
    var claude: ServiceState
    var codex: ServiceState
    var fetchedAt: Date

    func state(for brand: ServiceBrand) -> ServiceState {
        switch brand {
        case .claude: return claude
        case .codex:  return codex
        }
    }
}
