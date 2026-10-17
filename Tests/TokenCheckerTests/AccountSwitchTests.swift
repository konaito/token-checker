import Foundation
@testable import TokenChecker
import XCTest

@MainActor
final class AccountSwitchTests: XCTestCase {
    private let usage = ServiceUsage(fiveHour: nil, weekly: nil, weeklySonnet: nil)

    func testSwitchRunsCommandAndRefreshesToNewAccount() async {
        let claude = SwitchableProvider(email: "a@example.com", usage: usage)
        let recorder = SwitchRecorder()
        let viewModel = makeViewModel(claude: claude) { brand, email in
            await recorder.record(brand, email)
            claude.email = email
        }
        await viewModel.refresh()
        claude.email = "b@example.com"
        await viewModel.refresh()

        await viewModel.switchAccount(.claude, to: "a@example.com")

        let calls = await recorder.calls
        XCTAssertEqual(calls.map(\.1), ["a@example.com"])
        XCTAssertEqual(calls.map(\.0), [.claude])
        XCTAssertEqual(viewModel.snapshot.claude.accounts.map(\.email), ["a@example.com", "b@example.com"])
        XCTAssertNil(viewModel.switchingEmail)
        XCTAssertNil(viewModel.switchErrors[.claude])
    }

    func testSwitchFailureIsRecordedAndDoesNotChangeAccounts() async {
        let claude = SwitchableProvider(email: "a@example.com", usage: usage)
        let viewModel = makeViewModel(claude: claude) { _, _ in
            throw DomainError.accountSwitchFailed("boom")
        }
        await viewModel.refresh()

        await viewModel.switchAccount(.claude, to: "b@example.com")

        XCTAssertEqual(viewModel.switchErrors[.claude], .accountSwitchFailed("boom"))
        XCTAssertEqual(viewModel.snapshot.claude.accounts.map(\.email), ["a@example.com"])
        XCTAssertNil(viewModel.switchingEmail)
    }

    private func makeViewModel(
        claude: SwitchableProvider,
        switcher: @escaping AccountSwitcher
    ) -> UsageViewModel {
        let suiteName = "TokenCheckerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return UsageViewModel(
            claudeProvider: claude,
            codexProvider: SwitchableProvider(email: "c@example.com", usage: usage),
            store: AccountUsageStore(defaults: defaults),
            switcher: switcher
        )
    }
}

private actor SwitchRecorder {
    var calls: [(ServiceBrand, String)] = []
    func record(_ brand: ServiceBrand, _ email: String) { calls.append((brand, email)) }
}

private final class SwitchableProvider: UsageProvider, @unchecked Sendable {
    var email: String
    let usage: ServiceUsage

    init(email: String, usage: ServiceUsage) {
        self.email = email
        self.usage = usage
    }

    func fetch() async throws -> AccountUsage {
        AccountUsage(email: email, usage: usage, fetchedAt: Date())
    }
}
