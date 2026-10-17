import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class UsageViewModel {
    // applicationWillTerminate から MainActor を経由せず shutdown を呼べるよう
    // nonisolated 化する。providers 自体は immutable なので Sendable 違反は起きない。
    private nonisolated let claudeProvider: UsageProvider
    private nonisolated let codexProvider: UsageProvider
    private let cache: UsageCache

    /// 表示用の使用状況。取得に失敗したサービスは前回取得できた値で埋める。
    var snapshot: UsageSnapshot
    /// 直近の更新で取得に失敗したサービスとそのエラー。
    var refreshErrors: [ServiceBrand: DomainError] = [:]
    var isLoading: Bool = false
    var pollingInterval: PollingInterval {
        didSet { persistInterval() }
    }

    init(
        claudeProvider: UsageProvider = ClaudeUsageProvider(),
        codexProvider: UsageProvider = CodexUsageProvider(),
        cache: UsageCache = UsageCache()
    ) {
        self.claudeProvider = claudeProvider
        self.codexProvider = codexProvider
        self.cache = cache
        // 起動直後は前回の値を出しておき、最初の取得完了で置き換える。
        self.snapshot = UsageSnapshot(
            claude: cache.load(.claude).map { .success($0) },
            codex: cache.load(.codex).map { .success($0) },
            fetchedAt: .distantPast
        )
        self.pollingInterval = Self.loadPersistedInterval()
    }

    /// `task(id: pollingInterval)` から駆動するメインループ。
    func runPollingLoop() async {
        await refresh()
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: UInt64(pollingInterval.seconds * 1_000_000_000))
            } catch {
                return
            }
            await refresh()
        }
    }

    /// アプリ終了時に子プロセスや永続接続を解放するためのクロージャを返す。
    ///
    /// `@MainActor` final class である自身を `@Sendable` クロージャがキャプチャできないため
    /// (Swift 6 strict-concurrency でエラー)、Sendable な providers だけを閉じ込めて公開する。
    /// AppDelegate.applicationWillTerminate からは MainActor を経由せず呼ばれる。
    nonisolated func makeShutdownHandler() -> @Sendable () async -> Void {
        let claude = claudeProvider
        let codex = codexProvider
        return {
            await claude.shutdown()
            await codex.shutdown()
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        async let claude = fetch(from: claudeProvider, logger: .claude)
        async let codex = fetch(from: codexProvider, logger: .codex)

        let (c, x) = await (claude, codex)
        var errors: [ServiceBrand: DomainError] = [:]
        snapshot = UsageSnapshot(
            claude: applyCache(c, for: .claude, errors: &errors),
            codex: applyCache(x, for: .codex, errors: &errors),
            fetchedAt: Date()
        )
        refreshErrors = errors
    }

    /// 成功したら保存し、失敗したら前回の値があればそれを返す。
    private func applyCache(
        _ result: Result<ServiceUsage, DomainError>,
        for brand: ServiceBrand,
        errors: inout [ServiceBrand: DomainError]
    ) -> Result<ServiceUsage, DomainError> {
        switch result {
        case .success(let usage):
            cache.save(usage, for: brand)
            return result
        case .failure(let error):
            errors[brand] = error
            return cache.load(brand).map { .success($0) } ?? result
        }
    }

    private func fetch(from provider: UsageProvider, logger: Logger) async -> Result<ServiceUsage, DomainError> {
        do {
            return .success(try await provider.fetch())
        } catch let err as DomainError {
            logger.error("fetch failed: \(err.localizedDescription)")
            return .failure(err)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    // MARK: - ログインボタン

    /// ターミナルを開いて `brand.loginCommand` を実行する。
    func openLogin(_ brand: ServiceBrand) {
        let script = """
        tell application "Terminal"
            activate
            do script "\(brand.loginCommand)"
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        do { try process.run() } catch {
            Logger.ui.error("login spawn failed: \(error.localizedDescription)")
        }
    }

    // MARK: - 永続化

    private static let intervalKey = "pollingInterval"

    private static func loadPersistedInterval() -> PollingInterval {
        let raw = UserDefaults.standard.integer(forKey: intervalKey)
        return PollingInterval(rawValue: raw) ?? .default
    }

    private func persistInterval() {
        UserDefaults.standard.set(pollingInterval.rawValue, forKey: Self.intervalKey)
    }
}
