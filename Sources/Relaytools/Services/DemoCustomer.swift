import Foundation

/// An explicitly labelled offline rehearsal, never represented as generative AI.
enum DemoCustomer {
    static func respond(persona: CustomerPersona, messages: [ChatMessage], signals: CustomerSignals) -> CustomerTurn {
        let text = messages.last(where: { !$0.isCustomer })?.text.lowercased() ?? ""
        let turn = messages.filter { !$0.isCustomer }.count
        guard turn > 0 else {
            return .init(reply: "Hi, I'm \(persona.name.components(separatedBy: " ").first!). I'm open to a better way of doing things, but \(persona.priority.lowercased()) matters to me. What would you like to know about what I use today?", signals: signals, outcome: .ongoing, feedback: "Begin by learning about the customer.", strength: "You've made time to practise.", improvement: "Ask an open question before giving your pitch.")
        }
        let harmful = ["idiot", "stupid", "buy now or", "don't care", "shut up"].contains { text.contains($0) }
        let discovery = text.contains("?")
        let listening = ["understand", "hear you", "makes sense", "important", "fair", "you mentioned"].contains { text.contains($0) }
        let value = ["because", "helps", "save", "reduce", "benefit", "so you", "means"].contains { text.contains($0) }
        let nextStep = ["trial", "demo", "next step", "try", "start", "purchase"].contains { text.contains($0) }
        let longPitch = text.count > 650
        let adjustment = (discovery ? 9 : 0) + (listening ? 7 : 0) + (value ? 9 : 0) - (longPitch ? 8 : 0) - (harmful ? 60 : 0)
        let updated = CustomerSignals(
            conviction: signals.conviction + adjustment,
            comfort: signals.comfort + (listening ? 10 : discovery ? 5 : -3) - (harmful ? 80 : 0),
            readiness: signals.readiness + (value ? 10 : 0) + (nextStep && signals.conviction > 45 ? 15 : 0) - (harmful ? 55 : 0)).clamped()
        let won = turn >= 3 && updated.conviction >= 70 && updated.readiness >= 70 && nextStep
        let replies = [
            "We're spending too much time chasing things manually. What would actually change for us?",
            "That sounds useful, but how would it fit into the way we already work?",
            "I'm watching the budget. What makes the cost worth it for a team like mine?",
            "How could I check that it works before I commit?",
            "I want a clear next step without feeling locked in. What do you suggest?"
        ]
        let reply = harmful ? "I don't feel respected here. I'm going to leave it, thanks." : won ? "That addresses my concerns. I'm happy to go ahead with the next step you've suggested." : listening && discovery ? "Thanks for asking. My main concern is \(persona.priority.lowercased()). What would you recommend for that?" : replies[(turn - 1) % replies.count]
        return .init(reply: reply, signals: updated, outcome: harmful ? .lost : won ? .won : .ongoing,
            feedback: harmful ? "The customer felt pressured or disrespected." : adjustment > 10 ? "You moved the conversation forward by focusing on the customer's needs." : "Make the conversation more specific to the customer.",
            strength: discovery ? "Asked a discovery question." : listening ? "Acknowledged the customer's concern." : "Explained your offer.",
            improvement: value ? "Check whether that benefit matters to this customer." : "Connect one benefit to the customer's stated priority.")
    }
}
