import Foundation
@testable import TokenChecker
import XCTest

@MainActor
final class UsageCacheFallbackTests: XCTestCase {
    private let usage = ServiceUsage(
        fiveHour: RateLimit(utilization: 0.27, resetsAt: Date(timeIntervalSince1970: 1_760_000_000)),
        weekly: nil,
        weeklySonnet: nil
    )

    func testFailureFallsBackToLastSuccessfulUsage() async {
        let cache = makeCache()
        let claude = StubProvider(.success(usage))
        let viewModel = UsageViewModel(claudeProvider: claude, codexProvider: StubProvider(.failure(.timeout)), cache: cache)

        await viewModel.refresh()
        claude.result = .failure(.network("offline"))
        await viewModel.refresh()

        XCTAssertEqual(viewModel.snapshot.claude, .success(usage))
        XCTAssertEqual(viewModel.refreshErrors[.claude], .network("offline"))
    }

    func testFailureWithoutCacheShowsError() async {
        let viewModel = UsageViewModel(
            claudeProvider: StubProvider(.failure(.timeout)),
            codexProvider: StubProvider(.failure(.timeout)),
            cache: makeCache()
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.snapshot.codex, .failure(.timeout))
        XCTAssertEqual(viewModel.refreshErrors[.codex], .timeout)
    }

    func testSuccessClearsRefreshErrors() async {
        let codex = StubProvider(.failure(.timeout))
        let viewModel = UsageViewModel(claudeProvider: StubProvider(.success(usage)), codexProvider: codex, cache: makeCache())

        await viewModel.refresh()
        codex.result = .success(usage)
        await viewModel.refresh()

        XCTAssertTrue(viewModel.refreshErrors.isEmpty)
    }

    func testCachedUsageIsShownAfterRelaunch() async {
        let cache = makeCache()
        let first = UsageViewModel(claudeProvider: StubProvider(.success(usage)), codexProvider: StubProvider(.failure(.timeout)), cache: cache)
        await first.refresh()

        let relaunched = UsageViewModel(claudeProvider: StubProvider(.failure(.timeout)), codexProvider: StubProvider(.failure(.timeout)), cache: cache)

        XCTAssertEqual(relaunched.snapshot.claude, .success(usage))
        XCTAssertNil(relaunched.snapshot.codex)
    }

    private func makeCache() -> UsageCache {
        let suiteName = "TokenCheckerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return UsageCache(defaults: defaults)
    }
}

private final class StubProvider: UsageProvider, @unchecked Sendable {
    var result: Result<ServiceUsage, DomainError>

    init(_ result: Result<ServiceUsage, DomainError>) {
        self.result = result
    }

    func fetch() async throws -> ServiceUsage {
        try result.get()
    }
}
