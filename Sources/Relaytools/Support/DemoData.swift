import Foundation

enum DemoData {
    static let exampleBrief = """
    Flowdesk is a shared inbox for small service teams. It brings customer emails into one place, assigns a clear owner, and highlights unanswered requests.

    It costs £29 per user per month, with a 14-day free trial and no annual commitment. Our ideal customer runs a team of 3–15 people and is losing time or missing messages across personal inboxes.

    The goal is to understand their workflow and, if there is a fit, agree on a trial. Do not promise integrations or savings we have not verified.
    """

    static func sessions(now: Date = Date()) -> [SessionResult] {
        (0..<84).map { index in
            let days = index < 32 ? index % 29 : 35 + (index - 32) * 3
            let won = index % 4 != 3
            let score = won ? 72 + (index * 7 % 24) : 30 + index % 25
            return SessionResult(date: now.addingTimeInterval(-Double(days * 86400 + index * 71 + 3600)),
                customer: ["Morgan Ellis", "Alex Bennett", "Jamie Chen", "Taylor Reed", "Sam Patel"][index % 5],
                product: ["Flowdesk shared inbox", "Team scheduling software", "Business broadband", "Customer support platform"][index % 4],
                outcome: won ? .won : .ended,
                signals: .init(conviction: score, comfort: min(100, score + 5), readiness: max(0, score - 3)),
                score: score, xp: won ? 100 + index % 90 : -10,
                feedback: won ? "You connected the product to a clear customer need and agreed on a practical next step." : "The customer needed a clearer reason to change before discussing next steps.",
                strength: "Made space for the customer's concerns.",
                improvement: "Ask one more discovery question before presenting the solution.",
                isDemo: true, engine: "Sample session")
        }
    }
}
