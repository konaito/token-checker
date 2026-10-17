import Foundation
@testable import TokenChecker
import XCTest

@MainActor
final class AccountTrackingTests: XCTestCase {
    private func usage(_ fiveHour: Double) -> ServiceUsage {
        ServiceUsage(
            fiveHour: RateLimit(utilization: fiveHour, resetsAt: Date(timeIntervalSince1970: 1_760_000_000)),
            weekly: nil,
            weeklySonnet: nil
        )
    }

    func testActiveAccountComesFirstAndPreviousAccountsAreRemembered() async {
        let claude = StubProvider(.success(("a@example.com", usage(0.1))))
        let viewModel = makeViewModel(claude: claude)

        await viewModel.refresh()
        claude.result = .success(("b@example.com", usage(0.2)))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.snapshot.claude.accounts.map(\.email), ["b@example.com", "a@example.com"])
        XCTAssertEqual(viewModel.snapshot.claude.active?.usage, usage(0.2))
    }

    func testSameAccountIsOverwrittenAndMovedToTop() async {
        let claude = StubProvider(.success(("a@example.com", usage(0.1))))
        let viewModel = makeViewModel(claude: claude)

        await viewModel.refresh()
        claude.result = .success(("b@example.com", usage(0.2)))
        await viewModel.refresh()
        claude.result = .success(("a@example.com", usage(0.3)))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.snapshot.claude.accounts.map(\.email), ["a@example.com", "b@example.com"])
        XCTAssertEqual(viewModel.snapshot.claude.active?.usage, usage(0.3))
    }

    func testFailureKeepsRememberedAccountsAndRecordsError() async {
        let claude = StubProvider(.success(("a@example.com", usage(0.1))))
        let viewModel = makeViewModel(claude: claude)

        await viewModel.refresh()
        claude.result = .failure(.network("offline"))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.snapshot.claude.accounts.map(\.email), ["a@example.com"])
        XCTAssertEqual(viewModel.snapshot.claude.error, .network("offline"))
    }

    func testSuccessClearsError() async {
        let claude = StubProvider(.failure(.timeout))
        let viewModel = makeViewModel(claude: claude)

        await viewModel.refresh()
        XCTAssertEqual(viewModel.snapshot.claude.error, .timeout)
        XCTAssertTrue(viewModel.snapshot.claude.accounts.isEmpty)

        claude.result = .success(("a@example.com", usage(0.1)))
        await viewModel.refresh()
        XCTAssertNil(viewModel.snapshot.claude.error)
    }

    func testRememberedAccountsSurviveRelaunch() async {
        let store = makeStore()
        let first = makeViewModel(claude: StubProvider(.success(("a@example.com", usage(0.1)))), store: store)
        await first.refresh()

        let relaunched = makeViewModel(claude: StubProvider(.failure(.timeout)), store: store)

        XCTAssertEqual(relaunched.snapshot.claude.accounts.map(\.email), ["a@example.com"])
        XCTAssertTrue(relaunched.snapshot.codex.accounts.isEmpty)
    }

    private func makeViewModel(claude: StubProvider, store: AccountUsageStore? = nil) -> UsageViewModel {
        UsageViewModel(
            claudeProvider: claude,
            codexProvider: StubProvider(.failure(.timeout)),
            store: store ?? makeStore()
        )
    }

    private func makeStore() -> AccountUsageStore {
        let suiteName = "TokenCheckerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return AccountUsageStore(defaults: defaults)
    }
}

private final class StubProvider: UsageProvider, @unchecked Sendable {
    var result: Result<(String, ServiceUsage), DomainError>

    init(_ result: Result<(String, ServiceUsage), DomainError>) {
        self.result = result
    }

    func fetch() async throws -> AccountUsage {
        let (email, usage) = try result.get()
        return AccountUsage(email: email, usage: usage, fetchedAt: Date())
    }
}
