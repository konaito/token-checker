import Foundation

/// `codex app-server` を介して Codex の rate limit を取得。
/// アプリのライフタイム中 1 プロセスを共有する。失敗時は再起動を試みる。
actor CodexUsageProvider: UsageProvider {
    private let client: CodexAppServerClient
    /// 起動中の app-server がログイン情報を抱えたままにならないよう、
    /// auth.json の更新を検知したらプロセスを立て直す。
    private var lastAuthModifiedAt: Date?

    init(client: CodexAppServerClient = .init()) {
        self.client = client
    }

    func fetch() async throws -> AccountUsage {
        await restartIfAuthChanged()
        do {
            return try await readUsage()
        } catch DomainError.codexProcessExited {
            // 一度落ちていたら再起動して再試行
            await client.stop()
            return try await readUsage()
        }
    }

    func shutdown() async {
        await client.stop()
    }

    private func readUsage() async throws -> AccountUsage {
        try await client.start()
        let dto = try await client.readRateLimits()
        let account = try await client.readAccountName()
        return AccountUsage(
            email: account,
            usage: ServiceUsage(
                fiveHour: dto.fiveHourRateLimit(),
                weekly: dto.weeklyRateLimit(),
                weeklySonnet: nil
            ),
            fetchedAt: Date()
        )
    }

    private func restartIfAuthChanged() async {
        let modifiedAt = Self.authFileModifiedAt()
        defer { lastAuthModifiedAt = modifiedAt }
        guard let lastAuthModifiedAt, modifiedAt != lastAuthModifiedAt else { return }
        await client.stop()
    }

    private static func authFileModifiedAt() -> Date? {
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"]
            ?? "\(NSHomeDirectory())/.codex"
        let attributes = try? FileManager.default.attributesOfItem(atPath: "\(home)/auth.json")
        return attributes?[.modificationDate] as? Date
    }
}
