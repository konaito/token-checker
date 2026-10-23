import Foundation
@testable import TokenChecker
import XCTest

final class HeadlineUsageTests: XCTestCase {
    private func limit(_ utilization: Double) -> RateLimit {
        RateLimit(utilization: utilization, resetsAt: Date(timeIntervalSince1970: 1_760_000_000))
    }

    func testFiveHourIsPreferred() {
        let usage = ServiceUsage(fiveHour: limit(0.05), weekly: limit(0.47), weeklySonnet: nil)
        XCTAssertEqual(usage.headline, limit(0.05))
    }

    func testWeeklyIsUsedWhenFiveHourIsMissing() {
        let usage = ServiceUsage(fiveHour: nil, weekly: limit(0.47), weeklySonnet: nil)
        XCTAssertEqual(usage.headline, limit(0.47))
    }

    /// prolite プランの実レスポンス（2026-10-23 取得）。5h ウィンドウがなく週次だけが primary に入る。
    func testCodexWeeklyOnlyResponseFallsBackToWeekly() throws {
        let json = """
        {"rateLimits":{"limitId":"codex","primary":{"usedPercent":47,"windowDurationMins":10080,"resetsAt":1793293811},"secondary":null,"planType":"prolite"}}
        """
        let dto = try JSONDecoder().decode(CodexRateLimitsDTO.self, from: Data(json.utf8))
        let usage = ServiceUsage(fiveHour: dto.fiveHourRateLimit(), weekly: dto.weeklyRateLimit(), weeklySonnet: nil)

        XCTAssertNil(usage.fiveHour)
        XCTAssertEqual(usage.headline?.percent, 47)
    }
}
