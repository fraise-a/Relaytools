import Foundation
import Observation

@MainActor @Observable
final class TrainingStore {
    var destination: Destination = .dashboard
    var employeeName: String
    private(set) var prompts: [RecentPrompt]
    private(set) var sessions: [SessionResult]
    private(set) var mazeRuns: [MazeRunResult] = []
    private(set) var quickPicRuns: [QuickPicResult] = []
    private var savedSessionIDs: Set<UUID> = []
    var storageError: String?
    @ObservationIgnored private let storageURL: URL?
    @ObservationIgnored private var savingBlockedByLoadFailure = false

    init(persist: Bool = true, fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Relaytools", isDirectory: true)
        storageURL = persist ? (fileURL ?? directory?.appendingPathComponent("training.json")) : nil
        employeeName = NSFullUserName().isEmpty ? "Your name" : NSFullUserName()
        prompts = []
        sessions = DemoData.sessions()

        guard let url = storageURL else { return }
        do {
            let data = try Data(contentsOf: url)
            let saved = try JSONDecoder().decode(WorkspaceData.self, from: data)
            employeeName = saved.employeeName
            prompts = saved.prompts
            sessions = saved.sessions
            mazeRuns = saved.mazeRuns ?? []
            quickPicRuns = saved.quickPicRuns ?? []
            savedSessionIDs = Set(saved.sessions.map(\.id) + mazeRuns.map(\.id) + quickPicRuns.map(\.id))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // A new workspace has no saved file yet.
        } catch {
            savingBlockedByLoadFailure = true
            storageError = "Saved training data could not be loaded. The existing file is preserved. Restore the file and restart Relaytools before saving changes. " + error.localizedDescription
        }
    }

    var recentMazeRuns: [MazeRunResult] {
        let now = Date()
        return mazeRuns.filter { $0.date >= now.addingTimeInterval(-30 * 86400) && $0.date <= now }
    }

    func recordMaze(_ result: MazeRunResult) {
        guard !mazeRuns.contains(where: { $0.id == result.id }) else { return }
        mazeRuns.insert(result, at: 0)
        save()
    }

    func isMazeSaved(_ result: MazeRunResult) -> Bool { savedSessionIDs.contains(result.id) }

    func mazeTimeboard(for result: MazeRunResult) -> [MazeTimeEntry] {
        let target = result.difficulty.targetSeconds
        let best = mazeRuns.filter { $0.difficulty == result.difficulty }.map(\.seconds).min() ?? result.seconds
        return [
            .init(id: "demo-priya", name: "Priya Shah", seconds: target * 0.82, isYou: false),
            .init(id: "demo-marcus", name: "Marcus Cole", seconds: target * 1.05, isYou: false),
            .init(id: "demo-sophie", name: "Sophie Turner", seconds: target * 1.35, isYou: false),
            .init(id: "you", name: employeeName + " · best", seconds: min(best, result.seconds), isYou: true),
            .init(id: "demo-oliver", name: "Oliver James", seconds: target * 1.7, isYou: false)
        ].sorted { $0.seconds == $1.seconds ? $0.id < $1.id : $0.seconds < $1.seconds }
    }

    var recentQuickPicRuns: [QuickPicResult] {
        let now = Date()
        return quickPicRuns.filter { $0.date >= now.addingTimeInterval(-30 * 86400) && $0.date <= now }
    }

    func recordQuickPic(_ result: QuickPicResult) {
        guard !quickPicRuns.contains(where: { $0.id == result.id }) else { return }
        quickPicRuns.insert(result, at: 0)
        save()
    }
    func isQuickPicSaved(_ result: QuickPicResult) -> Bool { savedSessionIDs.contains(result.id) }
    func quickPicBest(for difficulty: QuickPicDifficulty) -> Double? {
        quickPicRuns.filter { $0.difficulty == difficulty }.map(\.xp).max()
    }
    func quickPicLeaderboard(for result: QuickPicResult) -> [LeaderboardEntry] {
        let base = Double(result.difficulty.baseXP)
        return [
            .init(id: "demo-priya", name: "Priya Shah", role: "Demo colleague", xp: base * 86),
            .init(id: "demo-marcus", name: "Marcus Cole", role: "Demo colleague", xp: base * 65),
            .init(id: "demo-sophie", name: "Sophie Turner", role: "Demo colleague", xp: base * 48),
            .init(id: "you", name: employeeName, role: "Your personal best", xp: max(quickPicBest(for: result.difficulty) ?? result.xp, result.xp), isYou: true),
            .init(id: "demo-oliver", name: "Oliver James", role: "Demo colleague", xp: base * 31)
        ].sorted { $0.xp == $1.xp ? $0.id < $1.id : $0.xp > $1.xp }
    }

