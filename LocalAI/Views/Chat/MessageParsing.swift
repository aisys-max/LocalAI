import Foundation

/// Ports the design's `parseBlocks`/`parseInline` markdown-lite renderer:
/// fenced ``` code blocks, and **bold** spans within the remaining text.
enum MessageParsing {
    private static let codeBlockRegex = try! NSRegularExpression(
        pattern: "```(?:\\w+)?\\n?(.*?)```",
        options: [.dotMatchesLineSeparators]
    )
    private static let boldRegex = try! NSRegularExpression(
        pattern: "\\*\\*(.*?)\\*\\*",
        options: [.dotMatchesLineSeparators]
    )

    static func blocks(from text: String) -> [MessageBlock] {
        var blocks: [MessageBlock] = []
        let ns = text as NSString
        var last = 0
        let matches = codeBlockRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.range.location > last {
                let plain = ns.substring(with: NSRange(location: last, length: match.range.location - last))
                blocks.append(.text(id: UUID(), parts: inlineParts(from: plain)))
            }
            var code = ns.substring(with: match.range(at: 1))
            if code.hasSuffix("\n") { code.removeLast() }
            blocks.append(.code(id: UUID(), text: code))
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            let plain = ns.substring(with: NSRange(location: last, length: ns.length - last))
            blocks.append(.text(id: UUID(), parts: inlineParts(from: plain)))
        }
        if blocks.isEmpty {
            blocks.append(.text(id: UUID(), parts: []))
        }
        return blocks
    }

    static func inlineParts(from text: String) -> [InlinePart] {
        var parts: [InlinePart] = []
        let ns = text as NSString
        var last = 0
        let matches = boldRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches {
            if match.range.location > last {
                parts.append(InlinePart(bold: false, text: ns.substring(with: NSRange(location: last, length: match.range.location - last))))
            }
            parts.append(InlinePart(bold: true, text: ns.substring(with: match.range(at: 1))))
            last = match.range.location + match.range.length
        }
        if last < ns.length {
            parts.append(InlinePart(bold: false, text: ns.substring(with: NSRange(location: last, length: ns.length - last))))
        }
        if parts.isEmpty {
            parts.append(InlinePart(bold: false, text: ""))
        }
        return parts
    }
}
