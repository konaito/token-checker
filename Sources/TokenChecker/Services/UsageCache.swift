import Foundation

/// 最後に取得できた使用状況をサービスごとに 1 件だけ保存する (上書き)。
/// オフライン等で取得に失敗したときの表示と、起動直後の表示に使う。
struct UsageCache {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(_ brand: ServiceBrand) -> ServiceUsage? {
        guard let data = defaults.data(forKey: Self.key(brand)) else { return nil }
        return try? JSONDecoder().decode(ServiceUsage.self, from: data)
    }

    func save(_ usage: ServiceUsage, for brand: ServiceBrand) {
        guard let data = try? JSONEncoder().encode(usage) else { return }
        defaults.set(data, forKey: Self.key(brand))
    }

    private static func key(_ brand: ServiceBrand) -> String {
        "lastUsage.\(brand.rawValue)"
    }
}
