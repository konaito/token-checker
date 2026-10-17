import Foundation

/// Keychain → Anthropic OAuth usage / profile エンドポイント。
actor ClaudeUsageProvider: UsageProvider {
    private let keychain: KeychainTokenSource
    private let api: AnthropicUsageAPIClient
    /// profile を毎回引かないよう、直近のトークンとその持ち主を覚えておく。
    /// アカウント切り替えやトークン更新でトークンが変われば引き直す。
    private var cachedOwner: (token: String, email: String)?

    init(keychain: KeychainTokenSource = .init(), api: AnthropicUsageAPIClient = .init()) {
        self.keychain = keychain
        self.api = api
    }

    func fetch() async throws -> AccountUsage {
        let token = try await keychain.readAccessToken()
        let dto = try await api.fetch(accessToken: token)
        let email = try await email(for: token)
        return AccountUsage(
            email: email,
            usage: ServiceUsage(
                fiveHour: dto.fiveHour?.toRateLimit(),
                weekly: dto.sevenDay?.toRateLimit(),
                weeklySonnet: dto.sevenDaySonnet?.toRateLimit()
            ),
            fetchedAt: Date()
        )
    }

    private func email(for token: String) async throws -> String {
        if let cachedOwner, cachedOwner.token == token { return cachedOwner.email }
        let email = try await api.fetchEmail(accessToken: token)
        cachedOwner = (token, email)
        return email
    }
}
