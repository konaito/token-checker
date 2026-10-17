import Foundation

/// アクティブになったことのあるアカウントと、その最新の使用状況をサービスごとに保存する。
/// 同じアカウントは上書きし、最後に取得できたものを先頭に置く。
struct AccountUsageStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(_ brand: ServiceBrand) -> [AccountUsage] {
        guard let data = defaults.data(forKey: Self.key(brand)) else { return [] }
        return (try? JSONDecoder().decode([AccountUsage].self, from: data)) ?? []
    }

    func save(_ accounts: [AccountUsage], for brand: ServiceBrand) {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        defaults.set(data, forKey: Self.key(brand))
    }

    private static func key(_ brand: ServiceBrand) -> String {
        "accounts.\(brand.rawValue)"
    }
}
