import Foundation

/// アクティブなアカウントを切り替える処理。テストで差し替えられるよう関数型で受け渡す。
typealias AccountSwitcher = @Sendable (ServiceBrand, String) async throws -> Void

/// berkboz/account-switcher と同じ CLI (`cswap` / `codex-auth`) を呼んで切り替える。
/// どちらもメールアドレスでアカウントを指定できる。
enum AccountSwitchCommand {
    /// CLI の探索先。account-switcher のインストーラは `~/.local/bin` に置く。
    private static let searchDirectories = [
        "\(NSHomeDirectory())/.local/bin",
        "/opt/homebrew/bin",
        "/usr/local/bin",
    ]
    private static let timeout: TimeInterval = 60

    static func run(_ brand: ServiceBrand, email: String) async throws {
        let name = brand.switchCommand
        guard let executable = searchDirectories
            .map({ "\($0)/\(name)" })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw DomainError.accountSwitchToolNotFound(name)
        }

        // シェルを介さず引数配列で渡すので、メールアドレスがコマンドとして解釈されることはない。
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["switch", email]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = (searchDirectories + ["/usr/bin", "/bin"]).joined(separator: ":")
        environment["NO_COLOR"] = "1"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        let (output, status) = try await Task.detached { () throws -> (String, Int32) in
            do {
                try process.run()
            } catch {
                throw DomainError.accountSwitchFailed(error.localizedDescription)
            }
            let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            killer.cancel()
            return (String(decoding: data, as: UTF8.self), process.terminationStatus)
        }.value

        guard status == 0 else {
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw DomainError.accountSwitchFailed(String(detail.suffix(160)))
        }
    }
}
