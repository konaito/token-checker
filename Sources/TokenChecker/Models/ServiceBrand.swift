import Foundation

/// 表示対象のサービス。表示名・アイコン・ログインコマンドをここに集約する。
enum ServiceBrand: String {
    case claude
    case codex

    var title: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex:  return "Codex"
        }
    }

    var symbolName: String {
        switch self {
        case .claude: return "sparkles"
        case .codex:  return "terminal.fill"
        }
    }

    /// アカウント切り替えに使う CLI。berkboz/account-switcher と同じもの。
    var switchCommand: String {
        switch self {
        case .claude: return "cswap"
        case .codex:  return "codex-auth"
        }
    }

    /// 任意文字列を AppleScript に渡せないよう、コマンドは enum から引く形にして
    /// インジェクションを「型として」不能にする。
    var loginCommand: String {
        switch self {
        case .claude: return "claude login"
        case .codex:  return "codex login"
        }
    }
}
