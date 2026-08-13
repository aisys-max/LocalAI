import Testing
@testable import LocalAI

struct MessageParsingTests {
    @Test func plainTextProducesASingleUnboldedTextBlock() {
        let blocks = MessageParsing.blocks(from: "just plain text")
        #expect(blocks.count == 1)
        guard case .text(_, let parts) = blocks[0] else {
            Issue.record("expected .text block")
            return
        }
        #expect(parts.count == 1)
        #expect(parts[0].bold == false)
        #expect(parts[0].text == "just plain text")
    }

    @Test func boldSpansAlternateCorrectly() {
        let parts = MessageParsing.inlineParts(from: "**bold** middle **end**")
        #expect(parts.map(\.bold) == [true, false, true])
        #expect(parts.map(\.text) == ["bold", " middle ", "end"])
    }

    @Test func fencedCodeBlockIsExtractedSeparately() {
        let blocks = MessageParsing.blocks(from: "before\n```python\nprint(1)\n```\nafter")
        #expect(blocks.count == 3)
        guard case .text(_, let beforeParts) = blocks[0] else {
            Issue.record("expected leading .text block"); return
        }
        #expect(beforeParts.first?.text == "before\n")

        guard case .code(_, let code) = blocks[1] else {
            Issue.record("expected .code block"); return
        }
        #expect(code == "print(1)")

        guard case .text(_, let afterParts) = blocks[2] else {
            Issue.record("expected trailing .text block"); return
        }
        #expect(afterParts.first?.text == "\nafter")
    }

    @Test func multipleCodeBlocksInterleavedWithTextStayInOrder() {
        // A word immediately after the opening fence is parsed as a language
        // tag (matching the design's parser), so blocks separate ``` fences
        // with a newline to actually capture code content, per real usage
        // (e.g. "```python\nimport os\n```").
        let blocks = MessageParsing.blocks(from: "a```\none\n```b```\ntwo\n```c")
        var kinds: [String] = []
        for block in blocks {
            switch block {
            case .code(_, let text): kinds.append("code:\(text)")
            case .text(_, let parts): kinds.append("text:\(parts.map(\.text).joined())")
            }
        }
        #expect(kinds == ["text:a", "code:one", "text:b", "code:two", "text:c"])
    }

    @Test func emptyStringProducesASingleTextBlockWithNoParts() {
        // blocks(from:) falls back to an empty .text block with no parts at
        // all when there are no matches and no remaining text — it does not
        // route through inlineParts's own (single-empty-part) fallback.
        let blocks = MessageParsing.blocks(from: "")
        #expect(blocks.count == 1)
        guard case .text(_, let parts) = blocks[0] else {
            Issue.record("expected .text block"); return
        }
        #expect(parts.isEmpty)
    }
}
