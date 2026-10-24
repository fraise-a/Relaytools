import Foundation
import FoundationModels

enum ConversationContext {
    /// Keep the entire latest reply. Older messages may be shortened to fit the model.
    static func transcript(_ messages: [ChatMessage], historyLimit: Int = 8) -> String {
        let recent = Array(messages.suffix(max(1, historyLimit)))
        return recent.enumerated().map { index, message in
            let text = index == recent.count - 1 ? message.text : String(message.text.prefix(450))
            return (message.isCustomer ? "Customer: " : "Salesperson: ") + text
        }.joined(separator: "\n")
    }

    /// Preserve the latest completed exchange, including the end of the salesperson's answer.
    static func reviewTranscript(_ messages: [ChatMessage], messageLimit: Int = 16) -> String {
        let limit = max(2, messageLimit)
        let selected: [ChatMessage]
        if messages.count <= limit { selected = messages }
        else if limit == 2 { selected = Array(messages.suffix(2)) }
        else { selected = Array(messages.prefix(2)) + Array(messages.suffix(limit - 2)) }
        let latestPitchID = messages.last(where: { !$0.isCustomer })?.id
        let latestReplyID = messages.last?.id
        let lines = selected.map { message in
            let text: String
            if message.id == latestPitchID || message.id == latestReplyID || message.text.count <= 450 {
                text = message.text
            } else {
                text = String(message.text.prefix(225)) + " [excerpt omitted] " + String(message.text.suffix(225))
            }
            return (message.isCustomer ? "Customer: " : "Salesperson: ") + text
        }
        let note = selected.count < messages.count ? "Opening and closing excerpts; some earlier exchanges omitted.\n" : ""
        return note + lines.joined(separator: "\n")
    }

    @MainActor @available(macOS 26.0, *)
    static func fittedPrompt<T: Generable>(instructions: String, generating: T.Type, variants: [String]) async throws -> String {
        guard let first = variants.first else { throw CustomerAIError.empty }
        guard #available(macOS 26.4, *) else { return first }
        let model = SystemLanguageModel.default
        let instructionTokens = try await model.tokenCount(for: Instructions(instructions))
        let schemaTokens = try await model.tokenCount(for: T.generationSchema)
        // Leave room for the guided response plus framework transcript overhead.
        let fixedTokens = instructionTokens + schemaTokens + 850
        for variant in variants {
            let tokens = try await model.tokenCount(for: Prompt(variant))
            if tokens + fixedTokens <= model.contextSize { return variant }
        }
        throw CustomerAIError.contextTooLong
    }
}