    var firstName: String { employeeName.split(separator: " ").first.map(String.init) ?? "there" }
    var initials: String { employeeName.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased() }
    var recentSessions: [SessionResult] {
        let now = Date()
        let cutoff = now.addingTimeInterval(-30 * 86400)
        return sessions.filter { $0.date >= cutoff && $0.date <= now }
    }
    var totalWins: Int { sessions.filter { $0.outcome == .won }.count + mazeRuns.reduce(0) { $0 + $1.convinced } }
    var recentWins: Int { recentSessions.filter { $0.outcome == .won }.count + recentMazeRuns.reduce(0) { $0 + $1.convinced } }
    var recentXP: Double { Double(recentSessions.reduce(0) { $0 + $1.xp } + recentMazeRuns.reduce(0) { $0 + $1.xp }) + recentQuickPicRuns.reduce(0) { $0 + $1.xp } }
    var totalXP: Double { Double(sessions.reduce(0) { $0 + $1.xp } + mazeRuns.reduce(0) { $0 + $1.xp }) + quickPicRuns.reduce(0) { $0 + $1.xp } }
    var level: Int { max(1, Int(max(0, totalXP) / 1000) + 1) }
    var levelRemainder: Double { max(0, totalXP).truncatingRemainder(dividingBy: 1000) }
    var levelProgress: Double { levelRemainder / 1000 }
    var leaderboard: [LeaderboardEntry] {
        [
            .init(id: "1", name: "Priya Shah", role: "Account executive", xp: 4260),
            .init(id: "2", name: "Marcus Cole", role: "Sales development", xp: 3890),
            .init(id: "3", name: "Sophie Turner", role: "Account executive", xp: 3120),
            .init(id: "you", name: employeeName, role: "You", xp: recentXP, isYou: true),
            .init(id: "5", name: "Oliver James", role: "Sales development", xp: 1940),
            .init(id: "6", name: "Amara Okafor", role: "Account executive", xp: 1680),
            .init(id: "7", name: "Leo Martin", role: "Sales development", xp: 1250)
        ].sorted { $0.xp == $1.xp ? $0.id < $1.id : $0.xp > $1.xp }
    }
    var rank: Int { (leaderboard.firstIndex { $0.isYou } ?? 0) + 1 }

    func remember(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = prompts.firstIndex(where: { $0.text == trimmed }) {
            prompts[index].lastUsed = Date()
        } else {
            prompts.append(.init(text: trimmed))
        }
        prompts.sort { $0.lastUsed > $1.lastUsed }
        prompts = Array(prompts.prefix(12))
        save()
    }

    func record(_ result: SessionResult) {
        guard !sessions.contains(where: { $0.id == result.id }) else { return }
        sessions.insert(result, at: 0)
        save()
    }

    func isSaved(_ result: SessionResult) -> Bool { savedSessionIDs.contains(result.id) }

    @discardableResult
    func save() -> Bool {
        guard let storageURL, !savingBlockedByLoadFailure else { return false }
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(WorkspaceData(employeeName: employeeName, prompts: prompts, sessions: sessions, mazeRuns: mazeRuns, quickPicRuns: quickPicRuns))
            try data.write(to: storageURL, options: .atomic)
            savedSessionIDs = Set(sessions.map(\.id) + mazeRuns.map(\.id) + quickPicRuns.map(\.id))
            storageError = nil
            return true
        } catch {
            storageError = "Your latest changes could not be saved. " + error.localizedDescription
            return false
        }
    }
}
