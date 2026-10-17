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
    private let store: AccountUsageStore

    /// 表示用の使用状況。取得に失敗しても、覚えているアカウントの値はそのまま残す。
    var snapshot: UsageSnapshot
    var isLoading: Bool = false
    var pollingInterval: PollingInterval {
        didSet { persistInterval() }
    }

    init(
        claudeProvider: UsageProvider = ClaudeUsageProvider(),
        codexProvider: UsageProvider = CodexUsageProvider(),
        store: AccountUsageStore = AccountUsageStore()
    ) {
        self.claudeProvider = claudeProvider
        self.codexProvider = codexProvider
        self.store = store
        // 起動直後は覚えている値を出しておき、最初の取得完了で更新する。
        self.snapshot = UsageSnapshot(
            claude: ServiceState(accounts: store.load(.claude)),
            codex: ServiceState(accounts: store.load(.codex)),
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
        snapshot = UsageSnapshot(
            claude: apply(c, to: snapshot.claude, for: .claude),
            codex: apply(x, to: snapshot.codex, for: .codex),
            fetchedAt: Date()
        )
    }

    /// 成功したらそのアカウントを先頭に上書きして保存する。失敗したら覚えている値は残してエラーだけ記録する。
    private func apply(
        _ result: Result<AccountUsage, DomainError>,
        to state: ServiceState,
        for brand: ServiceBrand
    ) -> ServiceState {
        switch result {
        case .success(let account):
            let accounts = [account] + state.accounts.filter { $0.email != account.email }
            store.save(accounts, for: brand)
            return ServiceState(accounts: accounts, error: nil)
        case .failure(let error):
            return ServiceState(accounts: state.accounts, error: error)
        }
    }

    private func fetch(from provider: UsageProvider, logger: Logger) async -> Result<AccountUsage, DomainError> {
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
